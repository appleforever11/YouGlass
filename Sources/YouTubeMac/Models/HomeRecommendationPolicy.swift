import Foundation

/// YouTube already ranks its homepage. Local interests must never reorder it.
/// Only content policy, stable deduplication and the cache bound apply here.
enum HomeRecommendationPolicy {
    static func sourceOrdered(_ videos: [VideoItem], limit: Int = 40) -> [VideoItem] {
        guard limit > 0 else { return [] }
        var seen = Set<String>()
        return Array(videos.filter {
            YouGlassContentPolicy.allows($0) && seen.insert($0.id).inserted
        }.prefix(min(40, limit)))
    }
}
