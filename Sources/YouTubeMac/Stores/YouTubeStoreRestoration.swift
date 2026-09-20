import Foundation

extension YouTubeStore {
    /// Restore durable state before connecting services or starting requests.
    func restorePersistedState() {
        autoMuteOnStart = defaults.object(forKey: DefaultsKey.autoMuteOnStart) as? Bool ?? false
        if let rawTheme = defaults.string(forKey: DefaultsKey.theme),
           let savedTheme = AppTheme(rawValue: rawTheme) {
            theme = savedTheme
        }
        if let rawVisualTheme = defaults.string(forKey: DefaultsKey.visualTheme),
           let savedVisualTheme = YouGlassThemeFamily(rawValue: rawVisualTheme) {
            visualTheme = savedVisualTheme
        }
        backgroundGlow = defaults.object(forKey: DefaultsKey.backgroundGlow) as? Double ?? 0.78
        glassIntensity = defaults.object(forKey: DefaultsKey.glassIntensity) as? Double ?? 0.72
        showContinueWatching = defaults.object(forKey: DefaultsKey.showContinueWatching) as? Bool ?? true
        themeCustomization = decodeThemeCustomization()
        lastAccountSyncDate = defaults.object(forKey: DefaultsKey.lastAccountSyncDate) as? Date
        cachedFeedUpdatedAt = defaults.object(forKey: DefaultsKey.cachedFeedDate) as? Date
        cachedPersonalizedFeedUpdatedAt = defaults.object(forKey: DefaultsKey.cachedPersonalizedFeedDate) as? Date
        cachedSubscriptionsUpdatedAt = defaults.object(forKey: DefaultsKey.cachedSubscriptionsDate) as? Date
        feedLastRefreshedDate = cachedPersonalizedFeedUpdatedAt ?? cachedFeedUpdatedAt
        if let rawCorner = defaults.string(forKey: DefaultsKey.compactPlayerCorner),
           let savedCorner = CompactPlayerCorner(rawValue: rawCorner) {
            compactPlayerCorner = savedCorner
        }
        isSignedIn = defaults.bool(forKey: DefaultsKey.isSignedIn)
        if let urlString = defaults.string(forKey: DefaultsKey.profileImageURL) {
            profileImageURL = URL(string: urlString)
        }
        if isSignedIn {
            subscriptions = decodeSubscriptions()
        }
        recommendationSeeds = decodeRecommendationSeeds()
        recentlyPresentedRecommendationIDs = decodeRecentlyPresentedRecommendationIDs()
        customFeeds = decodeCustomFeeds()
        subscriptionGroups = decodeSubscriptionGroups()
        recentlyWatched = decodeVideos(forKey: DefaultsKey.recentlyWatched)
        savedVideos = decodeVideos(forKey: DefaultsKey.savedVideos)
        locallyLikedVideos = decodeVideos(forKey: DefaultsKey.locallyLikedVideos)
        customCollections = decodeCollections()
        videoNotes = decodeVideoNotes()
        if let data = defaults.data(forKey: DefaultsKey.playbackQueue),
           let state = try? JSONDecoder().decode(YouGlassPlaybackQueueState.self, from: data) {
            playbackQueue = nonShortVideos(state.videos)
            queueAutoplay = state.autoplay
            if playbackQueue.count != state.videos.count {
                persistPlaybackQueue()
            }
        }
        let cachedPersonalizedVideos = decodeVideos(forKey: DefaultsKey.cachedPersonalizedFeed)
        if !cachedPersonalizedVideos.isEmpty {
            _ = applyPrimaryHomeVideos(
                cachedPersonalizedVideos,
                message: "Saved personalized YouTube recommendations",
                cacheFeed: false,
                preserveSourceOrder: defaults.bool(forKey: "YouGlass.cachedHomePreservesYouTubeOrder")
            )
        } else {
            let cachedFeedVideos = decodeVideos(forKey: DefaultsKey.cachedFeed)
            if !cachedFeedVideos.isEmpty {
                _ = applyPrimaryHomeVideos(cachedFeedVideos, message: "Saved YouTube recommendations", cacheFeed: false,
                                          preserveSourceOrder: defaults.bool(forKey: "YouGlass.cachedHomePreservesYouTubeOrder"))
            }
        }
        // Cached feeds and queues can reveal additional Shorts IDs after the
        // first local-library decode. Re-run the small reference cleanup once
        // every video source has been inspected.
        customCollections = decodeCollections()
        videoNotes = decodeVideoNotes()
        playbackPositions = decodePlaybackPositions()
        playbackDurations = decodePlaybackDurations()
        playbackPositionUpdatedAt = decodePlaybackPositionDates()
        persistPlaybackPositions()

    }

    enum DefaultsKey {
        static let isSignedIn = "YouGlass.isSignedIn"
        static let profileImageURL = "YouGlass.profileImageURL"
        static let recommendationSeeds = "YouGlass.recommendationSeeds"
        static let recentlyPresentedRecommendationIDs = "YouGlass.recentlyPresentedRecommendationIDs"
        static let cachedFeed = "YouGlass.cachedFeed"
        static let cachedPersonalizedFeed = "YouGlass.cachedPersonalizedFeed"
        static let cachedFeedDate = "YouGlass.cachedFeedDate"
        static let cachedPersonalizedFeedDate = "YouGlass.cachedPersonalizedFeedDate"
        static let autoMuteOnStart = "YouGlass.autoMuteOnStart"
        static let compactPlayerCorner = "YouGlass.compactPlayerCorner"
        static let recentlyWatched = "YouGlass.recentlyWatched"
        static let savedVideos = "YouGlass.savedVideos"
        static let locallyLikedVideos = "YouGlass.locallyLikedVideos"
        static let playbackPositions = "YouGlass.playbackPositions"
        static let playbackDurations = "YouGlass.playbackDurations"
        static let playbackPositionUpdatedAt = "YouGlass.playbackPositionUpdatedAt"
        static let playbackQueue = "YouGlass.playbackQueue"
        static let customCollections = "YouGlass.customCollections"
        static let videoNotes = "YouGlass.videoNotes"
        static let cachedSubscriptions = "YouGlass.cachedSubscriptions"
        static let cachedSubscriptionsDate = "YouGlass.cachedSubscriptionsDate"
        static let theme = "YouGlass.theme"
        static let visualTheme = YouGlassVisualDefaults.themeFamily
        static let backgroundGlow = YouGlassVisualDefaults.backgroundGlow
        static let glassIntensity = YouGlassVisualDefaults.glassIntensity
        static let lastAccountSyncDate = "YouGlass.lastAccountSyncDate"
        static let showContinueWatching = "YouGlass.showContinueWatching"
        static let themeCustomization = "YouGlass.themeCustomization"
        static let customFeeds = "YouGlass.customFeeds"
    }
}
