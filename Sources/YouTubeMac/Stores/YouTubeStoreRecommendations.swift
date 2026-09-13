import AppKit
import Foundation
import SwiftUI

extension YouTubeStore {
        func relatedVideos(for video: VideoItem) -> [VideoItem] {
            let candidates = [feed.hero]
                + feed.forYou
                + feed.trending
                + feed.more
                + feed.queue
                + recentlyWatched
                + savedVideos
            return RecommendationRanker.rank(
                candidates, subscriptions: subscriptions, history: recentlyWatched,
                liked: locallyLikedVideos, seeds: [], saved: savedVideos,
                contextVideo: video, limit: 10
            )
        }

        func loadRecommendations(for video: VideoItem) async -> [VideoItem] {
            let localFallback = relatedVideos(for: video)
            guard await client.hasCredentials() else {
                return localFallback
            }

            do {
                let query = recommendationQuery(for: video)
                async let relevance = client.searchVideos(query: query, maxResults: 8, order: "relevance")
                async let popular = client.searchVideos(query: video.channel, maxResults: 6, order: "viewCount")
                let matches = await ((try? relevance) ?? []) + ((try? popular) ?? [])
                try Task.checkCancellation()
                let blended = RecommendationRanker.rank(
                    matches + localFallback,
                    subscriptions: subscriptions,
                    history: recentlyWatched,
                    liked: locallyLikedVideos,
                    seeds: [video.channel, video.title],
                    saved: savedVideos,
                    contextVideo: video,
                    limit: 10
                )
                // Keep the rail populated when the API returns only one or two
                // search matches. The already-loaded home/history catalog is a
                // safe local supplement, so a transiently sparse API response
                // cannot collapse the visible Up Next rail to one card.
                return Array(mergeVideos(blended + localFallback).prefix(10))
            } catch {
                return localFallback
            }
        }
}
