import Foundation

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
