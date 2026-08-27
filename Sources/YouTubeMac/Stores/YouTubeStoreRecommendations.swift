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
            return Array(
                mergeVideos(candidates)
                    .filter { $0.id != video.id }
                    .prefix(10)
            )
        }

        func loadRecommendations(for video: VideoItem) async -> [VideoItem] {
            let localFallback = relatedVideos(for: video)
            guard await client.hasCredentials() else {
                return localFallback
            }

            do {
                let query = recommendationQuery(for: video)
                let relevance = try await client.searchVideos(query: query, maxResults: 8, order: "relevance")
                let popular = try await client.searchVideos(query: video.channel, maxResults: 6, order: "viewCount")
                let blended = RecommendationRanker.rank(
                    relevance + popular + relatedVideos(for: video),
                    subscriptions: subscriptions,
                    history: recentlyWatched,
                    liked: locallyLikedVideos,
                    seeds: [video.channel, video.title],
                    limit: 10
                ).filter { $0.id != video.id }
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
