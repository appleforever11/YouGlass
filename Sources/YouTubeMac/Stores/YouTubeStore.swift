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
    @Published var searchResults: [VideoItem] = []
    var playbackPositions: [String: Double] = [:]
    var playbackPositionUpdatedAt: [String: Date] = [:]
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
    @Published var ambientPalette = VideoAmbientPalette.neutral
    @Published var lastAccountSyncDate: Date?
    @Published var feedLastRefreshedDate: Date?
    @Published var accountSyncInProgress = false
    @Published var accountSyncStatus: String?

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
    var accountSyncTask: Task<Void, Never>?
    var cachedFeedUpdatedAt: Date?
    var cachedPersonalizedFeedUpdatedAt: Date?
    var cachedSubscriptionsUpdatedAt: Date?
    var cachedAccountSignalVideos: [VideoItem] = []
    var lastAccountSignalLoadDate: Date?
    var subscriptionLoadInProgress = false
    var subscriptionReloadPending = false
    var subscriptionLoadWaiters: [CheckedContinuation<Void, Never>] = []
    var subscriptionsLoaded = false
    var playbackStopHandler: (() -> Void)?
    var playbackStopHandlerToken: UUID?
    var playbackCommandHandler: ((YouGlassPlaybackCommand) -> Void)?
    var playbackCommandHandlerToken: UUID?
    var pipTransitionTask: Task<Void, Never>?
    let defaults = UserDefaults.standard
    let playbackLogger = Logger(subsystem: "com.kevinhowe.YouGlass", category: "playback")

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
        recommendationSeeds = defaults.stringArray(forKey: DefaultsKey.recommendationSeeds) ?? []
        recentlyWatched = decodeVideos(forKey: DefaultsKey.recentlyWatched)
        savedVideos = decodeVideos(forKey: DefaultsKey.savedVideos)
        locallyLikedVideos = decodeVideos(forKey: DefaultsKey.locallyLikedVideos)
        if let data = defaults.data(forKey: DefaultsKey.cachedPersonalizedFeed),
           let cachedVideos = try? JSONDecoder().decode([VideoItem].self, from: data),
           !cachedVideos.isEmpty {
            _ = applyPrimaryHomeVideos(
                cachedVideos,
                message: "Saved personalized YouTube recommendations",
                cacheFeed: false
            )
        } else if let data = defaults.data(forKey: DefaultsKey.cachedFeed),
                  let cachedVideos = try? JSONDecoder().decode([VideoItem].self, from: data),
                  !cachedVideos.isEmpty {
            _ = applyPrimaryHomeVideos(cachedVideos, message: "Saved YouTube recommendations", cacheFeed: false)
        }
        playbackPositions = decodePlaybackPositions()
        playbackPositionUpdatedAt = decodePlaybackPositionDates()

        authObservers = [
            NotificationCenter.default.addObserver(
                forName: .youTubeBrowserDidAuthenticate,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let profileURL = (notification.userInfo?[YouTubeAuthBridge.profileImageURLKey] as? String)
                    .flatMap(URL.init(string:))
                Task { @MainActor in
                    self?.isSignedIn = true
                    self?.connectionMessage = "Signed in to YouTube"
                    self?.defaults.set(true, forKey: DefaultsKey.isSignedIn)
                    if let url = profileURL {
                        self?.profileImageURL = url
                        self?.defaults.set(url.absoluteString, forKey: DefaultsKey.profileImageURL)
                    }
                    self?.lastAccountSyncDate = nil
                    self?.invalidateAccountSignalCache()
                    self?.scheduleSubscriptionsLoad(force: true)
                    self?.scheduleHomeReload(force: true)
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

        YouTubeBrowserWindow.shared.checkAuthenticationState()
    }

    enum DefaultsKey {
        static let isSignedIn = "YouGlass.isSignedIn"
        static let profileImageURL = "YouGlass.profileImageURL"
        static let recommendationSeeds = "YouGlass.recommendationSeeds"
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
        static let playbackPositionUpdatedAt = "YouGlass.playbackPositionUpdatedAt"
        static let cachedSubscriptions = "YouGlass.cachedSubscriptions"
        static let cachedSubscriptionsDate = "YouGlass.cachedSubscriptionsDate"
        static let theme = "YouGlass.theme"
        static let visualTheme = YouGlassVisualDefaults.themeFamily
        static let backgroundGlow = YouGlassVisualDefaults.backgroundGlow
        static let glassIntensity = YouGlassVisualDefaults.glassIntensity
        static let lastAccountSyncDate = "YouGlass.lastAccountSyncDate"
    }
}
