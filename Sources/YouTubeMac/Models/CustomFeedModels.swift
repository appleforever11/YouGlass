import Foundation

enum YouGlassCustomFeedDuration: String, Codable, Hashable {
    case short
    case medium
    case long

    var apiValue: String { rawValue }

    var label: String {
        switch self {
        case .short: "Short duration"
        case .medium: "Medium duration"
        case .long: "Long-form"
        }
    }
}

struct YouGlassCustomFeedIntent: Codable, Hashable {
    let searchQuery: String
    let keywords: [String]
    let subscribedOnly: Bool
    let freshnessHours: Int?
    let duration: YouGlassCustomFeedDuration?
    let excludesShorts: Bool

    var searchTerms: [String] {
        keywords + [searchQuery]
    }

    var summary: String {
        var parts: [String] = []
        if subscribedOnly { parts.append("Your subscriptions") }
        if let freshnessHours {
            parts.append(freshnessHours <= 24 ? "Past day" : "Past week")
        }
        if let duration { parts.append(duration.label) }
        if excludesShorts { parts.append("Shorts excluded") }
        return parts.isEmpty ? "Personalized long-form picks" : parts.joined(separator: " • ")
    }

    func matches(_ video: VideoItem, subscriptions: [SubscriptionItem]) -> Bool {
        guard excludesShorts ? YouGlassContentPolicy.allows(video) : true else { return false }

        if subscribedOnly {
            guard subscriptions.contains(where: {
                $0.matches(channelID: video.channelID, channelName: video.channel)
            }) else {
                return false
            }
        }

        if let freshnessHours,
           let age = Self.ageInterval(video.age),
           age > Double(freshnessHours) * 3600 {
            return false
        }

        if let duration,
           let seconds = Self.durationSeconds(video.duration) {
            switch duration {
            case .short where seconds > 4 * 60:
                return false
            case .medium where seconds <= 4 * 60 || seconds > 20 * 60:
                return false
            case .long where seconds <= 20 * 60:
                return false
            default:
                break
            }
        }

        return true
    }

    static func durationSeconds(_ value: String) -> Double? {
        let components = value.split(separator: ":")
        guard (2...3).contains(components.count),
              components.allSatisfy({ Int($0) != nil }) else {
            return nil
        }

        let numbers = components.compactMap { Double($0) }
        if numbers.count == 2 {
            return numbers[0] * 60 + numbers[1]
        }
        return numbers[0] * 3600 + numbers[1] * 60 + numbers[2]
    }

    static func ageInterval(_ value: String) -> Double? {
        let lower = value.lowercased()
        if lower.contains("just now") { return 0 }

        let pattern = #"\b(\d+)\s*(m|min|mins|minute|minutes|h|hr|hrs|hour|hours|d|day|days|w|week|weeks)\b"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                  in: lower,
                  range: NSRange(lower.startIndex..<lower.endIndex, in: lower)
              ),
              let numberRange = Range(match.range(at: 1), in: lower),
              let unitRange = Range(match.range(at: 2), in: lower),
              let number = Double(lower[numberRange]) else {
            return nil
        }

        switch String(lower[unitRange]) {
        case "m", "min", "mins", "minute", "minutes": return number * 60
        case "h", "hr", "hrs", "hour", "hours": return number * 3600
        case "d", "day", "days": return number * 86_400
        case "w", "week", "weeks": return number * 604_800
        default: return nil
        }
    }
}

struct YouGlassCustomFeed: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var prompt: String
    var intent: YouGlassCustomFeedIntent
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        prompt: String,
        intent: YouGlassCustomFeedIntent? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(64))
        self.prompt = String(prompt.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        self.intent = intent ?? YouGlassCustomFeedPromptInterpreter.interpret(prompt)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    mutating func update(name: String, prompt: String, now: Date = Date()) {
        self.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(64))
        self.prompt = String(prompt.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        intent = YouGlassCustomFeedPromptInterpreter.interpret(prompt)
        updatedAt = now
    }
}

