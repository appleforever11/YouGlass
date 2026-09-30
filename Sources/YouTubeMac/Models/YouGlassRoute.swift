import Foundation

/// Identity, rather than a mutable display title, owns the browse viewport.
enum YouGlassRoute: Hashable {
    case destination(YouGlassSidebarDestination)
    case search
    case channel(String)
    case playlist(String)
    case customFeed(UUID)
    case subscriptionGroup(UUID)
    case recommendations(String)
}
