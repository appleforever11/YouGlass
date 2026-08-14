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
    nonisolated(unsafe) private(set) var sidebarSubscriptionsSnapshot: [SubscriptionItem] = []
    nonisolated(unsafe) private(set) var sidebarIsSignedInSnapshot = false

    @Published var theme: AppTheme = .dark
    @Published var query = ""
    @Published var feed = VideoItem.sampleFeed
    @Published var isLoading = false
    @Published var connectionMessage = "Sample feed"
    @Published private(set) var sectionEmptyMessage: String?
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
    @Published private(set) var recentlyWatched: [VideoItem] = []
    @Published private(set) var savedVideos: [VideoItem] = []
    @Published private(set) var locallyLikedVideos: [VideoItem] = []
    @Published private(set) var searchResults: [VideoItem] = []
    private var playbackPositions: [String: Double] = [:]
    private var playbackPositionUpdatedAt: [String: Date] = [:]
    @Published private(set) var playlists: [YouTubePlaylist] = []
    @Published var selectedPlaylist: YouTubePlaylist?
    @Published private(set) var playlistItems: [VideoItem] = []
    @Published var playlistLoading = false
    @Published var playlistError: String?
    @Published var commentAuthorizationRequired = false
    @Published var autoMuteOnStart = false
    @Published var isPlayerCompact = false
    @Published private(set) var isDesktopPIPActive = false
    @Published private(set) var pipTransitionState: PIPTransitionState = .idle
    @Published var compactPlayerCorner: CompactPlayerCorner = .topTrailing
    @Published private(set) var ambientPalette = VideoAmbientPalette.neutral
    @Published private(set) var lastAccountSyncDate: Date?

    private var client = YouTubeAPIClient()
    private let oauth = YouTubeOAuthClient.shared
    private let safariHomeFeed = SafariHomeFeedClient()
    private let subscriptionBridge = YouTubeSubscriptionBridge.shared
    private let channelBridge = YouTubeChannelBridge.shared
    private let commentsBridge = YouTubeCommentsBridge.shared
    private let liveChatBridge = YouTubeLiveChatBridge.shared
    private var recommendationSeeds: [String] = []
    private var authObservers: [NSObjectProtocol] = []
    private var homeLoadInProgress = false
    private var homeReloadPending = false
    private var homeReloadPendingForce = false
    private var lastHomeLoadDate: Date?
    private var cachedFeedUpdatedAt: Date?
    private var cachedPersonalizedFeedUpdatedAt: Date?
    private var cachedSubscriptionsUpdatedAt: Date?
    private var cachedAccountSignalVideos: [VideoItem] = []
    private var lastAccountSignalLoadDate: Date?
    private var subscriptionLoadInProgress = false
    private var subscriptionReloadPending = false
    private var subscriptionLoadWaiters: [CheckedContinuation<Void, Never>] = []
    private var subscriptionsLoaded = false
    private var playbackStopHandler: (() -> Void)?
    private var playbackStopHandlerToken: UUID?
    private var pipTransitionTask: Task<Void, Never>?
    private let defaults = UserDefaults.standard
    private let playbackLogger = Logger(subsystem: "com.kevinhowe.YouGlass", category: "playback")

    var isDesktopPIPTransitioning: Bool {
        pipTransitionState.isTransitioning
    }

    private enum DefaultsKey {
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
        static let lastAccountSyncDate = "YouGlass.lastAccountSyncDate"
    }

    init() {
        autoMuteOnStart = defaults.object(forKey: DefaultsKey.autoMuteOnStart) as? Bool ?? false
        if let rawTheme = defaults.string(forKey: DefaultsKey.theme),
           let savedTheme = AppTheme(rawValue: rawTheme) {
            theme = savedTheme
        }
        lastAccountSyncDate = defaults.object(forKey: DefaultsKey.lastAccountSyncDate) as? Date
        cachedFeedUpdatedAt = defaults.object(forKey: DefaultsKey.cachedFeedDate) as? Date
        cachedPersonalizedFeedUpdatedAt = defaults.object(forKey: DefaultsKey.cachedPersonalizedFeedDate) as? Date
        cachedSubscriptionsUpdatedAt = defaults.object(forKey: DefaultsKey.cachedSubscriptionsDate) as? Date
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
                }
            }
        ]

        YouTubeBrowserWindow.shared.checkAuthenticationState()
    }

    var colorScheme: ColorScheme {
        theme.colorScheme
    }

    func setTheme(_ theme: AppTheme) {
        self.theme = theme
        defaults.set(theme.rawValue, forKey: DefaultsKey.theme)
    }

    func setAmbientPalette(_ palette: VideoAmbientPalette) {
        ambientPalette = palette
    }

    func resetAmbientPalette() {
        ambientPalette = .neutral
    }

    @discardableResult
    func registerPlaybackStopHandler(_ handler: @escaping () -> Void) -> UUID {
        playbackStopHandler = handler
        let token = UUID()
        playbackStopHandlerToken = token
        return token
    }

    func unregisterPlaybackStopHandler() {
        playbackStopHandler = nil
        playbackStopHandlerToken = nil
    }

    func unregisterPlaybackStopHandler(_ token: UUID) {
        guard playbackStopHandlerToken == token else { return }
        playbackStopHandler = nil
        playbackStopHandlerToken = nil
    }

    var hasDataAPIKey: Bool { client.canConnect }

    var hasOAuthClientID: Bool { oauth.hasClientID }

    var hasOAuthClientSecret: Bool { oauth.hasClientSecret }

    func saveDataAPIKey(_ value: String) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        KeychainStore.write(clean, service: "com.kevinhowe.YouGlass", account: "YOUTUBE_API_KEY")
        client = YouTubeAPIClient(apiKey: clean, oauth: oauth)
        invalidateAccountSignalCache()
        connectionMessage = "YouTube Data API key saved"
    }

    func saveOAuthClientID(_ value: String) {
        oauth.saveClientID(value)
        invalidateAccountSignalCache()
        connectionMessage = oauth.hasClientID
            ? "Google OAuth client ID saved"
            : "Google OAuth client ID is empty"
    }

    func saveOAuthClientSecret(_ value: String) {
        oauth.saveClientSecret(value)
        invalidateAccountSignalCache()
        connectionMessage = oauth.hasClientSecret
            ? "Google OAuth client secret saved"
            : "Google OAuth client secret is empty"
    }

    func resetYouTubeCredentials() {
        oauth.clearStoredCredentials()
        KeychainStore.remove(service: "com.kevinhowe.YouGlass", account: "YOUTUBE_API_KEY")
        client = YouTubeAPIClient(oauth: oauth)
        isSignedIn = false
        profileImageURL = nil
        subscriptions = []
        subscriptionsLoaded = false
        defaults.removeObject(forKey: DefaultsKey.cachedSubscriptions)
        defaults.removeObject(forKey: DefaultsKey.cachedSubscriptionsDate)
        cachedSubscriptionsUpdatedAt = nil
        lastAccountSyncDate = nil
        recommendationSeeds = []
        invalidateAccountSignalCache()
        defaults.set(false, forKey: DefaultsKey.isSignedIn)
        defaults.removeObject(forKey: DefaultsKey.profileImageURL)
        defaults.removeObject(forKey: DefaultsKey.recommendationSeeds)
        defaults.removeObject(forKey: DefaultsKey.cachedPersonalizedFeed)
        defaults.removeObject(forKey: DefaultsKey.cachedPersonalizedFeedDate)
        defaults.removeObject(forKey: DefaultsKey.lastAccountSyncDate)
        cachedPersonalizedFeedUpdatedAt = nil
        YouTubeBrowserWindow.shared.clearAuthenticationSession()
        connectionMessage = "YouTube sign-in data reset"
    }

    func clearCachedRecommendationData() {
        defaults.removeObject(forKey: DefaultsKey.cachedFeed)
        defaults.removeObject(forKey: DefaultsKey.cachedFeedDate)
        defaults.removeObject(forKey: DefaultsKey.cachedPersonalizedFeed)
        defaults.removeObject(forKey: DefaultsKey.cachedPersonalizedFeedDate)
        cachedFeedUpdatedAt = nil
        cachedPersonalizedFeedUpdatedAt = nil
        cachedAccountSignalVideos = []
        feed = VideoItem.sampleFeed
        sectionEmptyMessage = nil
        connectionMessage = "Cached recommendation data cleared"
    }

    func setAutoMuteOnStart(_ value: Bool) {
        autoMuteOnStart = value
        defaults.set(value, forKey: DefaultsKey.autoMuteOnStart)
        connectionMessage = value
            ? "Videos will start muted"
            : "Videos will start with audio"
    }

    func setCompactPlayerCorner(_ corner: CompactPlayerCorner) {
        compactPlayerCorner = corner
        defaults.set(corner.rawValue, forKey: DefaultsKey.compactPlayerCorner)
    }

    func playbackPosition(for videoID: String) -> Double {
        let position = playbackPositions[videoID] ?? 0
        return position.isFinite ? max(0, position) : 0
    }

    func savePlaybackPosition(for video: VideoItem, at seconds: Double, duration: Double) {
        guard seconds.isFinite, seconds > 1 else { return }

        let safePosition = max(0, seconds)
        let hasFiniteDuration = duration.isFinite && duration > 0
        let isNearCompletion = hasFiniteDuration && (
            safePosition >= max(0, duration - PlaybackCheckpointPolicy.completionGraceSeconds) ||
            safePosition / duration >= PlaybackCheckpointPolicy.completionFraction
        )

        if isNearCompletion {
            playbackPositions.removeValue(forKey: video.id)
            playbackPositionUpdatedAt.removeValue(forKey: video.id)
        } else {
            playbackPositions[video.id] = hasFiniteDuration
                ? min(safePosition, duration)
                : safePosition
            playbackPositionUpdatedAt[video.id] = Date()
        }

        // Keep the resume cache bounded so a long-lived account does not turn
        // playback checkpoints into unbounded UserDefaults data.
        if playbackPositions.count > PlaybackCheckpointPolicy.maxEntries {
            let excessCount = playbackPositions.count - PlaybackCheckpointPolicy.maxEntries
            let excessIDs = playbackPositions.keys.sorted { lhs, rhs in
                let lhsDate = playbackPositionUpdatedAt[lhs] ?? .distantPast
                let rhsDate = playbackPositionUpdatedAt[rhs] ?? .distantPast
                if lhsDate == rhsDate { return lhs < rhs }
                return lhsDate < rhsDate
            }.prefix(excessCount)
            excessIDs.forEach {
                playbackPositions.removeValue(forKey: $0)
                playbackPositionUpdatedAt.removeValue(forKey: $0)
            }
        }
        persistPlaybackPositions()
    }

    func isSaved(_ video: VideoItem) -> Bool {
        savedVideos.contains { $0.id == video.id }
    }

    func toggleSaved(_ video: VideoItem) {
        if isSaved(video) {
            savedVideos.removeAll { $0.id == video.id }
        } else {
            savedVideos.insert(video, at: 0)
        }
        savedVideos = Array(savedVideos.prefix(100))
        persistVideos(savedVideos, key: DefaultsKey.savedVideos)
    }

    func isLocallyLiked(_ video: VideoItem) -> Bool {
        locallyLikedVideos.contains { $0.id == video.id }
    }

    func isSubscribed(channelID: String?, channelName: String) -> Bool {
        subscriptions.contains { subscription in
            subscription.matches(channelID: channelID, channelName: channelName)
        }
    }

    func resolveSubscriptionStatus(channelID: String?, channelName: String) async -> Bool {
        guard isSignedIn else { return false }
        await loadSubscriptions(force: false)
        return isSubscribed(channelID: channelID, channelName: channelName)
    }

    func recordLocalRating(for video: VideoItem, liked: Bool) {
        locallyLikedVideos.removeAll { $0.id == video.id }
        if liked { locallyLikedVideos.insert(video, at: 0) }
        locallyLikedVideos = Array(locallyLikedVideos.prefix(100))
        persistVideos(locallyLikedVideos, key: DefaultsKey.locallyLikedVideos)
    }

    func loadHome(force: Bool = false) async {
        guard !homeLoadInProgress else {
            homeReloadPending = true
            homeReloadPendingForce = homeReloadPendingForce || force
            return
        }

        if !force,
           let lastHomeLoadDate,
           Date().timeIntervalSince(lastHomeLoadDate) < 15,
           !feed.forYou.isEmpty || !feed.trending.isEmpty || !feed.more.isEmpty || !feed.queue.isEmpty {
            return
        }

        homeLoadInProgress = true
        isLoading = true
        sectionEmptyMessage = nil
        YouGlassDiagnostics.feed.info("Home load started; forced: \(force, privacy: .public)")
        YouGlassDiagnostics.record(
            .info,
            category: "feed",
            message: "Home feed load started",
            metadata: ["forced": String(force)]
        )
        if feed.forYou.isEmpty && feed.trending.isEmpty && feed.more.isEmpty && feed.queue.isEmpty,
           let data = defaults.data(forKey: DefaultsKey.cachedFeed),
           let cachedVideos = try? JSONDecoder().decode([VideoItem].self, from: data),
           !cachedVideos.isEmpty {
            if let age = YouGlassCachePolicy.age(of: cachedFeedUpdatedAt) {
                YouGlassDiagnostics.feed.debug("Restoring cached feed age: \(age, privacy: .public) seconds")
            }
            _ = applyPrimaryHomeVideos(
                cachedVideos,
                message: "Saved YouTube recommendations",
                cacheFeed: false
            )
        }
        defer {
            isLoading = false
            homeLoadInProgress = false
            lastHomeLoadDate = Date()
            YouGlassDiagnostics.feed.info("Home load finished")
            YouGlassDiagnostics.record(.info, category: "feed", message: "Home feed load finished")
            if homeReloadPending {
                homeReloadPending = false
                let pendingForce = homeReloadPendingForce
                homeReloadPendingForce = false
                Task { @MainActor [weak self] in
                    await self?.loadHome(force: pendingForce)
                }
            }
        }

        connectionMessage = "Loading YouTube homepage recommendations..."
        let webResult = await YouTubeWebFeedBridge.shared.loadHomeVideos(maxResults: 32)
        if webResult.isSignedIn && !isSignedIn {
            isSignedIn = true
            defaults.set(true, forKey: DefaultsKey.isSignedIn)
        }

        if isSignedIn {
            // The hidden YouTube homepage can return a Shorts-only public
            // surface even when the account session is valid. Build the
            // account feed from the user's actual subscriptions first.
            await loadSubscriptions(force: false)
            let personalized = await personalizedAccountFeed(
                webHomepageVideos: webResult.isSignedIn ? webResult.videos : []
            )
            if !personalized.isEmpty,
               applyPrimaryHomeVideos(
                    personalized,
                    message: "Personalized feed from your YouTube account"
               ) {
                cachePersonalizedFeed(personalized)
                return
            }
        }

        if !webResult.videos.isEmpty && (!isSignedIn || webResult.isSignedIn) {
            let message = webResult.isSignedIn
                ? "Using signed-in YouTube homepage recommendations"
                : "Using YouTube homepage recommendations"
            if applyPrimaryHomeVideos(webResult.videos, message: message, cacheFeed: false) {
                return
            }
        }

        guard await client.hasCredentials() else {
            let safariSignals = await safariHomeFeed.loadFeed(maxResultsPerChannel: 5)
            if !safariSignals.isEmpty,
               applyPrimaryHomeVideos(
                    safariSignals,
                    message: "Safari Home-style channel recommendations (\(safariSignals.count) fresh uploads)"
               ) {
                return
            }

            connectionMessage = isSignedIn
                ? "Signed in; web feed unavailable (\(webResult.diagnostics))"
                : "API key needed for live YouTube (\(webResult.diagnostics))"
            return
        }

        do {
            let personalized = await personalizedVideos(maxResults: 12)
            let accountSignals = await accountSignalVideos(maxResults: 12)
            let popular = try await client.mostPopularVideos(maxResults: 8)
            let appleTech = try await client.searchVideos(query: "Apple Vision Pro technology creators", maxResults: 6, order: "relevance", videoCategoryId: "28")
            let candidates = accountSignals + personalized + popular + appleTech
            if !applyPrimaryHomeVideos(
                candidates,
                message: "Recommended by YouTube API account signals"
            ) {
                _ = applyPrimaryHomeVideos(popular + appleTech, message: "Popular on YouTube")
            }
        } catch {
            // Keep a cached or signed-in web feed visible when the Data API
            // project is temporarily rate-limited. Calling search again here
            // only compounds the quota problem and can replace useful content
            // with an error state.
            connectionMessage = feed.forYou.isEmpty && feed.trending.isEmpty && feed.more.isEmpty
                ? error.localizedDescription
                : "Using saved recommendations. \(error.localizedDescription)"
        }
    }

    func search(_ term: String? = nil) async {
        let searchTerm = (term ?? query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchTerm.isEmpty else { return }

        // Navigate immediately so a slow API or web-session fallback cannot
        // leave the user looking at the previous Home surface.
        query = searchTerm
        selectedSection = "Search"
        selectedPlaylist = nil
        selectedChannelItem = nil
        channelPage = nil
        sectionEmptyMessage = nil
        searchResults = []
        isLoading = true
        connectionMessage = "Searching YouTube..."
        YouGlassDiagnostics.feed.info("Search started")
        defer { isLoading = false }

        if let directVideo = VideoItem.fromYouTubeInput(searchTerm) {
            connectionMessage = "Opening YouTube video in the native player"
            open(directVideo)
            return
        }

        let hasCredentials = await client.hasCredentials()
        guard hasCredentials else {
            await applySearchFallback(for: searchTerm, apiError: nil)
            return
        }

        do {
            let videos = try await client.searchVideos(query: searchTerm, maxResults: 12)
            if !videos.isEmpty {
                applySearchResults(videos, message: "Connected to YouTube")
            } else {
                await applySearchFallback(for: searchTerm, apiError: nil)
            }
        } catch {
            // Data API search is quota-expensive and can be throttled even
            // when the signed-in YouTube website still works. Reuse the
            // authenticated hidden web session before showing an error.
            await applySearchFallback(for: searchTerm, apiError: error)
        }
    }

    private func applySearchResults(_ videos: [VideoItem], message: String) {
        let merged = mergeVideos(videos)
        guard !merged.isEmpty else {
            searchResults = []
            sectionEmptyMessage = "No matching YouTube videos were found."
            return
        }
        sectionEmptyMessage = nil
        searchResults = merged
        feed.hero = merged.first ?? feed.hero
        feed.forYou = Array(merged.prefix(8))
        feed.trending = Array(merged.dropFirst(8).prefix(8))
        feed.more = Array(merged.dropFirst(16).prefix(8))
        feed.queue = Array(merged.suffix(min(4, merged.count)))
        connectionMessage = message
    }

    private func applySearchFallback(for searchTerm: String, apiError: Error?) async {
        let webResult = await YouTubeWebFeedBridge.shared.searchVideos(query: searchTerm, maxResults: 20)
        if !webResult.videos.isEmpty {
            applySearchResults(
                webResult.videos,
                message: webResult.isSignedIn
                    ? "Personalized YouTube search results"
                    : "YouTube search results"
            )
            return
        }

        var localPoolSource = feed.forYou
        localPoolSource += feed.trending
        localPoolSource += feed.more
        localPoolSource += feed.queue
        localPoolSource += recentlyWatched
        localPoolSource += savedVideos
        localPoolSource += locallyLikedVideos
        localPoolSource += VideoItem.samples
        let localPool = mergeVideos(localPoolSource)
        let matches = localPool.filter { video in
            video.title.localizedCaseInsensitiveContains(searchTerm) ||
            video.channel.localizedCaseInsensitiveContains(searchTerm)
        }
        if !matches.isEmpty {
            applySearchResults(matches, message: "Showing saved results while YouTube search recovers")
            return
        }

        feed.forYou = []
        feed.trending = []
        feed.more = []
        feed.queue = []
        searchResults = []
        sectionEmptyMessage = "YouTube search is temporarily unavailable. Try again shortly."
        connectionMessage = searchFailureMessage(apiError: apiError, webDiagnostics: webResult.diagnostics)
    }

    private func searchFailureMessage(apiError: Error?, webDiagnostics: String) -> String {
        if let youtubeError = apiError as? YouTubeAPIError,
           case .httpStatus(let status, let reason, _) = youtubeError,
           status == 429 || reason == "rateLimitExceeded" || reason == "quotaExceeded" || reason == "dailyLimitExceeded" {
            return "YouTube search is temporarily unavailable. Try again shortly."
        }

        if let apiError {
            return "Search unavailable: \(apiError.localizedDescription)"
        }
        return webDiagnostics
    }

    func open(_ video: VideoItem) {
        stopCurrentPlayback()
        closeDesktopPIPWindow()
        guard video.isPlayableOnYouTube else {
            connectionMessage = "Resolving this card to a playable YouTube video..."
            Task { @MainActor [weak self] in
                guard let self else { return }

                if await client.hasCredentials(),
                   let matches = try? await client.searchVideos(query: video.title, maxResults: 1),
                   let resolved = matches.first {
                    rememberRecommendationSeed(resolved)
                    rememberHistory(resolved)
                    selectedVideo = resolved
                    isPlayerCompact = false
                    connectionMessage = "Playing a YouTube result in the native player"
                    return
                }

                // Keep the offline catalog interactive when no API key/feed is
                // available. This is the official IFrame API sample video.
                if let fallback = VideoItem.fromYouTubeInput("M7lc1UVf-VE") {
                    selectedVideo = VideoItem(
                        id: fallback.id,
                        title: "YouTube player test video",
                        channel: "YouTube",
                        views: "Official player sample",
                        age: "",
                        duration: "",
                        imageURL: fallback.imageURL,
                        verified: true
                    )
                    isPlayerCompact = false
                    connectionMessage = "Playing the offline YouTube player sample"
                    return
                }

                connectionMessage = "This card does not contain a valid YouTube video ID"
            }
            return
        }

        rememberRecommendationSeed(video)
        rememberHistory(video)
        isPlayerCompact = false
        selectedVideo = video
    }

    func openURL(_ url: URL, title: String = "YouTube") {
        YouTubeBrowserWindow.shared.open(url, title: title)
    }

    func openYouTube(_ path: String = "") {
        openURL(URL(string: "https://www.youtube.com\(path)")!)
    }

    func closePlayer() {
        presentDesktopPIP()
    }

    func expandPlayer() {
        guard selectedVideo != nil else { return }
        stopCurrentPlayback()
        closeDesktopPIPWindow()
        isPlayerCompact = false
    }

    func dismissPlayer() {
        stopCurrentPlayback()
        closeDesktopPIPWindow()
        selectedVideo = nil
        isPlayerCompact = false
    }

    /// Called by AppKit when the user closes the floating PIP window directly
    /// with the window chrome or a system close command.
    func desktopPIPDidClose() {
        guard isDesktopPIPActive || isDesktopPIPTransitioning else { return }
        pipTransitionTask?.cancel()
        pipTransitionTask = nil
        isDesktopPIPActive = false
        pipTransitionState = .idle
        stopCurrentPlayback()
        selectedVideo = nil
        isPlayerCompact = false
        connectionMessage = "Picture in Picture closed"
        YouGlassDesktopPIPWindowController.shared.close()
    }

    func presentDesktopPIP() {
        guard let video = selectedVideo else {
            connectionMessage = "Choose a video before opening Picture in Picture"
            return
        }

        guard !isDesktopPIPActive, !isDesktopPIPTransitioning else { return }

        pipTransitionTask?.cancel()
        pipTransitionTask = nil

        // Stop the source player and remove it from the SwiftUI tree before
        // creating the floating player. WebKit can crash while committing a
        // remote layer tree if the source and PIP WebViews are mounted or
        // detached in the same transaction.
        stopCurrentPlayback()
        isPlayerCompact = false
        pipTransitionState = .presenting(videoID: video.id)
        isDesktopPIPActive = true
        connectionMessage = "Opening Picture in Picture..."
        playbackLogger.notice("Starting PIP handoff for video=\(video.id, privacy: .public)")

        pipTransitionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: PIPTransitionPolicy.sourceTeardownDelayNanoseconds)
            guard !Task.isCancelled, let self,
                  self.pipTransitionState.matches(videoID: video.id),
                  self.pipTransitionState.isTransitioning,
                  self.selectedVideo?.id == video.id else { return }

            let presented = YouGlassDesktopPIPWindowController.shared.present(video: video, store: self)
            guard presented else {
                self.isDesktopPIPActive = false
                self.pipTransitionState = .idle
                self.pipTransitionTask = nil
                self.connectionMessage = "Picture in Picture could not be presented"
                self.playbackLogger.error("PIP handoff failed to present for video=\(video.id, privacy: .public)")
                return
            }

            self.pipTransitionState = .active(videoID: video.id)
            self.pipTransitionTask = nil
            self.connectionMessage = "Picture in Picture active"
            self.playbackLogger.notice("Completed PIP handoff for video=\(video.id, privacy: .public)")
        }
    }

    private func closeDesktopPIPWindow() {
        guard isDesktopPIPActive || isDesktopPIPTransitioning else { return }
        pipTransitionTask?.cancel()
        pipTransitionTask = nil
        isDesktopPIPActive = false
        pipTransitionState = .idle
        YouGlassDesktopPIPWindowController.shared.close()
    }

    private func stopCurrentPlayback() {
        let handler = playbackStopHandler
        playbackStopHandler = nil
        playbackStopHandlerToken = nil
        handler?()
    }

    func openChannel(_ item: SubscriptionItem) {
        if selectedVideo != nil {
            isPlayerCompact = true
        }
        selectedChannelItem = item
        channelPage = nil
        channelError = nil
        channelLoading = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let page = try await client.channelPage(for: item)
                guard selectedChannelItem?.id == item.id else { return }
                channelPage = page
                selectedSection = page.channel.name
            } catch {
                guard selectedChannelItem?.id == item.id else { return }
                if let page = await channelBridge.loadChannel(item) {
                    channelPage = page
                    selectedSection = page.channel.name
                    connectionMessage = "Native channel view from your signed-in YouTube session"
                } else {
                    channelError = error.localizedDescription
                }
            }
            channelLoading = false
        }
    }

    func closeChannel() {
        selectedChannelItem = nil
        channelPage = nil
        channelError = nil
        channelLoading = false
        selectedSection = "Home"
    }

    func relatedVideos(for video: VideoItem) -> [VideoItem] {
        let candidates = feed.forYou + feed.trending + feed.more + feed.queue
        let unique = candidates.filter { $0.id != video.id }
        return Array(unique.reduce(into: [VideoItem]()) { result, item in
            if !result.contains(where: { $0.id == item.id }) {
                result.append(item)
            }
        }.prefix(8))
    }

    func loadRecommendations(for video: VideoItem) async -> [VideoItem] {
        guard await client.hasCredentials() else {
            return relatedVideos(for: video)
        }

        do {
            let query = recommendationQuery(for: video)
            let relevance = try await client.searchVideos(query: query, maxResults: 8, order: "relevance")
            let popular = try await client.searchVideos(query: video.channel, maxResults: 6, order: "viewCount")
            let blended = RecommendationRanker.rank(
                relevance + popular + relatedVideos(for: video),
                subscriptions: subscriptions,
                history: recentlyWatched,
                liked: locallyLikedVideos,
                seeds: [video.channel, video.title],
                limit: 10
            ).filter { $0.id != video.id }
            return blended
        } catch {
            return relatedVideos(for: video)
        }
    }

    func loadComments(for video: VideoItem) async -> [VideoComment] {
        await loadCommentPage(for: video).comments
    }

    func loadCommentPage(for video: VideoItem, pageToken: String? = nil) async -> CommentPage {
        guard video.isPlayableOnYouTube else {
            return CommentPage(comments: [], totalCount: 0, isAvailable: false, message: "This item is not a live YouTube video.")
        }

        if let pageToken, pageToken.hasPrefix("bridge-offset:") {
            let offset = Int(pageToken.dropFirst("bridge-offset:".count)) ?? 0
            return await commentsBridge.load(videoID: video.id, maxResults: 50, offset: offset)
        }

        if let pageToken, !pageToken.isEmpty {
            do {
                return try await client.commentsPage(videoID: video.id, pageToken: pageToken)
            } catch {
                // A Data API page token is opaque and cannot be translated
                // into a web-session offset. Falling back to offset zero here
                // duplicates the first page and makes the list look truncated.
                YouGlassDiagnostics.record(
                    .warning,
                    category: "comments",
                    message: "Comment page request failed",
                    metadata: ["videoID": video.id, "error": error.localizedDescription]
                )
                return CommentPage(
                    comments: [],
                    totalCount: 0,
                    isAvailable: false,
                    message: error.localizedDescription,
                    nextPageToken: pageToken
                )
            }
        }

        do {
            let page = try await client.commentsPage(videoID: video.id, pageToken: nil)
            if page.isAvailable || page.message?.localizedCaseInsensitiveContains("disabled") == true {
                return page
            }
            let bridgePage = await commentsBridge.load(videoID: video.id, maxResults: 50, offset: 0)
            return bridgePage.isAvailable ? bridgePage : page
        } catch {
            YouGlassDiagnostics.record(
                .warning,
                category: "comments",
                message: "Comment request failed and web fallback was unavailable",
                metadata: ["videoID": video.id, "error": error.localizedDescription]
            )
            let bridgePage = await commentsBridge.load(videoID: video.id, maxResults: 50, offset: 0)
            if bridgePage.isAvailable || bridgePage.message?.localizedCaseInsensitiveContains("disabled") == true {
                return bridgePage
            }
            return CommentPage(
                comments: [],
                totalCount: 0,
                isAvailable: false,
                message: "\(error.localizedDescription) Add API access in Settings to load public comments safely."
            )
        }
    }

    func loadVideoDetails(for video: VideoItem) async -> VideoDetails? {
        guard video.isPlayableOnYouTube else { return nil }
        do {
            return try await client.videoDetails(videoID: video.id)
        } catch {
            connectionMessage = error.localizedDescription
            return nil
        }
    }

    func loadLiveChat(for video: VideoItem, liveChatID: String? = nil, pageToken: String? = nil) async -> LiveChatPage {
        guard let liveChatID, !liveChatID.isEmpty else {
            let bridgePage = await liveChatBridge.load(videoID: video.id)
            if bridgePage.isAvailable || bridgePage.isLive {
                return bridgePage
            }
            return LiveChatPage(
                messages: [],
                nextPageToken: nil,
                pollingInterval: 5_000_000_000,
                isLive: false,
                isAvailable: false,
                message: bridgePage.message ?? "YouTube did not expose a live-chat ID for this stream."
            )
        }

        do {
            return try await client.liveChatPage(liveChatID: liveChatID, pageToken: pageToken)
        } catch {
            let bridgePage = await liveChatBridge.load(videoID: video.id)
            if bridgePage.isAvailable || bridgePage.isLive {
                return bridgePage
            }
            connectionMessage = error.localizedDescription
            YouGlassDiagnostics.record(
                .warning,
                category: "live-chat",
                message: "Live chat request failed and web fallback was unavailable",
                metadata: ["videoID": video.id, "error": error.localizedDescription]
            )
            return LiveChatPage(
                messages: [],
                nextPageToken: pageToken,
                pollingInterval: 6_000_000_000,
                isLive: true,
                isAvailable: false,
                message: error.localizedDescription
            )
        }
    }

    func rate(video: VideoItem, as rating: String) async -> Bool {
        do {
            try await client.rate(videoID: video.id, rating: rating)
            return true
        } catch {
            connectionMessage = error.localizedDescription
            return false
        }
    }

    func subscribe(
        to channelID: String,
        channelName: String? = nil,
        avatarURL: URL? = nil,
        channelURL: URL? = nil
    ) async -> Bool {
        do {
            try await client.subscribe(to: channelID)
            if let channelName, !channelName.isEmpty {
                let resolvedChannelURL = channelURL
                    ?? (channelID.hasPrefix("UC")
                        ? URL(string: "https://www.youtube.com/channel/\(channelID)")
                        : nil)
                let item = SubscriptionItem(
                    id: channelID,
                    name: channelName,
                    avatarURL: avatarURL,
                    channelURL: resolvedChannelURL,
                    isLive: false
                )
                subscriptions = mergeSubscriptions([item] + subscriptions)
                subscriptionsLoaded = true
                persistSubscriptions(subscriptions)
            }
            return true
        } catch {
            connectionMessage = error.localizedDescription
            return false
        }
    }

    func addComment(to video: VideoItem, channelID: String?, text: String) async -> VideoComment? {
        guard let channelID, !channelID.isEmpty else {
            commentAuthorizationRequired = false
            connectionMessage = "Connect a YouTube Data API key or Google OAuth in YouGlass Settings before posting comments."
            return nil
        }

        do {
            let comment = try await client.addComment(videoID: video.id, channelID: channelID, text: text)
            commentAuthorizationRequired = false
            connectionMessage = "Comment posted to YouTube"
            return comment
        } catch {
            commentAuthorizationRequired = isAuthenticationError(error)
            connectionMessage = error.localizedDescription
            return nil
        }
    }

    func authorizeYouTubeComments() async -> Bool {
        guard oauth.hasClientID else {
            commentAuthorizationRequired = true
            connectionMessage = "Add the Google OAuth client ID before authorizing comments."
            return false
        }
        guard oauth.hasClientSecret else {
            commentAuthorizationRequired = true
            connectionMessage = "Add the Google OAuth client secret before authorizing comments."
            return false
        }

        do {
            if try await oauth.validAccessToken() == nil {
                _ = try await oauth.signIn()
            }
            isSignedIn = true
            defaults.set(true, forKey: DefaultsKey.isSignedIn)
            commentAuthorizationRequired = false
            connectionMessage = "Connected with YouTube OAuth"
            scheduleSubscriptionsLoad(force: true)
            scheduleHomeReload(force: true)
            return true
        } catch {
            connectionMessage = error.localizedDescription
            return false
        }
    }

    private func isAuthenticationError(_ error: Error) -> Bool {
        guard let apiError = error as? YouTubeAPIError else { return false }
        if case .authenticationRequired = apiError { return true }
        return false
    }

    private func rememberRecommendationSeed(_ video: VideoItem) {
        let seed = "\(video.channel) \(video.title)"
        recommendationSeeds.removeAll { $0 == seed }
        recommendationSeeds.insert(seed, at: 0)
        recommendationSeeds = Array(recommendationSeeds.prefix(6))
        defaults.set(recommendationSeeds, forKey: DefaultsKey.recommendationSeeds)
    }

    private func rememberHistory(_ video: VideoItem) {
        recentlyWatched.removeAll { $0.id == video.id }
        recentlyWatched.insert(video, at: 0)
        recentlyWatched = Array(recentlyWatched.prefix(100))
        persistVideos(recentlyWatched, key: DefaultsKey.recentlyWatched)
    }

    private func decodeVideos(forKey key: String) -> [VideoItem] {
        guard let data = defaults.data(forKey: key),
              let videos = try? JSONDecoder().decode([VideoItem].self, from: data) else { return [] }
        return videos
    }

    private func decodePlaybackPositions() -> [String: Double] {
        guard let data = defaults.data(forKey: DefaultsKey.playbackPositions),
              let positions = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return [:]
        }
        return positions.filter { $0.value.isFinite && $0.value > 0 }
    }

    private func decodePlaybackPositionDates() -> [String: Date] {
        guard let data = defaults.data(forKey: DefaultsKey.playbackPositionUpdatedAt),
              let dates = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return dates.filter { playbackPositions[$0.key] != nil }
    }

    private func decodeSubscriptions() -> [SubscriptionItem] {
        guard let data = defaults.data(forKey: DefaultsKey.cachedSubscriptions),
              let items = try? JSONDecoder().decode([SubscriptionItem].self, from: data) else {
            return []
        }
        return mergeSubscriptions(items)
    }

    private func persistPlaybackPositions() {
        guard let positionsData = try? JSONEncoder().encode(playbackPositions),
              let datesData = try? JSONEncoder().encode(playbackPositionUpdatedAt) else { return }
        defaults.set(positionsData, forKey: DefaultsKey.playbackPositions)
        defaults.set(datesData, forKey: DefaultsKey.playbackPositionUpdatedAt)
    }

    private func persistSubscriptions(_ items: [SubscriptionItem]) {
        guard !items.isEmpty else {
            defaults.removeObject(forKey: DefaultsKey.cachedSubscriptions)
            defaults.removeObject(forKey: DefaultsKey.cachedSubscriptionsDate)
            cachedSubscriptionsUpdatedAt = nil
            return
        }
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: DefaultsKey.cachedSubscriptions)
        cachedSubscriptionsUpdatedAt = Date()
        defaults.set(cachedSubscriptionsUpdatedAt, forKey: DefaultsKey.cachedSubscriptionsDate)
    }

    private func persistVideos(_ videos: [VideoItem], key: String) {
        if let data = try? JSONEncoder().encode(videos) {
            defaults.set(data, forKey: key)
        }
    }

    private func recommendationQuery(for video: VideoItem) -> String {
        let titleWords = video.title
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 }
            .prefix(7)
            .joined(separator: " ")
        let history = recommendationSeeds.prefix(2).joined(separator: " ")
        return "\(video.channel) \(titleWords) \(history)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func mergeVideos(_ videos: [VideoItem]) -> [VideoItem] {
        videos.reduce(into: [VideoItem]()) { result, video in
            if !result.contains(where: { $0.id == video.id }) {
                result.append(video)
            }
        }
    }

    private func applyHomeVideos(_ videos: [VideoItem], message: String) {
        applyHomeVideos(videos, message: message, cacheFeed: true)
    }

    private func applyHomeVideos(_ videos: [VideoItem], message: String, cacheFeed: Bool) {
        let merged = mergeVideos(videos)
        guard !merged.isEmpty else { return }
        sectionEmptyMessage = nil
        feed.hero = merged.first ?? feed.hero
        feed.forYou = Array(merged.prefix(8))
        feed.trending = Array(merged.dropFirst(8).prefix(8))
        feed.more = Array(merged.dropFirst(16).prefix(8))
        feed.queue = Array(merged.dropFirst(24).prefix(4))
        connectionMessage = message
        if cacheFeed, let data = try? JSONEncoder().encode(merged) {
            defaults.set(data, forKey: DefaultsKey.cachedFeed)
            cachedFeedUpdatedAt = Date()
            defaults.set(cachedFeedUpdatedAt, forKey: DefaultsKey.cachedFeedDate)
        }
    }

    @discardableResult
    private func applyPrimaryHomeVideos(
        _ videos: [VideoItem],
        message: String,
        cacheFeed: Bool = true
    ) -> Bool {
        let ranked = RecommendationRanker.rank(
            videos,
            subscriptions: subscriptions,
            history: recentlyWatched,
            liked: locallyLikedVideos,
            seeds: recommendationSeeds,
            saved: savedVideos,
            limit: 40,
            excludeShortForm: true
        )
        guard !ranked.isEmpty else { return false }
        applyHomeVideos(ranked, message: message, cacheFeed: cacheFeed)
        return true
    }

    private func cachePersonalizedFeed(_ videos: [VideoItem]) {
        let longForm = mergeVideos(videos).filter { !$0.isShortForm }
        guard let data = try? JSONEncoder().encode(Array(longForm.prefix(40))) else { return }
        defaults.set(data, forKey: DefaultsKey.cachedPersonalizedFeed)
        cachedPersonalizedFeedUpdatedAt = Date()
        defaults.set(cachedPersonalizedFeedUpdatedAt, forKey: DefaultsKey.cachedPersonalizedFeedDate)
    }

    private func showEmptySection(_ message: String) {
        feed.forYou = []
        feed.trending = []
        feed.more = []
        feed.queue = []
        sectionEmptyMessage = message
        connectionMessage = message
    }

    private func scheduleHomeReload(force: Bool = false) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            await self?.loadHome(force: force)
        }
    }

    private func personalizedVideos(maxResults: Int) async -> [VideoItem] {
        guard !recommendationSeeds.isEmpty else { return [] }

        var videos: [VideoItem] = []
        for seed in recommendationSeeds.prefix(3) {
            if let results = try? await client.searchVideos(
                query: seed,
                maxResults: max(4, maxResults / 3),
                order: "relevance"
            ) {
                videos.append(contentsOf: results)
            }
        }
        return Array(mergeVideos(videos).prefix(maxResults))
    }

    private func personalizedAccountFeed(webHomepageVideos: [VideoItem] = []) async -> [VideoItem] {
        // Keep the authenticated YouTube homepage as the highest-fidelity
        // source. The Data API cannot reproduce YouTube's private model, so it
        // supplements this list rather than replacing it.
        var videos: [VideoItem] = webHomepageVideos

        let subscribedChannels = subscriptions.compactMap { subscription -> SafariHomeFeedClient.Channel? in
            let source = subscription.channelURL
                ?? (subscription.id.hasPrefix("UC")
                    ? URL(string: "https://www.youtube.com/channel/\(subscription.id)")
                    : nil)
            guard let source else { return nil }
            return SafariHomeFeedClient.Channel(
                name: subscription.name,
                source: source,
                category: "Subscriptions"
            )
        }

        if !subscribedChannels.isEmpty {
            let uploads = await safariHomeFeed.loadFeed(
                channels: Array(subscribedChannels.prefix(24)),
                maxResultsPerChannel: 3
            )
            videos.append(contentsOf: uploads)
        }

        if await client.hasCredentials() {
            videos.append(contentsOf: await accountSignalVideos(maxResults: 16))
            videos.append(contentsOf: await personalizedVideos(maxResults: 12))
            if client.canConnect,
               let popular = try? await client.mostPopularVideos(maxResults: 6) {
                videos.append(contentsOf: popular)
            }
        }

        let ranked = RecommendationRanker.rank(
            videos,
            subscriptions: subscriptions,
            history: recentlyWatched,
            liked: locallyLikedVideos,
            seeds: recommendationSeeds,
            saved: savedVideos,
            limit: 40,
            excludeShortForm: true
        )
        if !ranked.isEmpty {
            return ranked
        }

        if let data = defaults.data(forKey: DefaultsKey.cachedPersonalizedFeed),
           let cached = try? JSONDecoder().decode([VideoItem].self, from: data) {
            return RecommendationRanker.rank(
                cached,
                subscriptions: subscriptions,
                history: recentlyWatched,
                liked: locallyLikedVideos,
                seeds: recommendationSeeds,
                saved: savedVideos,
                limit: 40,
                excludeShortForm: true
            )
        }

        return []
    }

    private func accountSignalVideos(maxResults: Int) async -> [VideoItem] {
        let requestedCount = max(1, maxResults)
        let cachedCandidates = cachedAccountSignalVideos.filter { !$0.isShortForm }
        if cachedCandidates.count >= requestedCount,
           let lastAccountSignalLoadDate,
           Date().timeIntervalSince(lastAccountSignalLoadDate) < 60 {
            return Array(cachedCandidates.prefix(requestedCount))
        }

        var videos: [VideoItem] = []

        if let liked = try? await client.likedVideos(maxResults: 8) {
            videos.append(contentsOf: liked)
        }

        let accountSubscriptions: [SubscriptionItem]
        if !subscriptions.isEmpty {
            accountSubscriptions = subscriptions
        } else {
            accountSubscriptions = (try? await client.mySubscriptions(maxResults: 60)) ?? []
        }
        if !accountSubscriptions.isEmpty {
            // A channel-page request is several API calls. Keep the burst
            // bounded so a refresh remains useful even on a small quota.
            for subscription in accountSubscriptions.prefix(12) {
                if let channelPage = try? await client.channelPage(for: subscription, maxResults: 4),
                   !channelPage.videos.isEmpty {
                    videos.append(contentsOf: channelPage.videos.prefix(4))
                    continue
                }

                if let latest = try? await client.searchVideos(
                    query: "\(subscription.name) latest",
                    maxResults: 4,
                    order: "date"
                ) {
                    videos.append(contentsOf: latest)
                }
            }
        }

        videos.append(contentsOf: recentlyWatched.prefix(8))
        videos.append(contentsOf: locallyLikedVideos.prefix(8))
        videos.append(contentsOf: savedVideos.prefix(8))
        let merged = Array(mergeVideos(videos).filter { !$0.isShortForm }.prefix(requestedCount))
        cachedAccountSignalVideos = merged
        lastAccountSignalLoadDate = Date()
        return merged
    }

    private func invalidateAccountSignalCache() {
        cachedAccountSignalVideos = []
        lastAccountSignalLoadDate = nil
    }

    func showSection(_ title: String, query: String? = nil) {
        if selectedVideo != nil {
            isPlayerCompact = true
        }
        selectedPlaylist = nil
        playlistItems = []
        playlistError = nil
        selectedSection = title
        self.query = query ?? (title == "Home" ? "" : self.query)
        Task { @MainActor [weak self] in
            await self?.loadSection(title, query: query)
        }
    }

    private func loadSection(_ title: String, query: String?) async {
        switch title {
        case "Home":
            await loadHome()
        case "Shorts":
            await loadShorts()
        case "History":
            await loadHistory()
        case "Watch Later":
            if savedVideos.isEmpty {
                showEmptySection("Your Watch Later list is empty")
            } else {
                applyHomeVideos(savedVideos, message: "Saved in YouGlass Watch Later")
            }
        case "Liked Videos":
            await loadLikedVideos()
        case "Library":
            let library = mergeVideos(savedVideos + locallyLikedVideos + recentlyWatched)
            if library.isEmpty {
                showEmptySection("Save or like a video to build your library")
            } else {
                applyHomeVideos(library, message: "Your YouGlass library")
            }
        case "Playlists":
            await loadPlaylists()
        case "Subscriptions":
            await loadSubscriptionFeed()
        default:
            if let query, !query.isEmpty { await search(query) }
        }
    }

    private func loadHistory() async {
        isLoading = true
        defer { isLoading = false }

        // Data API v3 intentionally does not return the private system
        // watch-history playlist. The signed-in YouTube session is the
        // authoritative source for this page.
        let webResult = await YouTubeWebFeedBridge.shared.loadHistoryVideos(maxResults: 100)
        if webResult.isSignedIn && !isSignedIn {
            isSignedIn = true
            defaults.set(true, forKey: DefaultsKey.isSignedIn)
        }
        if !webResult.videos.isEmpty {
            applyHomeVideos(
                webResult.videos,
                message: "Watch history from your signed-in YouTube session",
                cacheFeed: false
            )
            YouGlassDiagnostics.feed.info("Loaded \(webResult.videos.count, privacy: .public) account watch-history videos from the signed-in web session")
            return
        }

        if !recentlyWatched.isEmpty {
            applyHomeVideos(
                recentlyWatched,
                message: "Showing videos watched in YouGlass on this Mac",
                cacheFeed: false
            )
            return
        }

        if isSignedIn {
            showEmptySection("Your YouTube watch history is unavailable in the current session. Reconnect YouTube and try again.")
        } else {
            showEmptySection("Sign in with Google to load your YouTube watch history")
        }
    }

    private func loadShorts() async {
        guard await client.hasCredentials() else {
            connectionMessage = "Sign in with Google or add a YouTube API key to load Shorts"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let shorts = try await client.searchVideos(
                query: "shorts",
                maxResults: 12,
                order: "date",
                videoDuration: "short"
            )
            applyHomeVideos(shorts, message: "Latest Shorts from YouTube")
        } catch {
            connectionMessage = "Using saved Shorts. \(error.localizedDescription)"
        }
    }

    private func loadLikedVideos() async {
        if isSignedIn, await client.hasCredentials() {
            do {
                let liked = try await client.likedVideos(maxResults: 50)
                applyHomeVideos(
                    liked.isEmpty ? locallyLikedVideos : liked,
                    message: liked.isEmpty ? "No liked videos returned by YouTube" : "Liked videos from YouTube"
                )
                return
            } catch {
                connectionMessage = "Using saved liked videos. \(error.localizedDescription)"
            }
        }
        if locallyLikedVideos.isEmpty {
            showEmptySection("Like a video to build this list")
        } else {
            applyHomeVideos(locallyLikedVideos, message: "Liked videos saved in YouGlass")
        }
    }

    private func loadSubscriptionFeed() async {
        await loadSubscriptions(force: false)
        guard await client.hasCredentials() else {
            connectionMessage = "Sign in with Google or add a YouTube API key to load subscription uploads"
            return
        }

        isLoading = true
        defer { isLoading = false }
        var uploads: [VideoItem] = []
        for subscription in subscriptions.prefix(12) {
            if let page = try? await client.channelPage(for: subscription, maxResults: 6), !page.videos.isEmpty {
                uploads.append(contentsOf: page.videos)
            }
        }
        if uploads.isEmpty {
            uploads = await accountSignalVideos(maxResults: 16)
        }
        if uploads.isEmpty {
            showEmptySection("No recent subscription uploads were returned")
        } else {
            applyHomeVideos(uploads, message: "Latest uploads from your subscriptions")
        }
    }

    private func loadPlaylists() async {
        guard isSignedIn else {
            playlists = []
            showEmptySection("Sign in with Google to load your YouTube playlists")
            return
        }

        guard await client.hasCredentials() else {
            showEmptySection("Add a YouTube API key or reconnect Google in Settings")
            return
        }

        playlistLoading = true
        playlistError = nil
        defer { playlistLoading = false }

        do {
            let loaded = try await client.myPlaylists(maxResults: 100)
            playlists = loaded
            if loaded.isEmpty {
                showEmptySection("No YouTube playlists were found on this account")
            } else {
                sectionEmptyMessage = nil
                connectionMessage = "Loaded \(loaded.count) playlists from YouTube"
            }
        } catch {
            playlistError = error.localizedDescription
            if playlists.isEmpty {
                showEmptySection(error.localizedDescription)
            } else {
                connectionMessage = error.localizedDescription
            }
        }
    }

    func openPlaylist(_ playlist: YouTubePlaylist) {
        if selectedVideo != nil {
            isPlayerCompact = true
        }
        selectedPlaylist = playlist
        selectedSection = playlist.title
        playlistItems = []
        playlistError = nil
        sectionEmptyMessage = nil
        playlistLoading = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { playlistLoading = false }
            do {
                let items = try await client.playlistVideos(playlistID: playlist.id, maxResults: 100)
                guard selectedPlaylist?.id == playlist.id else { return }
                playlistItems = items
                if items.isEmpty {
                    playlistError = "This playlist does not contain playable videos."
                } else {
                    connectionMessage = "Loaded \(items.count) videos from \(playlist.title)"
                }
            } catch {
                guard selectedPlaylist?.id == playlist.id else { return }
                playlistError = error.localizedDescription
                connectionMessage = error.localizedDescription
            }
        }
    }

    func closePlaylist() {
        selectedPlaylist = nil
        playlistItems = []
        playlistError = nil
        playlistLoading = false
        selectedSection = "Playlists"
        Task { @MainActor [weak self] in
            await self?.loadPlaylists()
        }
    }

    func login() {
        guard oauth.hasClientID else {
            connectionMessage = "OAuth client ID needed for personalized account feed"
            let continueURL = "https%3A%2F%2Fwww.youtube.com%2F"
            openURL(URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=\(continueURL)")!, title: "Sign in")
            return
        }

        Task {
            do {
                // A valid cached access token is the normal relaunch path. It
                // avoids opening a new Google window and keeps the account
                // session available after the app is quit and reopened.
                if try await oauth.validAccessToken() == nil {
                    _ = try await oauth.signIn()
                }
                isSignedIn = true
                defaults.set(true, forKey: DefaultsKey.isSignedIn)
                connectionMessage = "Connected with YouTube OAuth"
                await loadHome(force: true)
            } catch {
                connectionMessage = error.localizedDescription
            }
        }
    }

    func legacyLogin() {
        let continueURL = "https%3A%2F%2Fwww.youtube.com%2F"
        openURL(URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=\(continueURL)")!, title: "Sign in")
    }

    func openSearchPage() {
        let searchTerm = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let queryValue = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchTerm
        openURL(URL(string: "https://www.youtube.com/results?search_query=\(queryValue)")!, title: "Search")
    }

    func refreshAccount() {
        subscriptionsLoaded = false
        invalidateAccountSignalCache()
        connectionMessage = "Refreshing your YouTube account..."
        YouTubeBrowserWindow.shared.checkAuthenticationState()
        scheduleSubscriptionsLoad(force: true)
        scheduleHomeReload(force: true)
    }

    private func scheduleSubscriptionsLoad(force: Bool) {
        Task { @MainActor [weak self] in
            await self?.loadSubscriptions(force: force)
        }
    }

    private func loadSubscriptions(force: Bool) async {
        guard !subscriptionLoadInProgress else {
            if force { subscriptionReloadPending = true }
            await withCheckedContinuation { continuation in
                subscriptionLoadWaiters.append(continuation)
            }
            return
        }
        guard force || !subscriptionsLoaded else { return }
        guard isSignedIn else {
            subscriptions = []
            subscriptionsLoaded = false
            return
        }

        subscriptionLoadInProgress = true
        YouGlassDiagnostics.auth.info("Subscription load started; forced: \(force, privacy: .public)")
        defer {
            subscriptionLoadInProgress = false
            YouGlassDiagnostics.auth.info("Subscription load finished")
            let waiters = subscriptionLoadWaiters
            subscriptionLoadWaiters.removeAll()
            waiters.forEach { $0.resume() }
            if subscriptionReloadPending {
                subscriptionReloadPending = false
                Task { @MainActor [weak self] in
                    await self?.loadSubscriptions(force: true)
                }
            }
        }

        var apiSubscriptions: [SubscriptionItem] = []
        var apiRequestSucceeded = false
        do {
            apiSubscriptions = try await client.mySubscriptions(maxResults: 200)
            apiRequestSucceeded = true
            YouGlassDiagnostics.auth.debug("Subscription API returned \(apiSubscriptions.count, privacy: .public) items")
        } catch {
            YouGlassDiagnostics.auth.error("Subscription API request failed")
            connectionMessage = error.localizedDescription
        }

        // The OAuth list has stable channel IDs and is authoritative, including
        // an authenticated empty response. Only scrape the signed-in web
        // session when the API request itself failed.
        let webSubscriptions = apiRequestSucceeded
            ? []
            : await subscriptionBridge.loadSubscriptions(maxResults: 200)

        let mergedSubscriptions = mergeSubscriptions(apiSubscriptions + webSubscriptions)
        if !mergedSubscriptions.isEmpty {
            subscriptions = mergedSubscriptions
            subscriptionsLoaded = true
            persistSubscriptions(mergedSubscriptions)
            lastAccountSyncDate = Date()
            defaults.set(lastAccountSyncDate, forKey: DefaultsKey.lastAccountSyncDate)
            connectionMessage = "Loaded \(mergedSubscriptions.count) subscriptions from YouTube"
            return
        }

        if apiRequestSucceeded {
            // An authenticated empty response is meaningful. Clear stale
            // subscriptions instead of continuing to display old channels.
            subscriptions = []
            subscriptionsLoaded = true
            persistSubscriptions([])
            lastAccountSyncDate = Date()
            defaults.set(lastAccountSyncDate, forKey: DefaultsKey.lastAccountSyncDate)
            connectionMessage = "Your YouTube account has no subscriptions"
            return
        }

        if webSubscriptions.isEmpty && apiSubscriptions.isEmpty {
            connectionMessage = connectionMessage == "Refreshing your YouTube account..."
                ? "Your YouTube account has no subscriptions"
                : connectionMessage
        }
        subscriptionsLoaded = false
    }

    private func mergeSubscriptions(_ items: [SubscriptionItem]) -> [SubscriptionItem] {
        items.reduce(into: [SubscriptionItem]()) { result, item in
            let duplicate = result.contains { existing in
                if let channelID = item.canonicalChannelID,
                   let existingChannelID = existing.canonicalChannelID {
                    return channelID == existingChannelID
                }
                return existing.matches(channelID: nil, channelName: item.name)
            }
            if !duplicate {
                result.append(item)
            }
        }
    }
}