enum YouGlassCustomFeedPromptInterpreter {
    static let defaultName = "Custom Feed"

    static func interpret(_ prompt: String) -> YouGlassCustomFeedIntent {
        let normalized = prompt
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let subscribedOnly = containsAny(
            normalized,
            [
                "from my subscriptions",
                "from subscribed channels",
                "from channels i follow",
                "subscribed channels",
                "my subscriptions"
            ]
        )

        let freshnessHours: Int?
        if containsAny(normalized, ["today", "past 24", "last 24", "last day"]) {
            freshnessHours = 24
        } else if containsAny(normalized, ["past 48", "last 48", "past two days", "last two days"]) {
            freshnessHours = 48
        } else if containsAny(normalized, ["this week", "past week", "last week"]) {
            freshnessHours = 168
        } else if containsAny(normalized, ["latest", "recent", "new uploads", "fresh uploads"]) {
            freshnessHours = 72
        } else {
            freshnessHours = nil
        }

        let duration: YouGlassCustomFeedDuration?
        if containsAny(normalized, ["long form", "long-form", "full length", "full-length", "deep dive", "deep-dive"]) {
            duration = .long
        } else if containsAny(normalized, ["under 4 minutes", "under four minutes", "quick clips", "short duration"]) {
            duration = .short
        } else if containsAny(normalized, ["4 to 20 minutes", "4-20 minutes", "medium length"]) {
            duration = .medium
        } else {
            duration = nil
        }

        let keywords = keywordTokens(from: normalized)
        return YouGlassCustomFeedIntent(
            searchQuery: keywords.joined(separator: " "),
            keywords: keywords,
            subscribedOnly: subscribedOnly,
            freshnessHours: freshnessHours,
            duration: duration,
            excludesShorts: true
        )
    }

    static func suggestedName(for prompt: String) -> String {
        let intent = interpret(prompt)
        if !intent.keywords.isEmpty {
            return intent.keywords
                .prefix(4)
                .map { $0.capitalized }
                .joined(separator: " ")
        }
        if intent.subscribedOnly { return "Subscription Picks" }
        return defaultName
    }

    private static func keywordTokens(from value: String) -> [String] {
        let ignored = Set([
            "about", "after", "all", "and", "are", "around", "be", "best", "by",
            "channels", "channel", "content", "custom", "feed", "find", "for", "from",
            "form", "fresh", "give", "i", "in", "into", "latest", "last", "long", "me", "my",
            "new", "no", "of", "on", "or", "past", "please", "recommend", "recommendations",
            "recent", "show", "short", "shorts", "subscriptions", "subscribe", "that", "the",
            "this", "to", "today", "under", "uploads", "videos", "video", "want", "watch", "week", "with", "without",
            "youtube"
        ])

        var seen = Set<String>()
        let tokens: [String] = value
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { token in
                token.count >= 3 && !ignored.contains(token) && seen.insert(token).inserted
            }
            .map { String($0) }
        return Array(tokens.prefix(12))
    }

    private static func containsAny(_ value: String, _ phrases: [String]) -> Bool {
        phrases.contains { value.contains($0) }
    }
}

struct YouGlassCustomFeedRanker {
    static func rank(
        _ videos: [VideoItem],
        feed: YouGlassCustomFeed,
        subscriptions: [SubscriptionItem],
        history: [VideoItem],
        liked: [VideoItem],
        saved: [VideoItem],
        limit: Int = 24
    ) -> [VideoItem] {
        let eligible = videos.filter {
            feed.intent.matches($0, subscriptions: subscriptions)
        }
        guard !eligible.isEmpty else { return [] }

        return RecommendationRanker.rank(
            eligible,
            subscriptions: subscriptions,
            history: history,
            liked: liked,
            seeds: feed.intent.searchTerms,
            saved: saved,
            favorFresh: feed.intent.freshnessHours != nil,
            limit: limit
        )
    }
}
