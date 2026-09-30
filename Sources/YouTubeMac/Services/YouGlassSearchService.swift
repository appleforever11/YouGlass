import Foundation

@MainActor
protocol YouGlassSearchService {
    func hasCredentials() async -> Bool
    func search(_ query: String) async throws -> [VideoItem]
    func webSearch(_ query: String) async -> YouTubeWebFeedResult
}

/// Resolve the current client at each call, so credential edits take effect.
@MainActor
struct YouGlassLiveSearchService: YouGlassSearchService {
    let client: () -> YouTubeAPIClient

    func hasCredentials() async -> Bool { await client().hasCredentials() }
    func search(_ query: String) async throws -> [VideoItem] {
        try await client().searchVideos(query: query, maxResults: 20)
    }
    func webSearch(_ query: String) async -> YouTubeWebFeedResult {
        await YouTubeWebFeedBridge.shared.searchVideos(query: query, maxResults: 20)
    }
}
