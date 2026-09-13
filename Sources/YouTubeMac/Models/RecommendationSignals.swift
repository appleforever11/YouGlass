import Foundation

/// Balanced, bounded interest signals. Each source gets its own budget so a
/// long history cannot hide deliberate likes and saves.
struct RecommendationSignals {
    private var tokenWeights: [String: Double] = [:]
    private var channelWeights: [String: Double] = [:]

    init(history: [VideoItem], liked: [VideoItem], saved: [VideoItem]) {
        add(history, weight: 1)
        add(liked, weight: 1.8)
        add(saved, weight: 1.4)
    }

    private mutating func add(_ videos: [VideoItem], weight: Double) {
        var seen = Set<String>()
        for (index, video) in videos.prefix(24).enumerated()
        where YouGlassContentPolicy.allows(video) && seen.insert(video.id).inserted {
            let strength = weight / (1 + Double(index) / 8)
            for token in Self.tokens(video.title) {
                tokenWeights[token, default: 0] += strength
            }
            channelWeights[Self.channelKey(video), default: 0] += strength
        }
    }

    func score(_ video: VideoItem) -> Double {
        let topic = Self.tokens(video.title).reduce(0.0) {
            $0 + min(6, tokenWeights[$1, default: 0] * 3)
        }
        let channel = min(26, channelWeights[Self.channelKey(video), default: 0] * 12)
        return min(28, topic) + channel
    }

    static func tokens(_ text: String) -> Set<String> {
        Set(text.folding(options: [.diacriticInsensitive, .caseInsensitive],
                         locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && !stopWords.contains($0) })
    }

    static func channelKey(_ video: VideoItem) -> String {
        if let id = video.channelID, id.hasPrefix("UC"), id.count >= 24 {
            return "channel:\(id)"
        }
        let name = video.channel.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                        locale: Locale(identifier: "en_US_POSIX"))
            .lowercased().filter { $0.isLetter || $0.isNumber }
        return name.isEmpty ? "video:\(video.id)" : "name:\(name)"
    }

    static func contextScore(_ candidate: VideoItem, for current: VideoItem) -> Double {
        let overlap = tokens(candidate.title).intersection(tokens(current.title)).count
        return min(120, Double(overlap) * 30)
            + (channelKey(candidate) == channelKey(current) ? 80 : 0)
    }

    private static let stopWords: Set<String> = [
        "the", "and", "for", "with", "this", "that", "from", "what", "your",
        "you", "are", "was", "how", "why", "not", "but", "have", "has",
        "new", "video", "videos", "official", "watch", "full", "episode"
    ]
}

enum RecommendationSourcePolicy {
    /// Rotate a bounded window without additional requests or persisted account data.
    static func rotatingWindow<T>(_ values: [T], limit: Int, now: Date = Date()) -> [T] {
        guard limit > 0, !values.isEmpty else { return [] }
        guard values.count > limit else { return values }
        let window = Int(max(0, now.timeIntervalSince1970) / 300)
        let start = (window % values.count) * limit % values.count
        return (0..<limit).map { values[(start + $0) % values.count] }
    }
}
