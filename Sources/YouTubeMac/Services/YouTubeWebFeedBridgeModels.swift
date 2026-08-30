import Foundation

struct WebFeedPayload: Decodable {
    let items: [WebFeedEntry]
    let signedIn: Bool
    let profileImageURL: String?
    let title: String
    let url: String
    let initialCount: Int
    let domCount: Int
}

struct WebFeedEntry: Decodable {
    let id: String
    let title: String
    let channel: String
    let views: String
    let age: String
    let duration: String
    let imageURL: String
}
