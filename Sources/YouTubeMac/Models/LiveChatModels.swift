import Foundation

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
