import Foundation

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
    let playlists: [YouTubePlaylist]
}

enum YouGlassPlaybackCommand: Sendable {
    case togglePlayback
    case seek(Double)
    case toggleMute
    case toggleCaptions
    case retry
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
