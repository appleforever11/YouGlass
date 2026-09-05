import Foundation

struct YouTubeAPIErrorEnvelope: Decodable {
    let error: YouTubeAPIErrorBody?
}

struct YouTubeAPIErrorBody: Decodable {
    let message: String?
    let errors: [YouTubeAPIErrorDetail]?
}

struct YouTubeAPIErrorDetail: Decodable {
    let reason: String?
}

struct SearchResponse: Decodable {
    let items: [SearchItem]
}

struct SearchItem: Decodable {
    struct ID: Decodable {
        let videoId: String?
    }

    let id: ID
    let snippet: Snippet
}

struct VideoListResponse: Decodable {
    let items: [VideoListItem]
}

struct VideoListItem: Decodable {
    let id: String
    let snippet: Snippet
    let statistics: VideoStatistics?
    let contentDetails: VideoContentDetails?
    let liveStreamingDetails: VideoLiveStreamingDetails?
}

struct VideoStatistics: Decodable {
    let viewCount: String?
    let likeCount: String?
    let commentCount: String?
}

struct VideoLiveStreamingDetails: Decodable {
    let concurrentViewers: String?
    let activeLiveChatID: String?
    let actualStartTime: String?
    let actualEndTime: String?

    enum CodingKeys: String, CodingKey {
        case concurrentViewers
        case activeLiveChatID = "activeLiveChatId"
        case actualStartTime
        case actualEndTime
    }

    var isCurrentlyLive: Bool {
        activeLiveChatID != nil || (actualStartTime != nil && actualEndTime == nil)
    }
}

struct VideoContentDetails: Decodable {
    let duration: String

