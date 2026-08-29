import XCTest
@testable import YouTubeMac

final class ModelsTests: XCTestCase {
    func testThemeCatalogProvidesPairedLightAndDarkFamilies() throws {
        let themes = YouGlassThemeFamily.allCases

        XCTAssertEqual(themes.count, 12)
        XCTAssertEqual(Set(themes.map(\.id)).count, themes.count)
        XCTAssertEqual(themes.filter(\.isFeatured), [.neoCitrus])
        XCTAssertTrue(themes.allSatisfy { !$0.title.isEmpty && !$0.subtitle.isEmpty })

        for theme in themes {
            _ = theme.colors(isDark: false)
            _ = theme.colors(isDark: true)

            let encoded = try JSONEncoder().encode(theme)
            XCTAssertEqual(try JSONDecoder().decode(YouGlassThemeFamily.self, from: encoded), theme)
        }
    }

    func testPIPTransitionOnlyMatchesItsCurrentVideo() {
        let presenting = PIPTransitionState.presenting(videoID: "video-a")
        XCTAssertTrue(presenting.isTransitioning)
        XCTAssertTrue(presenting.matches(videoID: "video-a"))
        XCTAssertFalse(presenting.matches(videoID: "video-b"))

        let active = PIPTransitionState.active(videoID: "video-a")
        XCTAssertFalse(active.isTransitioning)
        XCTAssertTrue(active.matches(videoID: "video-a"))
        XCTAssertEqual(PIPTransitionState.idle, .idle)
    }

    func testPIPHandoffUsesShortAnimatedWindow() {
        XCTAssertGreaterThan(PIPTransitionPolicy.sourceTeardownDelayNanoseconds, 0)
        XCTAssertLessThan(PIPTransitionPolicy.sourceTeardownDelayNanoseconds, 500_000_000)
        XCTAssertGreaterThan(PIPTransitionPolicy.panelFadeDuration, 0)
        XCTAssertLessThan(PIPTransitionPolicy.panelFadeDuration, 0.5)
    }

    func testConnectionModePrioritizesReachabilityAndAccountState() {
        XCTAssertEqual(
            YouGlassConnectionMode.resolve(
                isNetworkAvailable: false,
                isSignedIn: true,
                isSyncing: false,
                detailMessage: "Connected"
            ),
            .offline
        )
        XCTAssertEqual(
            YouGlassConnectionMode.resolve(
                isNetworkAvailable: true,
                isSignedIn: false,
                isSyncing: true,
                detailMessage: "Loading recommendations"
            ),
            .syncing
        )
        XCTAssertEqual(
            YouGlassConnectionMode.resolve(
                isNetworkAvailable: true,
                isSignedIn: true,
                isSyncing: false,
                detailMessage: "Account feed ready"
            ),
            .connected
        )
    }

    func testConnectionModeSeparatesSetupFromLocalMode() {
        XCTAssertEqual(
            YouGlassConnectionMode.resolve(
                isNetworkAvailable: true,
                isSignedIn: false,
                isSyncing: false,
                detailMessage: "API key needed for live YouTube"
            ),
            .setupRequired
        )
        XCTAssertEqual(
            YouGlassConnectionMode.resolve(
                isNetworkAvailable: true,
                isSignedIn: false,
                isSyncing: false,
                detailMessage: "Saved YouTube recommendations"
            ),
            .local
        )
    }

    func testPlaybackCheckpointPolicyHasBoundedResumeData() {
        XCTAssertEqual(PlaybackCheckpointPolicy.maxEntries, 200)
        XCTAssertGreaterThan(PlaybackCheckpointPolicy.completionGraceSeconds, 0)
        XCTAssertLessThan(PlaybackCheckpointPolicy.completionGraceSeconds, 10)
        XCTAssertGreaterThan(PlaybackCheckpointPolicy.completionFraction, 0.9)
        XCTAssertLessThan(PlaybackCheckpointPolicy.completionFraction, 1)
        XCTAssertTrue(PlaybackCheckpointPolicy.isResumable(position: 30, duration: 300))
        XCTAssertFalse(PlaybackCheckpointPolicy.isResumable(position: 0, duration: 300))
        XCTAssertFalse(PlaybackCheckpointPolicy.isResumable(position: 30, duration: 0))
        XCTAssertFalse(PlaybackCheckpointPolicy.isResumable(position: 299, duration: 300))
    }

