import Foundation

enum YouGlassLibrarySearch {
    /// All words must match, across either title or channel, without altering saved order.
    static func videos(matching query: String, in videos: [VideoItem]) -> [VideoItem] {
        let tokens = query.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !tokens.isEmpty else { return videos }
        return videos.filter { video in
            let text = "\(video.title) \(video.channel)"
            return tokens.allSatisfy { text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }
}
