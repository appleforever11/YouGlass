import Foundation

extension YouTubeStore {
    var refreshDestination: YouGlassRefreshDestination {
        YouGlassRefreshDestination(
            section: selectedSection,
            hasCustomFeed: selectedCustomFeed != nil,
            hasChannel: selectedChannelItem != nil,
            hasPlaylist: selectedPlaylist != nil
        )
    }

    var canRefreshCurrentDestination: Bool {
        refreshDestination != .unavailable && !isLoading && !customFeedLoading
    }

    func refreshCurrentDestination() {
        guard canRefreshCurrentDestination else { return }
        switch refreshDestination {
        case .unavailable: break
        case .home:
            Task { await loadHome(force: true) }
        case .search: startSearch()
        case .customFeed: refreshSelectedCustomFeed()
        case .section(let title): showSection(title)
        }
    }
}