    func testParsesStandardWatchURL() {
        let video = VideoItem.fromYouTubeInput("https://www.youtube.com/watch?v=5sTQfGJiVdc")
        XCTAssertEqual(video?.id, "5sTQfGJiVdc")
        XCTAssertTrue(video?.isPlayableOnYouTube == true)
        XCTAssertEqual(video?.playbackURL.absoluteString, "https://www.youtube.com/watch?v=5sTQfGJiVdc")
    }

    func testPlaylistPreservesAccountMetadata() {
        let playlist = YouTubePlaylist(
            id: "PL123",
            title: "My playlist",
            description: "Saved videos",
            thumbnailURL: URL(string: "https://i.ytimg.com/vi/5sTQfGJiVdc/hqdefault.jpg"),
            itemCount: 19
        )

        XCTAssertEqual(playlist.id, "PL123")
        XCTAssertEqual(playlist.itemCount, 19)
        XCTAssertEqual(playlist.title, "My playlist")
    }

    func testSubscriptionMatchesChannelIDAndWebChannelName() {
        let byID = SubscriptionItem(
            id: "UC1234567890123456789012",
            name: "Example Channel",
            avatarURL: nil,
            isLive: false
        )
        XCTAssertTrue(byID.matches(channelID: "UC1234567890123456789012", channelName: "Different display name"))

        let fromWebSession = SubscriptionItem(
            id: "https://www.youtube.com/@ReportingLiveFromMySofaThePodcast",
            name: "ReportingLiveFromMySofaThePodcast",
            avatarURL: nil,
            channelURL: URL(string: "https://www.youtube.com/@ReportingLiveFromMySofaThePodcast"),
            isLive: false
        )
        XCTAssertTrue(fromWebSession.matches(channelID: nil, channelName: "Reporting Live From My Sofa The Podcast"))
        XCTAssertFalse(fromWebSession.matches(channelID: nil, channelName: "A different channel"))

        let shortenedWebLabel = SubscriptionItem(
            id: "https://www.youtube.com/@ReportingLiveFromMySofaThePodcast",
            name: "Reporting live from my sofa",
            avatarURL: nil,
            channelURL: URL(string: "https://www.youtube.com/@ReportingLiveFromMySofaThePodcast"),
            isLive: false
        )
        XCTAssertTrue(shortenedWebLabel.matches(channelID: nil, channelName: "ReportingLiveFromMySofaThePodcast"))

        XCTAssertTrue(shortenedWebLabel.matches(channelID: nil, channelName: "ReportingLiveFromMySofa..."))

        let sameNameDifferentID = SubscriptionItem(
            id: "UC9999999999999999999999",
            name: "Example Channel",
            avatarURL: nil,
            isLive: false
        )
        XCTAssertFalse(sameNameDifferentID.matches(channelID: "UC1234567890123456789012", channelName: "Example Channel"))
    }

