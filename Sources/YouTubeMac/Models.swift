import Foundation
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme {
        self == .dark ? .dark : .light
    }
}

enum CompactPlayerCorner: String, CaseIterable, Identifiable, Equatable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topLeading: "Top Left"
        case .topTrailing: "Top Right"
        case .bottomLeading: "Bottom Left"
        case .bottomTrailing: "Bottom Right"
        }
    }

    var alignment: Alignment {
        switch self {
        case .topLeading: .topLeading
        case .topTrailing: .topTrailing
        case .bottomLeading: .bottomLeading
        case .bottomTrailing: .bottomTrailing
        }
    }
}

enum PIPTransitionState: Equatable {
    case idle
    case presenting(videoID: String)
    case active(videoID: String)

    var isTransitioning: Bool {
        if case .presenting = self { return true }
        return false
    }

    func matches(videoID: String) -> Bool {
        switch self {
        case .idle:
            return false
        case .presenting(let currentID), .active(let currentID):
            return currentID == videoID
        }
    }
}

enum PIPTransitionPolicy {
    // Give the source WebView a full SwiftUI/AppKit transaction to tear down
    // before a new WebKit surface is created for the desktop PIP panel.
    static let sourceTeardownDelayNanoseconds: UInt64 = 180_000_000
    static let panelFadeDuration: TimeInterval = 0.18
}

enum PlaybackCheckpointPolicy {
    static let maxEntries = 200
    static let completionGraceSeconds = 3.0
    static let completionFraction = 0.98
}

struct VideoAmbientColor: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}

struct VideoAmbientPalette: Equatable, Sendable {
    let primary: VideoAmbientColor
    let secondary: VideoAmbientColor
    let accent: VideoAmbientColor
    let energy: Double

    static let neutral = VideoAmbientPalette(
        primary: VideoAmbientColor(red: 0.20, green: 0.55, blue: 1.0),
        secondary: VideoAmbientColor(red: 1.0, green: 0.18, blue: 0.52),
        accent: VideoAmbientColor(red: 0.56, green: 0.25, blue: 1.0),
        energy: 0.42
    )
}

struct VideoItem: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let channel: String
    let views: String
    let age: String
    let duration: String
    let imageURL: URL?
    let verified: Bool
    let channelID: String?

    init(
        id: String,
        title: String,
        channel: String,
        views: String,
        age: String,
        duration: String,
        imageURL: URL?,
        verified: Bool,
        channelID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.channel = channel
        self.views = views
        self.age = age
        self.duration = duration
        self.imageURL = imageURL
        self.verified = verified
        self.channelID = channelID
    }

    var playbackURL: URL {
        if id.count == 11, id.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil {
            return URL(string: "https://www.youtube.com/watch?v=\(id)")!
        }

        let query = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        return URL(string: "https://www.youtube.com/results?search_query=\(query)")!
    }

    var isPlayableOnYouTube: Bool {
        id.count == 11 && id.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
    }

    /// Web homepage cards can arrive before their lazy thumbnail has been
    /// attached. A YouTube-hosted fallback keeps the card useful and, more
    /// importantly, prevents an empty async-image phase from becoming the
    /// visual state of an otherwise playable video.
    var thumbnailURL: URL? {
        if let imageURL {
            return imageURL
        }
        guard isPlayableOnYouTube else {
            return nil
        }
        return URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")
    }

    var embedURL: URL? {
        guard isPlayableOnYouTube else {
            return nil
        }
        return URL(string: "https://www.youtube.com/embed/\(id)?autoplay=1&playsinline=1&rel=0&modestbranding=1&enablejsapi=1&origin=https%3A%2F%2Fwww.youtube.com&mute=1")
    }
}

struct SubscriptionItem: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let avatarURL: URL?
    let channelURL: URL?
    let isLive: Bool

    init(
        id: String? = nil,
        name: String,
        avatarURL: URL?,
        channelURL: URL? = nil,
        isLive: Bool
    ) {
        self.id = id ?? "subscription:\(name.lowercased())"
        self.name = name
        self.avatarURL = avatarURL
        self.channelURL = channelURL
        self.isLive = isLive
    }
}

