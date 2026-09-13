import AppKit
import Foundation
import SwiftUI

extension YouTubeStore {
        func scheduleHomeReload(force: Bool = false) {
            scheduledHomeReloadTask?.cancel()
            scheduledHomeReloadTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard !Task.isCancelled else { return }
                guard let self else { return }
                self.scheduledHomeReloadTask = nil
                await self.loadHome(force: force)
            }
        }

        func personalizedVideos(
            maxResults: Int,
            forceFresh: Bool = false,
            seedLimit: Int = 3
        ) async -> [VideoItem] {
            guard !recommendationSeeds.isEmpty else { return [] }

            let results = await withTaskGroup(of: [VideoItem].self, returning: [VideoItem].self) { group in
                let seeds = RecommendationSourcePolicy.rotatingWindow(recommendationSeeds, limit: max(1, seedLimit))
                for seed in seeds {
                    group.addTask {
                        (try? await self.client.searchVideos(
                            query: seed,
                            maxResults: max(4, maxResults / seeds.count),
                            order: "relevance",
                            forceFresh: forceFresh
                        )) ?? []
                    }
                }

                var videos: [VideoItem] = []
                for await batch in group {
                    videos.append(contentsOf: batch)
                }
                return videos
            }
            return Array(mergeVideos(results).prefix(maxResults))
        }

        func personalizedAccountFeed(
            webHomepageVideos: [VideoItem] = [],
            forceFresh: Bool = false
        ) async -> [VideoItem] {
            // Keep the authenticated YouTube homepage as the highest-fidelity
            // source. The Data API cannot reproduce YouTube's private model, so it
            // supplements this list rather than replacing it.
            var videos: [VideoItem] = webHomepageVideos

            let subscribedChannels = subscriptions.compactMap { subscription -> SafariHomeFeedClient.Channel? in
                let source = subscription.channelURL
                    ?? (subscription.id.hasPrefix("UC")
                        ? URL(string: "https://www.youtube.com/channel/\(subscription.id)")
                        : nil)
                guard let source else { return nil }
                return SafariHomeFeedClient.Channel(
                    name: subscription.name,
                    source: source,
                    category: "Subscriptions",
                    channelID: subscription.canonicalChannelID
                )
            }

            let hasCredentials = await client.hasCredentials()
            let subscriptionChannels = RecommendationSourcePolicy.rotatingWindow(
                subscribedChannels, limit: YouGlassFeedRefreshPolicy.homeSubscriptionChannelLimit
            )
            let needsSearchFallback = subscriptionChannels.isEmpty
            await withTaskGroup(of: [VideoItem].self) { group in
                if !subscriptionChannels.isEmpty {
                    group.addTask {
                        await self.safariHomeFeed.loadFeed(
                            channels: subscriptionChannels,
                            maxResultsPerChannel: YouGlassFeedRefreshPolicy.homeSubscriptionVideosPerChannel,
                            timeout: YouGlassFeedRefreshPolicy.homeSubscriptionFeedTimeout
                        )
                    }
                }

                if hasCredentials {
                    group.addTask {
                        await self.accountSignalVideos(maxResults: 16, forceRefresh: forceFresh)
                    }
                    if needsSearchFallback {
                        group.addTask {
                            await self.personalizedVideos(
                                maxResults: 12,
                                forceFresh: forceFresh,
                                seedLimit: 1
                            )
                        }
                    }
                    if client.canConnect {
                        group.addTask {
                            (try? await self.client.mostPopularVideos(
                                maxResults: 6,
                                forceFresh: forceFresh
                            )) ?? []
                        }
                    }
                }

                for await batch in group {
                    videos.append(contentsOf: batch)
                }
            }

            let ranked = RecommendationRanker.rank(
                videos,
                subscriptions: subscriptions,
                history: recentlyWatched,
                liked: locallyLikedVideos,
                seeds: recommendationSeeds,
                saved: savedVideos,
                limit: 40
            )
            if !ranked.isEmpty {
                return ranked
            }

            if let data = defaults.data(forKey: DefaultsKey.cachedPersonalizedFeed),
               let cached = try? JSONDecoder().decode([VideoItem].self, from: data) {
                return RecommendationRanker.rank(
                    cached,
                    subscriptions: subscriptions,
                    history: recentlyWatched,
                    liked: locallyLikedVideos,
                    seeds: recommendationSeeds,
                    saved: savedVideos,
                    limit: 40
                )
            }

            return []
        }

        func accountSignalVideos(maxResults: Int, forceRefresh: Bool = false) async -> [VideoItem] {
            let requestedCount = max(1, maxResults)
            let cachedCandidates = YouGlassContentPolicy.nonShortVideos(from: cachedAccountSignalVideos)
            if !forceRefresh,
               cachedCandidates.count >= requestedCount,
               let lastAccountSignalLoadDate,
               !YouGlassFeedRefreshPolicy.needsRefresh(
                    lastUpdated: lastAccountSignalLoadDate,
                    maxAge: YouGlassFeedRefreshPolicy.accountSignalRefreshInterval
               ) {
                return Array(cachedCandidates.prefix(requestedCount))
            }

            var videos: [VideoItem] = []

            // Liked videos and private subscription activity are OAuth-only. Do
            // not spend API quota on public channel searches when the account has
            // no OAuth token; the signed-in homepage/Safari feed is the better
            // fallback for that mode.
            guard (try? await oauth.validAccessToken()) != nil else {
                let local = recentlyWatched + locallyLikedVideos + savedVideos
                return Array(YouGlassContentPolicy.nonShortVideos(from: mergeVideos(local)).prefix(requestedCount))
            }

            if let liked = try? await client.likedVideos(maxResults: 8) {
                videos.append(contentsOf: liked)
            }

            videos.append(contentsOf: recentlyWatched.prefix(8))
            videos.append(contentsOf: locallyLikedVideos.prefix(8))
            videos.append(contentsOf: savedVideos.prefix(8))
            let merged = Array(YouGlassContentPolicy.nonShortVideos(from: mergeVideos(videos)).prefix(requestedCount))
            cachedAccountSignalVideos = merged
            lastAccountSignalLoadDate = Date()
            return merged
        }

        func invalidateAccountSignalCache() {
            cachedAccountSignalVideos = []
            lastAccountSignalLoadDate = nil
        }
}