    func testSubscriptionItemRoundTripsThroughJSON() throws {
        let item = SubscriptionItem(
            id: "UC1234567890123456789012",
            name: "Example Channel",
            avatarURL: URL(string: "https://example.com/avatar.jpg"),
            channelURL: URL(string: "https://www.youtube.com/channel/UC1234567890123456789012"),
            isLive: true
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(SubscriptionItem.self, from: data)

        XCTAssertEqual(decoded, item)
        XCTAssertEqual(decoded.canonicalChannelID, item.canonicalChannelID)
    }

    func testParsesShortLiveAndEmbedURLs() {
        let id = "5sTQfGJiVdc"
        XCTAssertEqual(VideoItem.fromYouTubeInput("https://youtu.be/\(id)")?.id, id)
        XCTAssertNil(VideoItem.fromYouTubeInput("https://youtube.com/shorts/\(id)"))
        XCTAssertEqual(VideoItem.fromYouTubeInput("https://youtube.com/live/\(id)")?.id, id)
        XCTAssertEqual(VideoItem.fromYouTubeInput("https://youtube.com/embed/\(id)")?.id, id)
        XCTAssertTrue(YouGlassContentPolicy.isShortsURL("https://youtube.com/shorts/\(id)"))
    }

    func testContentPolicyRecognizesShortsSignalsWithoutBlockingShortWords() {
        XCTAssertTrue(YouGlassContentPolicy.isShortsText("Quick tips #shorts"))
        XCTAssertTrue(YouGlassContentPolicy.isShortsText("YouTube Shorts compilation"))
        XCTAssertTrue(YouGlassContentPolicy.isShortsSearch("latest shorts"))
        XCTAssertFalse(YouGlassContentPolicy.isShortsText("A short film festival interview"))
    }

    func testRejectsUnsupportedOrMalformedInput() {
        XCTAssertNil(VideoItem.fromYouTubeInput("https://example.com/watch?v=5sTQfGJiVdc"))
        XCTAssertNil(VideoItem.fromYouTubeInput("too-short"))
        XCTAssertNil(VideoItem.fromYouTubeInput("invalid id!"))
    }

    func testVideoThumbnailFallsBackToYouTubeHostedImage() {
        let videoID = "5sTQfGJiVdc"
        let video = VideoItem(
            id: videoID,
            title: "Video",
            channel: "YouTube",
            views: "",
            age: "",
            duration: "",
            imageURL: nil,
            verified: false
        )

        XCTAssertEqual(
            video.thumbnailURL?.absoluteString,
            "https://i.ytimg.com/vi/\(videoID)/hqdefault.jpg"
        )
    }

    func testYouTubeAPIErrorClassifiesQuotaAndTransientFailures() {
        let quota = YouTubeAPIError.httpStatus(
            403,
            reason: "quotaExceeded",
            message: "The request cannot be completed because you have exceeded your quota."
        )
        XCTAssertFalse(quota.isRetryable)
        XCTAssertTrue(quota.localizedDescription.localizedCaseInsensitiveContains("quota"))

        let transient = YouTubeAPIError.httpStatus(503, reason: "backendError", message: "Temporary backend error")
        XCTAssertTrue(transient.isRetryable)
        XCTAssertTrue(transient.localizedDescription.localizedCaseInsensitiveContains("temporary"))

        let throttled = YouTubeAPIError.httpStatus(429, reason: "rateLimitExceeded", message: "Too many requests")
        XCTAssertFalse(throttled.isRetryable)
    }

    func testYouTubeAPIErrorExplainsAuthorizationFailures() {
        let unauthorized = YouTubeAPIError.httpStatus(401, reason: "authError", message: "Invalid Credentials")
        XCTAssertFalse(unauthorized.isRetryable)
        XCTAssertTrue(unauthorized.localizedDescription.localizedCaseInsensitiveContains("authorization"))
    }

    func testLocalCollectionDeduplicatesAndMutatesVideoIDs() {
        var collection = YouGlassLibraryCollection(
            name: "Research",
            videoIDs: ["one", "one", "two"]
        )

        XCTAssertEqual(collection.videoIDs, ["one", "two"])
        collection.add(videoID: "three")
        collection.add(videoID: "three")
        collection.remove(videoID: "one")

        XCTAssertEqual(collection.videoIDs, ["three", "two"])
    }

    func testThemeCustomizationNormalizesShortAndLongHexValues() {
        XCTAssertEqual(YouGlassThemeCustomization.normalizeHex(" #abc "), "#AABBCC")
        XCTAssertEqual(YouGlassThemeCustomization.normalizeHex("#4c8dff"), "#4C8DFF")
        XCTAssertNil(YouGlassThemeCustomization.normalizeHex("#12"))
        XCTAssertNil(YouGlassThemeCustomization.normalizeHex("#GGGGGG"))
    }

    func testPlaybackQueueStateRoundTripsAutoplayPreference() throws {
        let state = YouGlassPlaybackQueueState(videos: [VideoItem.samples[0]], autoplay: false)
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(YouGlassPlaybackQueueState.self, from: data)

        XCTAssertEqual(decoded, state)
    }

    func testRecommendationRankerAlwaysExcludesShortFormWithoutDroppingLongForm() {
        let longForm = VideoItem(
            id: "long-form-1",
            title: "A thoughtful long-form interview",
            channel: "Example Channel",
            views: "1K views",
            age: "1 day ago",
            duration: "24:00",
            imageURL: nil,
            verified: false
        )
        let shortForm = VideoItem(
            id: "short-form-1",
            title: "Quick tips #shorts",
            channel: "Example Channel",
            views: "1K views",
            age: "1 day ago",
            duration: "0:30",
            imageURL: nil,
            verified: false
        )

        XCTAssertTrue(shortForm.isShortForm)
        XCTAssertEqual(
            RecommendationRanker.rank(
                [shortForm, longForm],
                subscriptions: [],
                history: [],
                liked: [],
                seeds: [],
                limit: 40
            ).map(\.id),
            [longForm.id]
        )
    }

    func testCachePolicyReportsFreshAndStaleEntries() {
        let now = Date(timeIntervalSince1970: 10_000)

        XCTAssertTrue(
            YouGlassCachePolicy.isFresh(
                lastUpdated: now.addingTimeInterval(-15),
                now: now,
                maxAge: 30
            )
        )
        XCTAssertFalse(
            YouGlassCachePolicy.isFresh(
                lastUpdated: now.addingTimeInterval(-31),
                now: now,
                maxAge: 30
            )
        )
        XCTAssertFalse(YouGlassCachePolicy.isFresh(lastUpdated: nil, now: now, maxAge: 30))
    }

    func testFeedRefreshPolicyRefreshesMissingAndOldRecommendations() {
        let now = Date(timeIntervalSince1970: 10_000)

        XCTAssertFalse(
            YouGlassFeedRefreshPolicy.needsRefresh(
                lastUpdated: now.addingTimeInterval(-60),
                now: now
            )
        )
        XCTAssertTrue(
            YouGlassFeedRefreshPolicy.needsRefresh(
                lastUpdated: now.addingTimeInterval(-YouGlassFeedRefreshPolicy.activeRefreshInterval - 1),
                now: now
            )
        )
        XCTAssertTrue(YouGlassFeedRefreshPolicy.needsRefresh(lastUpdated: nil, now: now))
    }

    func testFeedRefreshPolicyUsesLongerSubscriptionWindow() {
        let now = Date(timeIntervalSince1970: 10_000)
        let recentSubscriptionSync = now.addingTimeInterval(-4 * 60)
        let staleSubscriptionSync = now.addingTimeInterval(-6 * 60)

        XCTAssertFalse(
            YouGlassFeedRefreshPolicy.needsRefresh(
                lastUpdated: recentSubscriptionSync,
                now: now,
                maxAge: YouGlassFeedRefreshPolicy.subscriptionRefreshInterval
            )
        )
        XCTAssertTrue(
            YouGlassFeedRefreshPolicy.needsRefresh(
                lastUpdated: staleSubscriptionSync,
                now: now,
                maxAge: YouGlassFeedRefreshPolicy.subscriptionRefreshInterval
            )
        )
    }

    func testFeedRefreshPolicyKeepsForegroundAccountDataFresh() {
        XCTAssertEqual(YouGlassFeedRefreshPolicy.activeRefreshInterval, 60)
        XCTAssertEqual(YouGlassFeedRefreshPolicy.accountSignalRefreshInterval, 90)
        XCTAssertEqual(YouGlassFeedRefreshPolicy.subscriptionRefreshInterval, 5 * 60)
        XCTAssertLessThan(
            YouGlassFeedRefreshPolicy.activeRefreshInterval,
            YouGlassFeedRefreshPolicy.subscriptionRefreshInterval
        )
    }

    func testLoadingFeedDoesNotExposeSampleRecommendations() {
        let feed = VideoItem.loadingFeed

        XCTAssertTrue(feed.queue.isEmpty)
        XCTAssertTrue(feed.forYou.isEmpty)
        XCTAssertTrue(feed.trending.isEmpty)
        XCTAssertTrue(feed.more.isEmpty)
    }

    func testResponseCacheStoresAndClearsEntries() async {
        let cache = YouGlassResponseCache(maxEntries: 2)
        let value = Data("value".utf8)

        await cache.insert(value, forKey: "one", ttl: 30, now: Date(timeIntervalSince1970: 10_000))
        let stored = await cache.data(forKey: "one", now: Date(timeIntervalSince1970: 10_010))
        XCTAssertEqual(stored, value)

        let expired = await cache.data(forKey: "one", now: Date(timeIntervalSince1970: 10_031))
        XCTAssertNil(expired)

        await cache.removeAll()
        let cleared = await cache.data(forKey: "one", now: Date(timeIntervalSince1970: 10_010))
        XCTAssertNil(cleared)
    }

    func testPrimaryRecommendationsExcludeShortFormTitles() {
        let short = VideoItem(
            id: "short-video",
            title: "My daily #shorts",
            channel: "Channel",
            views: "",
            age: "",
            duration: "0:30",
            imageURL: nil,
            verified: false
        )
        let long = VideoItem(
            id: "long-video",
            title: "A long-form story",
            channel: "Channel",
            views: "",
            age: "",
            duration: "12:00",
            imageURL: nil,
            verified: false
        )

        XCTAssertTrue(short.isShortForm)
        XCTAssertFalse(long.isShortForm)

        let ranked = RecommendationRanker.rank(
            [short, long],
            subscriptions: [],
            history: [],
            liked: [],
            seeds: [],
            limit: 10
        )

        XCTAssertEqual(ranked.map(\.id), ["long-video"])
    }

    func testRecommendationRankerPromotesSubscribedSavedSignals() {
        let subscribed = VideoItem(
            id: "subscribed-video",
            title: "Fresh upload",
            channel: "Signal Channel",
            views: "",
            age: "1 hour ago",
            duration: "",
            imageURL: nil,
            verified: false,
            channelID: "UC1234567890123456789012"
        )
        let unrelated = VideoItem(
            id: "unrelated-video",
            title: "Other upload",
            channel: "Other Channel",
            views: "",
            age: "1 hour ago",
            duration: "",
            imageURL: nil,
            verified: false,
            channelID: "UC9999999999999999999999"
        )
        let subscription = SubscriptionItem(
            id: "UC1234567890123456789012",
            name: "Signal Channel",
            avatarURL: nil,
            isLive: false
        )

        let ranked = RecommendationRanker.rank(
            [unrelated, subscribed],
            subscriptions: [subscription],
            history: [],
            liked: [],
            seeds: [],
            saved: [subscribed],
            limit: 2
        )

        XCTAssertEqual(ranked.first?.id, "subscribed-video")
    }

    func testRecommendationRankerUsesFreshnessAndChannelDiversity() {
        let firstChannel = (1...3).map { index in
            VideoItem(
                id: "fresh-\(index)",
                title: "Fresh channel upload \(index)",
                channel: "Fresh Channel",
                views: "",
                age: "\(index) minutes ago",
                duration: "",
                imageURL: nil,
                verified: false,
                channelID: "UC1234567890123456789012"
            )
        }
        let secondChannel = VideoItem(
            id: "other-channel",
            title: "Older but different channel upload",
            channel: "Other Channel",
            views: "",
            age: "1 month ago",
            duration: "",
            imageURL: nil,
            verified: false,
            channelID: "UC9999999999999999999999"
        )

        let ranked = RecommendationRanker.rank(
            firstChannel + [secondChannel],
            subscriptions: [],
            history: [],
            liked: [],
            seeds: [],
            limit: 4
        )

        XCTAssertEqual(ranked.first?.id, "fresh-1")
        XCTAssertEqual(ranked.dropFirst().first?.id, "other-channel")
    }

}
