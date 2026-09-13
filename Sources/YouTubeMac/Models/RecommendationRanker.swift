import Foundation

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
        recentlyPresentedIDs: [String] = [],
        favorFresh: Bool = false,
        contextVideo: VideoItem? = nil,
        limit: Int = 40
    ) -> [VideoItem] {
        guard limit > 0 else { return [] }

        let subscriptionIDs = Set(subscriptions.compactMap(\.canonicalChannelID))
        let historyIDs = Set(history.map(\.id))
        let historyIndexByID = Dictionary(
            history.enumerated().map { ($0.element.id, $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )
        let likedIDs = Set(liked.map(\.id))
        let savedIDs = Set(saved.map(\.id))
        let recentlyPresentedIDSet = Set(recentlyPresentedIDs)
        let seedText = seeds.map(normalized).filter { !$0.isEmpty }
        let signals = RecommendationSignals(history: history, liked: liked, saved: saved)

        var best: [String: (video: VideoItem, score: Double, index: Int)] = [:]
        for (index, video) in videos.enumerated() {
            if video.id.isEmpty || video.id == contextVideo?.id || !YouGlassContentPolicy.allows(video) {
                continue
            }

            let normalizedChannelID = video.channelID.flatMap(Self.canonicalChannelID)
            let channelName = normalized(video.channel)
            let title = normalized(video.title)
            var score = max(0, 24 - Double(index) * 0.20)

            if likedIDs.contains(video.id) { score += 12 }
            if savedIDs.contains(video.id) { score += 18 }
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
            if normalizedChannelID.map(subscriptionIDs.contains) == true
                || subscriptions.contains(where: {
                    $0.matches(channelID: video.channelID, channelName: video.channel)
                }) {
                score += contextVideo == nil ? 110 : 24
            }

            let seedMatches = seedText.reduce(0) { total, seed in
                return total + ((title.contains(seed) || channelName.contains(seed)) ? 1 : 0)
            }
            score += Double(seedMatches) * 14

            score += signals.score(video) * (contextVideo == nil ? 1 : 0.25)
            if let contextVideo {
                score += RecommendationSignals.contextScore(video, for: contextVideo)
            }
            score += recencyScore(video.age)
            score += viewScore(video.views)

            if let existing = best[video.id], existing.score >= score { continue }
            best[video.id] = (video, score, index)
        }

        let sorted = best.values
            .sorted {
                if favorFresh {
                    let leftWasRecentlyPresented = recentlyPresentedIDSet.contains($0.video.id)
                    let rightWasRecentlyPresented = recentlyPresentedIDSet.contains($1.video.id)
                    if leftWasRecentlyPresented != rightWasRecentlyPresented {
                        return !leftWasRecentlyPresented
                    }
                }
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
            // Exhaust unseen candidates before repeating recently displayed
            // ones; channel balancing must not undo freshness ordering.
            let eligible = favorFresh && remaining.contains(where: { !recentlyPresentedIDSet.contains($0.id) })
                ? remaining.filter { !recentlyPresentedIDSet.contains($0.id) } : remaining
            let eligibleCounts = eligible.compactMap { video -> Int? in
                let count = channelCounts[channelKey(for: video), default: 0]
                return count < 3 ? count : nil
            }
            guard let minimumCount = eligibleCounts.min(),
                  let nextIndex = remaining.firstIndex(where: { video in
                      let count = channelCounts[channelKey(for: video), default: 0]
                      return eligible.contains(where: { $0.id == video.id }) && count == minimumCount && count < 3
                  }) else {
                let next = eligible[0]
                selected.append(next)
                remaining.removeAll { $0.id == next.id }
                continue
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

    private static func channelKey(for video: VideoItem) -> String {
        RecommendationSignals.channelKey(video)
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
