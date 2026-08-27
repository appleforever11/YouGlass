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

        func personalizedVideos(maxResults: Int) async -> [VideoItem] {
            guard !recommendationSeeds.isEmpty else { return [] }

            let results = await withTaskGroup(of: [VideoItem].self, returning: [VideoItem].self) { group in
                for seed in recommendationSeeds.prefix(3) {
                    group.addTask {
                        (try? await self.client.searchVideos(
                            query: seed,
                            maxResults: max(4, maxResults / 3),
                            order: "relevance"
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

        func personalizedAccountFeed(webHomepageVideos: [VideoItem] = []) async -> [VideoItem] {
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
            await withTaskGroup(of: [VideoItem].self) { group in
                if !subscribedChannels.isEmpty {
                    group.addTask {
                        await self.safariHomeFeed.loadFeed(
                            channels: Array(subscribedChannels.prefix(24)),
                            maxResultsPerChannel: 3
                        )
                    }
                }

                if hasCredentials {
                    group.addTask { await self.accountSignalVideos(maxResults: 16) }
                    group.addTask { await self.personalizedVideos(maxResults: 12) }
                    if client.canConnect {
                        group.addTask {
                            (try? await self.client.mostPopularVideos(maxResults: 6)) ?? []
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
                limit: 40,
                excludeShortForm: true
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
                    limit: 40,
                    excludeShortForm: true
                )
            }

            return []
        }

        func accountSignalVideos(maxResults: Int) async -> [VideoItem] {
            let requestedCount = max(1, maxResults)
            let cachedCandidates = cachedAccountSignalVideos.filter { !$0.isShortForm }
            if cachedCandidates.count >= requestedCount,
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
                return Array(mergeVideos(local).filter { !$0.isShortForm }.prefix(requestedCount))
            }

            if let liked = try? await client.likedVideos(maxResults: 8) {
                videos.append(contentsOf: liked)
            }

            videos.append(contentsOf: recentlyWatched.prefix(8))
            videos.append(contentsOf: locallyLikedVideos.prefix(8))
            videos.append(contentsOf: savedVideos.prefix(8))
            let merged = Array(mergeVideos(videos).filter { !$0.isShortForm }.prefix(requestedCount))
            cachedAccountSignalVideos = merged
            lastAccountSignalLoadDate = Date()
            return merged
        }

        func invalidateAccountSignalCache() {
            cachedAccountSignalVideos = []
            lastAccountSignalLoadDate = nil
        }
}
