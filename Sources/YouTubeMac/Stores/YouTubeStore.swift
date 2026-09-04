import AppKit
import OSLog
import SwiftUI

@MainActor
final class YouTubeStore: ObservableObject {
    // SwiftUI may reevaluate a view body from an AttributeGraph transaction
    // that is running on the main thread without carrying the Swift main
    // executor. Keep render-only sidebar snapshots synchronized on the main
    // actor so macOS 27 does not enter the crashing executor-check thunk while
    // diffing subscriptions.
    nonisolated(unsafe) var sidebarSubscriptionsSnapshot: [SubscriptionItem] = []
    nonisolated(unsafe) var sidebarIsSignedInSnapshot = false

    @Published var theme: AppTheme = .light
    @Published var visualTheme: YouGlassThemeFamily = .neoCitrus
    @Published var backgroundGlow = 0.78
    @Published var glassIntensity = 0.72
    @Published var query = ""
    @Published var searchFocusRequestID = UUID()
    @Published var feed = VideoItem.loadingFeed
    @Published var isLoading = false
    @Published var connectionMessage = "Sample feed"
    @Published var sectionEmptyMessage: String?
    @Published var selectedSection = "Home"
    @Published var selectedVideo: VideoItem?
    @Published var selectedChannelItem: SubscriptionItem?
    @Published var channelPage: YouTubeChannelPage?
    @Published var channelLoading = false
    @Published var channelError: String?
    @Published var isSignedIn = false {
        didSet { sidebarIsSignedInSnapshot = isSignedIn }
    }
    @Published var profileImageURL: URL?
    @Published var subscriptions: [SubscriptionItem] = [] {
        didSet { sidebarSubscriptionsSnapshot = subscriptions }
    }
    @Published var recentlyWatched: [VideoItem] = []
    @Published var savedVideos: [VideoItem] = []
    @Published var locallyLikedVideos: [VideoItem] = []
    @Published var customCollections: [YouGlassLibraryCollection] = []
    @Published var videoNotes: [YouGlassVideoNote] = []
    @Published var searchResults: [VideoItem] = []
    var playbackPositions: [String: Double] = [:]
    var playbackDurations: [String: Double] = [:]
    var playbackPositionUpdatedAt: [String: Date] = [:]
    @Published var playbackQueue: [VideoItem] = []
    @Published var queueAutoplay = true
    @Published var playlists: [YouTubePlaylist] = []
    @Published var selectedPlaylist: YouTubePlaylist?
    @Published var playlistItems: [VideoItem] = []
    @Published var playlistLoading = false
    @Published var playlistError: String?
    @Published var commentAuthorizationRequired = false
    @Published var autoMuteOnStart = false
    @Published var isPlayerCompact = false
    @Published var isDesktopPIPActive = false
    @Published var pipTransitionState: PIPTransitionState = .idle
    @Published var compactPlayerCorner: CompactPlayerCorner = .topTrailing
    @Published var showContinueWatching = true
    @Published var commandPalettePresented = false
    @Published var themeCustomization = YouGlassThemeCustomization.empty
    @Published var isNetworkAvailable = true
    @Published var networkStatus = "Checking connection..."
    @Published var ambientPalette = VideoAmbientPalette.neutral
    @Published var lastAccountSyncDate: Date?
    @Published var feedLastRefreshedDate: Date?
    @Published var accountSyncInProgress = false
    @Published var accountSyncStatus: String?
    @Published var customFeeds: [YouGlassCustomFeed] = []
    @Published var selectedCustomFeedID: UUID?
    @Published var customFeedVideos: [VideoItem] = []
    @Published var customFeedLoading = false
    @Published var customFeedMessage: String?
    @Published var customFeedComposerPresented = false
    @Published var editingCustomFeedID: UUID?

