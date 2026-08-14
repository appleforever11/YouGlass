import XCTest
@testable import YouTubeMac

final class ModelsTests: XCTestCase {
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

    func testPlaybackCheckpointPolicyHasBoundedResumeData() {
        XCTAssertEqual(PlaybackCheckpointPolicy.maxEntries, 200)
        XCTAssertGreaterThan(PlaybackCheckpointPolicy.completionGraceSeconds, 0)
        XCTAssertLessThan(PlaybackCheckpointPolicy.completionGraceSeconds, 10)
        XCTAssertGreaterThan(PlaybackCheckpointPolicy.completionFraction, 0.9)
        XCTAssertLessThan(PlaybackCheckpointPolicy.completionFraction, 1)
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
        XCTAssertEqual(VideoItem.fromYouTubeInput("https://youtube.com/shorts/\(id)")?.id, id)
        XCTAssertEqual(VideoItem.fromYouTubeInput("https://youtube.com/live/\(id)")?.id, id)
        XCTAssertEqual(VideoItem.fromYouTubeInput("https://youtube.com/embed/\(id)")?.id, id)
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
        let recentSubscriptionSync = now.addingTimeInterval(-10 * 60)
        let staleSubscriptionSync = now.addingTimeInterval(-16 * 60)

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
            limit: 10,
            excludeShortForm: true
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

}