extension SubscriptionItem {
    /// Returns the stable YouTube channel ID when the item came from either
    /// the Data API or a channel URL extracted from the signed-in web session.
    var canonicalChannelID: String? {
        Self.canonicalChannelID(from: id) ?? Self.canonicalChannelID(from: channelURL?.absoluteString)
    }

    func matches(channelID: String?, channelName: String) -> Bool {
        let incomingChannelID = Self.canonicalChannelID(from: channelID)
        if let incomingChannelID, let canonicalChannelID {
            // Once both sources expose a stable ID, a display-name match is
            // unsafe: YouTube channel names are not unique.
            return canonicalChannelID == incomingChannelID
        }

        let targetName = Self.normalizedChannelName(channelName)
        guard !targetName.isEmpty else { return false }

        let candidates = [
            (name, Self.normalizedChannelName(name)),
            (Self.channelHandle(from: channelURL?.absoluteString), Self.normalizedChannelName(Self.channelHandle(from: channelURL?.absoluteString))),
            (Self.channelHandle(from: id), Self.normalizedChannelName(Self.channelHandle(from: id)))
        ].filter { !$0.1.isEmpty }

        return candidates.contains { rawCandidate, candidate in
            guard candidate == targetName || candidate.count >= 8 else { return false }
            if candidate == targetName { return true }

            // Web navigation labels can be shortened with an ellipsis. Only
            // allow a prefix match when that truncation is explicit; broad
            // fuzzy matching can incorrectly mark similarly named channels as
            // subscribed.
            let candidateWasTruncated = Self.hasTrailingTruncation(rawCandidate)
            let targetWasTruncated = Self.hasTrailingTruncation(channelName)
            guard candidateWasTruncated || targetWasTruncated else { return false }
            return candidate.hasPrefix(targetName) || targetName.hasPrefix(candidate)
        }
    }

    private static func canonicalChannelID(from value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        let parts = value.split { character in
            !(character.isLetter || character.isNumber || character == "_" || character == "-")
        }
        return parts
            .map(String.init)
            .first { $0.hasPrefix("UC") && $0.count >= 24 }
    }