    var client = YouTubeAPIClient()
    let oauth = YouTubeOAuthClient.shared
    let safariHomeFeed = SafariHomeFeedClient()
    let subscriptionBridge = YouTubeSubscriptionBridge.shared
    let channelBridge = YouTubeChannelBridge.shared
    let commentsBridge = YouTubeCommentsBridge.shared
    let liveChatBridge = YouTubeLiveChatBridge.shared
    var recommendationSeeds: [String] = []
    var authObservers: [NSObjectProtocol] = []
    var homeLoadInProgress = false
    var homeReloadPending = false
    var homeReloadPendingForce = false
    var lastHomeLoadDate: Date?
    var scheduledHomeReloadTask: Task<Void, Never>?
    var homeRefreshTask: Task<Void, Never>?
    var sectionLoadTask: Task<Void, Never>?
    var sectionLoadGeneration = 0
    var accountSyncTask: Task<Void, Never>?
    var accountSyncGeneration = 0
    var channelLoadTask: Task<Void, Never>?
    var channelLoadGeneration = 0
    var videoResolutionTask: Task<Void, Never>?
    var videoResolutionGeneration = 0
    var playlistLoadTask: Task<Void, Never>?
    var playlistLoadGeneration = 0
    var cachedFeedUpdatedAt: Date?
    var cachedPersonalizedFeedUpdatedAt: Date?
    var cachedSubscriptionsUpdatedAt: Date?
    var cachedAccountSignalVideos: [VideoItem] = []
    var lastAccountSignalLoadDate: Date?
    var recentlyPresentedRecommendationIDs: [String] = []
    var subscriptionLoadInProgress = false
    var subscriptionReloadPending = false
    var subscriptionLoadWaiters: [CheckedContinuation<Void, Never>] = []
    var subscriptionsLoaded = false
    var playbackStopHandler: (() -> Void)?
    var playbackStopHandlerToken: UUID?
    var playbackCommandHandler: ((YouGlassPlaybackCommand) -> Void)?
    var playbackCommandHandlerToken: UUID?
    var pipTransitionTask: Task<Void, Never>?
    var networkMonitor: YouGlassNetworkMonitor?
    let defaults = UserDefaults.standard
    let playbackLogger = Logger(subsystem: "com.kevinhowe.YouGlass", category: "playback")
    var excludedShortFormIDs: Set<String> = []
    var customFeedTask: Task<Void, Never>?
    var customFeedGeneration = 0

    var isDesktopPIPTransitioning: Bool {
        pipTransitionState.isTransitioning
    }

    init() {
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
                cacheFeed: false
            )
        } else {
            let cachedFeedVideos = decodeVideos(forKey: DefaultsKey.cachedFeed)
            if !cachedFeedVideos.isEmpty {
                _ = applyPrimaryHomeVideos(cachedFeedVideos, message: "Saved YouTube recommendations", cacheFeed: false)
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

        networkMonitor = YouGlassNetworkMonitor { [weak self] isAvailable in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isNetworkAvailable = isAvailable
                self.networkStatus = isAvailable ? "Online" : "Offline — using saved data"
            }
        }
        networkMonitor?.start()
        YouGlassDockMenuController.shared.store = self

        authObservers = [
            NotificationCenter.default.addObserver(
                forName: .youTubeBrowserDidAuthenticate,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let profileURL = (notification.userInfo?[YouTubeAuthBridge.profileImageURLKey] as? String)
                    .flatMap(URL.init(string:))
                Task { @MainActor in
                    guard let self else { return }
                    self.isSignedIn = true
                    self.connectionMessage = "Signed in to YouTube"
                    self.defaults.set(true, forKey: DefaultsKey.isSignedIn)
                    if let url = profileURL {
                        self.profileImageURL = url
                        self.defaults.set(url.absoluteString, forKey: DefaultsKey.profileImageURL)
                    } else {
                        await self.refreshProfileImage()
                    }
                    self.lastAccountSyncDate = nil
                    self.invalidateAccountSignalCache()
                    self.scheduleSubscriptionsLoad(force: true)
                    self.scheduleHomeReload(force: true)
                }
            },
            NotificationCenter.default.addObserver(
                forName: .youTubeBrowserDidSignOut,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.isSignedIn = false
                    self?.subscriptions = []
                    self?.subscriptionsLoaded = false
                    self?.profileImageURL = nil
                    self?.lastAccountSyncDate = nil
                    self?.invalidateAccountSignalCache()
                    self?.clearRecentlyPresentedRecommendations()
                    self?.cachedSubscriptionsUpdatedAt = nil
                    self?.defaults.set(false, forKey: DefaultsKey.isSignedIn)
                    self?.defaults.removeObject(forKey: DefaultsKey.profileImageURL)
                    self?.defaults.removeObject(forKey: DefaultsKey.cachedSubscriptions)
                    self?.defaults.removeObject(forKey: DefaultsKey.cachedSubscriptionsDate)
                    self?.defaults.removeObject(forKey: DefaultsKey.cachedPersonalizedFeed)
                    self?.defaults.removeObject(forKey: DefaultsKey.cachedPersonalizedFeedDate)
                    self?.defaults.removeObject(forKey: DefaultsKey.lastAccountSyncDate)
                    self?.cachedPersonalizedFeedUpdatedAt = nil
                    self?.feedLastRefreshedDate = self?.cachedFeedUpdatedAt
                    self?.scheduleHomeReload(force: true)
                }
            }
        ]

        if isSignedIn {
            Task { @MainActor [weak self] in
                await self?.refreshProfileImage()
            }
        }

        YouTubeBrowserWindow.shared.checkAuthenticationState()
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
