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
