import Foundation

/// Product-level content rules shared by feed ingestion, local persistence,
/// search, and presentation. Keeping this policy in one model boundary makes
/// it difficult for a secondary feed or cached fallback to reintroduce a
/// content type the user has disabled.
enum YouGlassContentPolicy {
    static func allows(_ video: VideoItem) -> Bool {
        !video.isShortForm
    }

    static func nonShortVideos<S: Sequence>(from videos: S) -> [VideoItem]
    where S.Element == VideoItem {
        videos.filter(allows)
    }

    static func isShortsText(_ value: String) -> Bool {
        let normalized = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let tokens = normalized
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        return normalized.contains("#short")
            || normalized.contains("youtube shorts")
            || normalized.contains("short form")
            || normalized.contains("vertical short")
            || tokens.contains("shorts")
    }

    static func isShortsURL(_ value: String) -> Bool {
        guard let url = URL(string: value) else { return false }
        return isShortsURL(url)
    }

    static func isShortsURL(_ url: URL) -> Bool {
        url.pathComponents.contains { component in
            component.caseInsensitiveCompare("shorts") == .orderedSame
        }
    }

    static func isShortsSearch(_ value: String) -> Bool {
        isShortsText(value)
    }
}
