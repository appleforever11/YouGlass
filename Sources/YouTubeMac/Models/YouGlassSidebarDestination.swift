import Foundation

/// Stable sidebar destinations; dynamic channel and playlist titles stay separate.
enum YouGlassSidebarDestination: String, Identifiable {
    case home = "Home"
    case explore = "Explore"
    case subscriptions = "Subscriptions"
    case library = "Library"
    case playlists = "Playlists"
    case history = "History"
    case watchLater = "Watch Later"
    case likedVideos = "Liked Videos"

    static let browse: [Self] = [.home, .explore, .subscriptions]
    static let personal: [Self] = [.library, .playlists, .history, .watchLater, .likedVideos]

    var id: Self { self }
    var title: String { rawValue }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .explore: "safari"
        case .subscriptions: "play.rectangle"
        case .library: "rectangle.stack"
        case .playlists: "list.bullet.rectangle"
        case .history: "clock.arrow.circlepath"
        case .watchLater: "bookmark"
        case .likedVideos: "heart"
        }
    }
}
