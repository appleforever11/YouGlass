import Foundation

struct CommentBridgePayload: Decodable {
    let comments: [CommentBridgeItem]
    let totalCount: Int
    let isAvailable: Bool
    let message: String?
    let nextPageToken: String?
    let nextContinuationToken: String?
    let channelID: String?
}

struct CommentBridgeItem: Decodable {
    let id: String
    let author: String
    let text: String
    let age: String
    let likes: String
    let avatarURL: String
}
