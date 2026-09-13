import Foundation

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
