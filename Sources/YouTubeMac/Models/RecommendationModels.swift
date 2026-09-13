import Foundation

struct HomeFeed {
    var hero: VideoItem
    var queue: [VideoItem]
    var forYou: [VideoItem]
    var trending: [VideoItem]
    var more: [VideoItem]

    /// Keep every loaded item reachable; the old 8/8/8/4 partition dropped
    /// everything after item 28, even from a 100-item History response.
    mutating func replaceVideos(_ videos: [VideoItem]) {
        guard let first = videos.first else { return }
        hero = first
        forYou = Array(videos.prefix(8))
        trending = Array(videos.dropFirst(8).prefix(8))
        more = Array(videos.dropFirst(16))
        queue = []
    }
}

enum RecommendationRotationPolicy {
    static let rememberedRecommendationLimit = 24

    static func updatedRecentlyPresentedIDs(
        previous: [String],
        displayed: [VideoItem],
        limit: Int = rememberedRecommendationLimit
    ) -> [String] {
        guard limit > 0 else { return [] }

        var result: [String] = []
        for id in displayed.map(\.id) + previous where !id.isEmpty {
            guard !result.contains(id) else { continue }
            result.append(id)
            if result.count == limit { break }
        }
        return result
    }
}
