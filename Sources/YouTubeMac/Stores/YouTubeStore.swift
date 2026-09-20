import AppKit
import OSLog
import SwiftUI

@MainActor
final class YouTubeStore: ObservableObject {
    // Surface changes do not create another YouTube page or forward ticks to Home.
    let playbackController = YouTubePlaybackController()
    // SwiftUI may reevaluate a view body from an AttributeGraph transaction
    // that is running on the main thread without carrying the Swift main
    // executor. Keep render-only sidebar snapshots synchronized on the main
    // actor so macOS 27 does not enter the crashing executor-check thunk while
    // diffing subscriptions.
    nonisolated(unsafe) var sidebarSubscriptionsSnapshot: [SubscriptionItem] = []
    nonisolated(unsafe) var sidebarIsSignedInSnapshot = false
    nonisolated(unsafe) var sidebarSubscriptionGroupsSnapshot: [SubscriptionGroup] = []

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
    @Published var isInlinePlayerTransitioning = false
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
    @Published var subscriptionGroups: [SubscriptionGroup] = [] {
        didSet { sidebarSubscriptionGroupsSnapshot = subscriptionGroups }
    }
    @Published var selectedSubscriptionGroupID: UUID?
    @Published var subscriptionGroupVideos: [VideoItem] = []
    @Published var subscriptionGroupMessage: String?
    @Published var subscriptionGroupEditorPresented = false
    @Published var editingSubscriptionGroup: SubscriptionGroup?
    @Published var homeRecommendationsAreFromYouTube = false

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
    var inlinePlayerTransitionTask: Task<Void, Never>?
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
        restorePersistedState()
        connectRuntimeServices()
    }
}
