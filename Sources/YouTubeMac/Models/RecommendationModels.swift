import Foundation

struct HomeFeed {
    var hero: VideoItem
    var queue: [VideoItem]
    var forYou: [VideoItem]
    var trending: [VideoItem]
    var more: [VideoItem]
}

/// A small, deterministic ranking layer for the sources YouGlass can access.
/// YouTube does not expose its private homepage ranking model through the Data
/// API, so this preserves the signed-in web feed when available and then
/// promotes signals we can verify locally or through OAuth.
struct RecommendationRanker {
    static func rank(
        _ videos: [VideoItem],
        subscriptions: [SubscriptionItem],
        history: [VideoItem],
        liked: [VideoItem],
        seeds: [String],
        saved: [VideoItem] = [],
        limit: Int = 40
    ) -> [VideoItem] {
        guard limit > 0 else { return [] }

        let subscriptionIDs = Set(subscriptions.compactMap(\.canonicalChannelID))
        let historyChannels = Set(history.map { normalized($0.channel) })
        let historyIDs = Set(history.map(\.id))
        let historyIndexByID = Dictionary(
            history.enumerated().map { ($0.element.id, $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )
        let likedIDs = Set(liked.map(\.id))
        let savedIDs = Set(saved.map(\.id))
        let seedText = seeds.map(normalized).filter { !$0.isEmpty }
        let signalTokens = Set(
            (history + liked + saved)
                .prefix(24)
                .flatMap { tokens($0.title + " " + $0.channel) }
        )

        var best: [String: (video: VideoItem, score: Double, index: Int)] = [:]
        for (index, video) in videos.enumerated() {
            if !YouGlassContentPolicy.allows(video) {
                continue
            }

            let normalizedChannelID = video.channelID.flatMap(Self.canonicalChannelID)
            let channelName = normalized(video.channel)
            let title = normalized(video.title)
            var score = max(0, 24 - Double(index) * 0.20)

            if likedIDs.contains(video.id) { score += 48 }
            if savedIDs.contains(video.id) { score += 36 }
            if let historyIndex = historyIndexByID[video.id],
               !likedIDs.contains(video.id),
               !savedIDs.contains(video.id) {
                // Keep watched channels useful, but move the exact videos the
                // user just watched out of the first screen until the feed has
                // a chance to find something new.
                let recentPenalty = max(18, 46 - Double(min(historyIndex, 14)) * 2)
                score -= recentPenalty
            } else if historyIDs.contains(video.id) {
                score -= 8
            }
            if historyChannels.contains(channelName) { score += 22 }
            if normalizedChannelID.map(subscriptionIDs.contains) == true
                || subscriptions.contains(where: {
                    $0.matches(channelID: video.channelID, channelName: video.channel)
                }) {
                score += 110
            }

            let seedMatches = seedText.reduce(0) { total, seed in
                return total + ((title.contains(seed) || channelName.contains(seed)) ? 1 : 0)
            }
            score += Double(seedMatches) * 14

            let overlap = Set(tokens(video.title + " " + video.channel))
                .intersection(signalTokens)
                .count
            score += min(28, Double(overlap) * 4)
            score += recencyScore(video.age)
            score += viewScore(video.views)

            if let existing = best[video.id], existing.score >= score { continue }
            best[video.id] = (video, score, index)
        }

        let sorted = best.values
            .sorted {
                if $0.score == $1.score { return $0.index < $1.index }
                return $0.score > $1.score
            }

        var selected: [VideoItem] = []
        var remaining = sorted.map(\.video)
        var channelCounts: [String: Int] = [:]

        // Round-robin through the ranked list so a single prolific channel
        // cannot fill the entire first screen. If the account only follows one
        // channel, the remaining items are still returned after the diversity
        // pass rather than being discarded.
        while selected.count < limit, !remaining.isEmpty {
            let eligibleCounts = remaining.compactMap { video -> Int? in
                let count = channelCounts[channelKey(for: video), default: 0]
                return count < 3 ? count : nil
            }
            guard let minimumCount = eligibleCounts.min(),
                  let nextIndex = remaining.firstIndex(where: { video in
                      let count = channelCounts[channelKey(for: video), default: 0]
                      return count == minimumCount && count < 3
                  }) else {
                selected.append(contentsOf: remaining)
                break
            }

            let video = remaining.remove(at: nextIndex)
            let key = channelKey(for: video)
            selected.append(video)
            channelCounts[key, default: 0] += 1
        }
        return Array(selected.prefix(limit))
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive], locale: .current)
            .lowercased()
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    private static func tokens(_ value: String) -> [String] {
        value
            .folding(options: [.diacriticInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }
    }

    private static func channelKey(for video: VideoItem) -> String {
        if let channelID = video.channelID.flatMap(canonicalChannelID) {
            return "channel:\(channelID)"
        }
        let channel = normalized(video.channel)
        return channel.isEmpty ? (video.channelID ?? video.id) : "name:\(channel)"
    }

    private static func canonicalChannelID(_ value: String) -> String? {
        guard value.hasPrefix("UC"), value.count >= 24 else { return nil }
        return value
    }

    private static func recencyScore(_ value: String) -> Double {
        let lower = value.lowercased()
        if lower.contains("just now") { return 13 }
        if lower.contains("fresh upload") { return 12 }

        let pattern = #"\b(\d+)\s*(m|min|mins|minute|minutes|h|hr|hrs|hour|hours|d|day|days|w|week|weeks|mo|month|months|y|year|years)\b"#
        if let expression = try? NSRegularExpression(pattern: pattern),
           let match = expression.firstMatch(in: lower, range: NSRange(lower.startIndex..<lower.endIndex, in: lower)),
           match.numberOfRanges > 2,
           let numberRange = Range(match.range(at: 1), in: lower),
           let unitRange = Range(match.range(at: 2), in: lower),
           let number = Double(lower[numberRange]) {
            switch String(lower[unitRange]) {
            case "m", "min", "mins", "minute", "minutes":
                return max(8, 13 - min(number, 180) / 30)
            case "h", "hr", "hrs", "hour", "hours":
                return max(5, 10 - min(number, 72) / 18)
            case "d", "day", "days":
                return max(2, 7 - min(number, 30) / 10)
            case "w", "week", "weeks":
                return max(1, 4 - min(number, 12) / 6)
            case "mo", "month", "months":
                return max(0.5, 2 - min(number, 12) / 12)
            default:
                return 0.5
            }
        }

        return lower.contains("year") ? 0.5 : 1
    }

    private static func viewScore(_ value: String) -> Double {
        let lower = value.lowercased().replacingOccurrences(of: ",", with: "")
        guard let number = Double(lower.filter { $0.isNumber || $0 == "." }) else { return 0 }
        let multiplier: Double
        if lower.contains("b") { multiplier = 1.8 }
        else if lower.contains("m") { multiplier = 1.2 }
        else if lower.contains("k") { multiplier = 0.7 }
        else { multiplier = 0.1 }
        return min(5, log10(max(1, number)) * multiplier)
    }
}