    private static func normalizedChannelName(_ value: String) -> String {
        let folded = value
            .folding(options: [.diacriticInsensitive], locale: .current)
            .lowercased()
        return folded.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    private static func channelHandle(from value: String?) -> String {
        guard let value, !value.isEmpty else { return "" }
        guard let atIndex = value.firstIndex(of: "@") else { return "" }
        let handle = value[atIndex...].dropFirst()
        return String(handle.prefix(while: { character in
            character.isLetter || character.isNumber || character == "_" || character == "-"
        }))
    }

    private static func hasTrailingTruncation(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasSuffix("...") || trimmed.hasSuffix("\u{2026}")
    }
}

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
        limit: Int = 40
    ) -> [VideoItem] {
        guard limit > 0 else { return [] }

        let subscriptionIDs = Set(subscriptions.compactMap(\.canonicalChannelID))
        let subscriptionNames = subscriptions.map { normalized($0.name) }
        let historyChannels = Set(history.map { normalized($0.channel) })
        let likedIDs = Set(liked.map(\.id))
        let seedText = seeds.map(normalized)

        var best: [String: (video: VideoItem, score: Double, index: Int)] = [:]
        for (index, video) in videos.enumerated() {
            let normalizedChannelID = video.channelID.flatMap(Self.canonicalChannelID)
            let channelName = normalized(video.channel)
            let title = normalized(video.title)
            var score = max(0, 14 - Double(index) * 0.16)

            if likedIDs.contains(video.id) { score += 42 }
            if historyChannels.contains(channelName) { score += 22 }
            if (normalizedChannelID.map(subscriptionIDs.contains) == true)
                || subscriptionNames.contains(where: { name in
                    !name.isEmpty && (channelName == name || channelName.contains(name) || name.contains(channelName))
                }) {
                score += 90
            }

            let seedMatches = seedText.reduce(0) { total, seed in
                guard !seed.isEmpty else { return total }
                return total + ((title.contains(seed) || channelName.contains(seed)) ? 1 : 0)
            }
            score += Double(seedMatches) * 12
            score += recencyScore(video.age)
            score += viewScore(video.views)

            if let existing = best[video.id], existing.score >= score { continue }
            best[video.id] = (video, score, index)
        }

        return best.values
            .sorted {
                if $0.score == $1.score { return $0.index < $1.index }
                return $0.score > $1.score
            }
            .prefix(limit)
            .map(\.video)
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

    private static func canonicalChannelID(_ value: String) -> String? {
        guard value.hasPrefix("UC"), value.count >= 24 else { return nil }
        return value
    }

    private static func recencyScore(_ value: String) -> Double {
        let lower = value.lowercased()
        if lower.contains("just now") || lower.contains("fresh") || lower.contains("minute") || lower.contains(" min") { return 11 }
        if lower.contains("hour") || lower.contains(" hr") { return 9 }
        if lower.contains("day") { return 7 }
        if lower.contains("week") { return 4 }
        if lower.contains("month") { return 2 }
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

struct VideoComment: Identifiable, Hashable {
    let id: String
    let author: String
    let text: String
    let age: String
    let likes: String
    let avatarURL: URL?
}

struct YouTubeChannel: Identifiable, Hashable {
    let id: String
    let name: String
    let handle: String
    let description: String
    let avatarURL: URL?
    let bannerURL: URL?
    let subscriberCount: String
    let videoCount: String
    let isSubscribed: Bool
}

struct YouTubeChannelPage: Hashable {
    let channel: YouTubeChannel
    let videos: [VideoItem]
    let shorts: [VideoItem]
    let live: [VideoItem]
}

struct YouTubePlaylist: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let thumbnailURL: URL?
    let itemCount: Int
}

struct VideoDetails: Hashable {
    let id: String
    let likeCount: String
    let commentCount: String
    let concurrentViewers: String?
    let liveChatID: String?
    let channelID: String?
    let channelAvatarURL: URL?
    let description: String
    let isLive: Bool
    let rating: String?
}

struct CommentPage: Hashable {
    let comments: [VideoComment]
    let totalCount: Int
    let isAvailable: Bool
    let message: String?
    let nextPageToken: String?
    let channelID: String?

    init(
        comments: [VideoComment],
        totalCount: Int,
        isAvailable: Bool,
        message: String?,
        nextPageToken: String? = nil,
        channelID: String? = nil
    ) {
        self.comments = comments
        self.totalCount = totalCount
        self.isAvailable = isAvailable
        self.message = message
        self.nextPageToken = nextPageToken
        self.channelID = channelID
    }
}

struct LiveChatMessage: Identifiable, Hashable {
    let id: String
    let author: String
    let text: String
    let publishedAt: String
    let avatarURL: URL?
    let isHighlighted: Bool
}

struct LiveChatPage: Hashable {
    let messages: [LiveChatMessage]
    let nextPageToken: String?
    let pollingInterval: UInt64
    let isLive: Bool
    let isAvailable: Bool
    let message: String?

    init(
        messages: [LiveChatMessage],
        nextPageToken: String?,
        pollingInterval: UInt64,
        isLive: Bool = true,
        isAvailable: Bool = true,
        message: String? = nil
    ) {
        self.messages = messages
        self.nextPageToken = nextPageToken
        self.pollingInterval = pollingInterval
        self.isLive = isLive
        self.isAvailable = isAvailable
        self.message = message
    }

    static let unavailable = LiveChatPage(
        messages: [],
        nextPageToken: nil,
        pollingInterval: 5_000_000_000,
        isLive: false,
        isAvailable: false,
        message: "Live chat is unavailable for this video."
    )
}

extension VideoComment {
    static let samples = [
        VideoComment(
            id: "sample-1",
            author: "Kevin",
            text: "This native player layout already feels much better than a web view.",
            age: "2 hours ago",
            likes: "42",
            avatarURL: nil
        ),
        VideoComment(
            id: "sample-2",
            author: "Ava",
            text: "The glass controls and related rail make this feel like a real macOS app.",
            age: "1 day ago",
            likes: "18",
            avatarURL: nil
        )
    ]
}

extension VideoItem {
    static func fromYouTubeInput(_ value: String) -> VideoItem? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate: String

        if let url = URL(string: trimmed),
           let host = url.host?.lowercased(),
           host == "youtube.com" || host.hasSuffix(".youtube.com") || host == "youtu.be" {
            if host == "youtu.be" {
                candidate = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            } else if let queryID = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "v" })?.value {
                candidate = queryID
            } else {
                let paths = url.pathComponents
                if let marker = paths.firstIndex(where: { $0 == "shorts" || $0 == "live" || $0 == "embed" }),
                   paths.indices.contains(marker + 1) {
                    candidate = paths[marker + 1]
                } else {
                    return nil
                }
            }
        } else {
            candidate = trimmed
        }

        guard candidate.count == 11,
              candidate.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil else {
            return nil
        }

        return VideoItem(
            id: candidate,
            title: "YouTube video",
            channel: "YouTube",
            views: "Loading details",
            age: "",
            duration: "",
            imageURL: URL(string: "https://i.ytimg.com/vi/\(candidate)/hqdefault.jpg"),
            verified: false
        )
    }

    static let hero = VideoItem(
        id: "hero-yosemite",
        title: "The Beauty of Yosemite",
        channel: "Featured",
        views: "Experience the wonder of nature",
        age: "in stunning 4K.",
        duration: "",
        imageURL: URL(string: "https://images.unsplash.com/photo-1472396961693-142e6e269027?auto=format&fit=crop&w=1400&q=85"),
        verified: false
    )

    static let samples: [VideoItem] = [
        VideoItem(id: "iphone", title: "iPhone 15 Pro Review: Titanium Feels Different", channel: "Marques Brownlee", views: "1.8M views", age: "1 day ago", duration: "9:13", imageURL: URL(string: "https://images.unsplash.com/photo-1695048133142-1a20484d2569?auto=format&fit=crop&w=900&q=85"), verified: true),
        VideoItem(id: "apple-park", title: "Inside Apple Park", channel: "Apple", views: "3.2M views", age: "2 weeks ago", duration: "8:47", imageURL: URL(string: "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=900&q=85"), verified: true),
        VideoItem(id: "iceland", title: "Is Iceland the Most Beautiful Place on Earth?", channel: "Kara and Nate", views: "2.1M views", age: "5 days ago", duration: "10:32", imageURL: URL(string: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=900&q=85"), verified: true),
        VideoItem(id: "cars", title: "The Future of Electric Cars", channel: "MrBeast", views: "4.3M views", age: "3 days ago", duration: "7:28", imageURL: URL(string: "https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=900&q=85"), verified: true),
        VideoItem(id: "studio", title: "The Studio Tour", channel: "Marques Brownlee", views: "812K views", age: "4 days ago", duration: "9:21", imageURL: URL(string: "https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?auto=format&fit=crop&w=900&q=85"), verified: true),
        VideoItem(id: "space", title: "What We Found Beyond Earth", channel: "Mark Rober", views: "6.4M views", age: "1 week ago", duration: "14:08", imageURL: URL(string: "https://images.unsplash.com/photo-1446776811953-b23d57bd21aa?auto=format&fit=crop&w=900&q=85"), verified: true),
        VideoItem(id: "steak", title: "Cooking With Fire", channel: "Tastemade", views: "942K views", age: "2 days ago", duration: "12:03", imageURL: URL(string: "https://images.unsplash.com/photo-1558030006-450675393462?auto=format&fit=crop&w=900&q=85"), verified: false),
        VideoItem(id: "mountains", title: "Alone in the Arctic", channel: "Kara and Nate", views: "1.1M views", age: "6 days ago", duration: "4:12", imageURL: URL(string: "https://images.unsplash.com/photo-1483728642387-6c3bdd6c93e5?auto=format&fit=crop&w=900&q=85"), verified: false)
    ]

    static var sampleFeed: HomeFeed {
        HomeFeed(
            hero: .hero,
            queue: [
                samples[7],
                VideoItem(id: "future", title: "Building the Future", channel: "Mark Rober", views: "", age: "", duration: "15:48", imageURL: URL(string: "https://images.unsplash.com/photo-1518709268805-4e9042af2176?auto=format&fit=crop&w=700&q=85"), verified: false),
                samples[4],
                samples[6]
            ],
            forYou: Array(samples.prefix(4)),
            trending: Array(samples.dropFirst(4)),
            more: []
        )
    }
}
