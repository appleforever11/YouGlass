import AppKit
import Foundation
import SwiftUI

extension YouTubeStore {
        func relatedVideos(for video: VideoItem) -> [VideoItem] {
            let candidates = feed.forYou + feed.trending + feed.more + feed.queue
            let unique = candidates.filter { $0.id != video.id }
            return Array(unique.reduce(into: [VideoItem]()) { result, item in
                if !result.contains(where: { $0.id == item.id }) {
                    result.append(item)
                }
            }.prefix(8))
        }

        func loadRecommendations(for video: VideoItem) async -> [VideoItem] {
            guard await client.hasCredentials() else {
                return relatedVideos(for: video)
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
                return blended
            } catch {
                return relatedVideos(for: video)
            }
        }
}
