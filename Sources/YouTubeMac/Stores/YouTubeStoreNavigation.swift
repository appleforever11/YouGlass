import Foundation

extension YouTubeStore {
    var route: YouGlassRoute {
        if let channel = selectedChannelItem { return .channel(channel.id) }
        if let playlist = selectedPlaylist { return .playlist(playlist.id) }
        if let id = selectedCustomFeedID { return .customFeed(id) }
        if let id = selectedSubscriptionGroupID { return .subscriptionGroup(id) }
        if selectedSection == "Search" { return .search }
        if let destination = YouGlassSidebarDestination(rawValue: selectedSection) {
            return .destination(destination)
        }
        return .recommendations(selectedSection)
    }

    /// Every destination transition retires competing loads before replacing UI.
    @discardableResult
    func beginNavigation() -> Int {
        let generation = sectionRequests.invalidate()
        channelLoadTask?.cancel()
        channelLoadTask = nil
        channelLoadGeneration &+= 1
        playlistLoadTask?.cancel()
        playlistLoadTask = nil
        playlistLoadGeneration &+= 1
        clearSelectedCustomFeed()
        selectedChannelItem = nil
        channelPage = nil
        channelError = nil
        channelLoading = false
        selectedPlaylist = nil
        playlistItems = []
        playlistError = nil
        playlistLoading = false
        sectionEmptyMessage = nil
        isLoading = false
        searchState.isLoading = false
        if selectedVideo != nil && !isPlayerCompact && !isDesktopPIPActive { minimizePlayer() }
        return generation
    }

    func invalidateAccountRequests() {
        accountSessionGeneration &+= 1
        accountSyncTask?.cancel()
        accountSyncTask = nil
        accountSyncGeneration &+= 1
        accountSyncInProgress = false
        scheduledHomeReloadTask?.cancel()
        scheduledHomeReloadTask = nil
        homeReloadPending = false
        homeReloadPendingForce = false
        searchState.results = []
        searchState.message = ""
        searchState.emptyMessage = nil
        _ = beginNavigation()
    }
}
