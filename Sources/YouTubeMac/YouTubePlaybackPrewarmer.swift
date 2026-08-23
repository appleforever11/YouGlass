import Foundation

/// Warms YouTube's network path without mounting another WKWebView. Hidden
/// WebKit warm-up surfaces are intentionally avoided for runtime stability.
actor YouTubePlaybackPrewarmer {
    static let shared = YouTubePlaybackPrewarmer()

    private var warmedAt: [String: Date] = [:]
    private var inFlight: Set<String> = []
    private let freshnessInterval: TimeInterval = 10 * 60
    private let maximumEntries = 80

    func prewarm(_ video: VideoItem) async {
        guard video.isPlayableOnYouTube, !inFlight.contains(video.id) else { return }
        if let date = warmedAt[video.id], Date().timeIntervalSince(date) < freshnessInterval {
            return
        }

        inFlight.insert(video.id)
        defer { inFlight.remove(video.id) }

        await withTaskGroup(of: Void.self) { group in
            if let thumbnailURL = video.thumbnailURL {
                group.addTask { await Self.fetch(thumbnailURL) }
            }
            if let embedURL = video.embedURL {
                group.addTask { await Self.fetch(embedURL) }
            }
        }

        warmedAt[video.id] = Date()
        trimIfNeeded()
    }

    private func trimIfNeeded() {
        guard warmedAt.count > maximumEntries else { return }
        let overflow = warmedAt.count - maximumEntries
        warmedAt
            .sorted { $0.value < $1.value }
            .prefix(overflow)
            .forEach { warmedAt.removeValue(forKey: $0.key) }
    }

    private static func fetch(_ url: URL) async {
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 8)
        request.setValue("Mozilla/5.0 (Macintosh; Apple Silicon Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        _ = try? await URLSession.shared.data(for: request)
    }
}
