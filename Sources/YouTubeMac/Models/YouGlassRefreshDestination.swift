import Foundation

/// The same refresh decision is used by menus, the toolbar, and the palette.
enum YouGlassRefreshDestination: Equatable {
    case unavailable
    case home
    case search
    case customFeed
    case section(String)

    init(section: String, hasCustomFeed: Bool, hasChannel: Bool, hasPlaylist: Bool) {
        if hasChannel || hasPlaylist {
            self = .unavailable
        } else if hasCustomFeed {
            self = .customFeed
        } else {
            switch section {
            case "Library", "Explore", "Notifications": self = .unavailable
            case "Home", "For You", "Trending", "More to watch": self = .home
            case "Search": self = .search
            default: self = .section(section)
            }
        }
    }
}