    var displayDuration: String {
        var hours = 0
        var minutes = 0
        var seconds = 0
        var number = ""

        for character in duration {
            if character.isNumber {
                number.append(character)
            } else {
                let value = Int(number) ?? 0
                if character == "H" { hours = value }
                if character == "M" { minutes = value }
                if character == "S" { seconds = value }
                number = ""
            }
        }

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct Snippet: Decodable {
    let publishedAt: Date
    let title: String
    let channelTitle: String
    let channelID: String?
    let videoOwnerChannelTitle: String?
    let description: String
    let thumbnails: ThumbnailSet

    var relativePublishedDate: String {
        let days = max(1, Calendar.current.dateComponents([.day], from: publishedAt, to: Date()).day ?? 1)
        if days < 7 { return days == 1 ? "1 day ago" : "\(days) days ago" }
        let weeks = days / 7
        if weeks < 5 { return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago" }
        let months = max(1, days / 30)
        return months == 1 ? "1 month ago" : "\(months) months ago"
    }

    enum CodingKeys: String, CodingKey {
        case publishedAt
        case title
        case channelTitle
        case channelID = "channelId"
        case videoOwnerChannelTitle
        case description
        case thumbnails
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        channelTitle = try container.decode(String.self, forKey: .channelTitle)
        channelID = try container.decodeIfPresent(String.self, forKey: .channelID)
        videoOwnerChannelTitle = try container.decodeIfPresent(String.self, forKey: .videoOwnerChannelTitle)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        thumbnails = try container.decode(ThumbnailSet.self, forKey: .thumbnails)
        let dateString = try container.decode(String.self, forKey: .publishedAt)
        publishedAt = ISO8601DateFormatter().date(from: dateString) ?? Date()
    }
}

struct ThumbnailSet: Decodable {
    let defaultThumbnail: Thumbnail
    let medium: Thumbnail?
    let high: Thumbnail?

    enum CodingKeys: String, CodingKey {
        case defaultThumbnail = "default"
        case medium
        case high
    }
}

struct Thumbnail: Decodable {
    let url: String
}

struct ChannelListResponse: Decodable {
    let items: [ChannelResource]
}

struct ChannelResource: Decodable {
    let id: String
    let snippet: ChannelSnippet
    let contentDetails: ChannelContentDetails?
    let statistics: ChannelStatistics?
    let brandingSettings: ChannelBrandingSettings?
}

struct ChannelSnippet: Decodable {
    let title: String
    let description: String
    let customURL: String?
    let thumbnails: ThumbnailSet

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case customURL = "customUrl"
        case thumbnails
    }
}

struct ChannelContentDetails: Decodable {
    let relatedPlaylists: RelatedPlaylists
}

struct RelatedPlaylists: Decodable {
    let uploads: String
}

struct ChannelStatistics: Decodable {
    let subscriberCount: String?
    let hiddenSubscriberCount: Bool?
    let videoCount: String?
}

struct ChannelBrandingSettings: Decodable {
    let image: ChannelBrandingImage?
}

struct ChannelBrandingImage: Decodable {
    let bannerExternalURL: String?

    enum CodingKeys: String, CodingKey {
        case bannerExternalURL = "bannerExternalUrl"
    }
}

struct SubscriptionResponse: Decodable {
    let items: [SubscriptionItemResponse]
    let nextPageToken: String?
}

struct SubscriptionItemResponse: Decodable {
    let snippet: SubscriptionSnippet
}

struct SubscriptionSnippet: Decodable {
    let title: String
    let thumbnails: ThumbnailSet
    let resourceID: SubscriptionResourceID?

    enum CodingKeys: String, CodingKey {
        case title
        case thumbnails
        case resourceID = "resourceId"
    }
}

struct SubscriptionResourceID: Decodable {
    let channelID: String

    enum CodingKeys: String, CodingKey {
        case channelID = "channelId"
    }
}

struct PlaylistListResponse: Decodable {
    let items: [PlaylistResource]
    let nextPageToken: String?
}

struct PlaylistResource: Decodable {
    let id: String
    let snippet: PlaylistSnippet
    let contentDetails: PlaylistDetails?
}

struct PlaylistSnippet: Decodable {
    let title: String
    let description: String
    let thumbnails: ThumbnailSet
}

struct PlaylistDetails: Decodable {
    let itemCount: Int?
}

struct PlaylistItemsResponse: Decodable {
    let items: [PlaylistItemResponse]
    let nextPageToken: String?
}

struct PlaylistItemResponse: Decodable {
    let snippet: Snippet
    let contentDetails: PlaylistContentDetails
}

struct PlaylistContentDetails: Decodable {
    let videoId: String
}

struct CommentThreadResponse: Decodable {
    let items: [CommentThreadItem]
    let pageInfo: PageInfo?
    let nextPageToken: String?
}

struct PageInfo: Decodable {
    let totalResults: Int?
}

struct CommentThreadItem: Decodable {
    let id: String
    let snippet: CommentThreadSnippet
}

struct CommentThreadSnippet: Decodable {
    let topLevelComment: TopLevelComment?
}

struct TopLevelComment: Decodable {
    let snippet: CommentSnippet
}

struct CommentSnippet: Decodable {
    let authorDisplayName: String
    let authorProfileImageUrl: String
    let textDisplay: String
    let likeCount: Int
    let publishedAt: Date

    var relativePublishedDate: String {
        let days = max(1, Calendar.current.dateComponents([.day], from: publishedAt, to: Date()).day ?? 1)
        if days < 7 { return days == 1 ? "1 day ago" : "\(days) days ago" }
        let weeks = days / 7
        if weeks < 5 { return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago" }
        let months = max(1, days / 30)
        if months < 12 { return months == 1 ? "1 month ago" : "\(months) months ago" }
        let years = max(1, days / 365)
        return years == 1 ? "1 year ago" : "\(years) years ago"
    }

    enum CodingKeys: CodingKey {
        case authorDisplayName
        case authorProfileImageUrl
        case textDisplay
        case likeCount
        case publishedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        authorDisplayName = try container.decode(String.self, forKey: .authorDisplayName)
        authorProfileImageUrl = try container.decode(String.self, forKey: .authorProfileImageUrl)
        textDisplay = try container.decode(String.self, forKey: .textDisplay)
        likeCount = try container.decode(Int.self, forKey: .likeCount)
        let dateString = try container.decode(String.self, forKey: .publishedAt)
        publishedAt = ISO8601DateFormatter().date(from: dateString) ?? Date()
    }
}

struct RatingResponse: Decodable {
    let items: [RatingItem]
}

struct RatingItem: Decodable {
    let videoID: String
    let rating: String

    enum CodingKeys: String, CodingKey {
        case videoID = "videoId"
        case rating
    }
}

struct LiveChatResponse: Decodable {
    let items: [LiveChatItem]
    let nextPageToken: String?
    let pollingIntervalMillis: Int?
}

struct LiveChatItem: Decodable {
    let id: String
    let snippet: LiveChatSnippet
    let authorDetails: LiveChatAuthor?
}

struct LiveChatSnippet: Decodable {
    let type: String
    let displayMessage: String?
    let publishedAt: String?
}

struct LiveChatAuthor: Decodable {
    let displayName: String
    let profileImageURL: String?

    enum CodingKeys: String, CodingKey {
        case displayName
        case profileImageURL = "profileImageUrl"
    }
}

extension Int {
    var abbreviated: String {
        if self >= 1_000_000 { return "\(self / 1_000_000)M" }
        if self >= 1_000 { return "\(self / 1_000)K" }
        return "\(self)"
    }
}

extension String {
    var abbreviatedCount: String {
        guard let value = Int(self) else { return self }
        if value >= 1_000_000_000 { return String(format: "%.1fB", Double(value) / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", Double(value) / 1_000) }
        return "\(value)"
    }

    var abbreviatedViews: String {
        guard let value = Int(self) else { return "YouTube" }
        if value >= 1_000_000 { return "\(value / 1_000_000)M views" }
        if value >= 1_000 { return "\(value / 1_000)K views" }
        return "\(value) views"
    }
}

func relativeDate(_ value: String) -> String {
    guard let date = ISO8601DateFormatter().date(from: value) else { return "now" }
    let seconds = max(1, Int(Date().timeIntervalSince(date)))
    if seconds < 60 { return "now" }
    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes)m" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours)h" }
    return "\(hours / 24)d"
}

extension String {
    var htmlDecoded: String {
        replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
