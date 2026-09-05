import XCTest
@testable import YouTubeMac

final class PlaybackAndFeedPolicyTests: XCTestCase {
    func testPlaybackQueueStateRoundTripsAutoplayPreference() throws {
        let state = YouGlassPlaybackQueueState(videos: [VideoItem.samples[0]], autoplay: false)
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(YouGlassPlaybackQueueState.self, from: data)

        XCTAssertEqual(decoded, state)
    }

    func testPlaybackQueueKeepsOrderWhenAutoplaySelectsTheNextVideo() {
        let first = VideoItem(
            id: "first-video",
            title: "First video",
            channel: "Example",
            views: "",
            age: "",
            duration: "",
            imageURL: nil,
            verified: false
        )
        let second = VideoItem(
            id: "second-video",
            title: "Second video",
            channel: "Example",
            views: "",
            age: "",
            duration: "",
            imageURL: nil,
            verified: false
        )
        let third = VideoItem(
            id: "third-video",
            title: "Third video",
            channel: "Example",
            views: "",
            age: "",
            duration: "",
            imageURL: nil,
            verified: false
        )

        let initialQueue = YouGlassPlaybackQueuePolicy.prepare(
            for: first,
            existingQueue: [],
            source: [first, second, third]
        )
        let queueAfterAutoplay = YouGlassPlaybackQueuePolicy.prepare(
            for: second,
            existingQueue: initialQueue,
            source: [first, second, third]
        )

        XCTAssertEqual(initialQueue.map(\.id), [first.id, second.id, third.id])
        XCTAssertEqual(queueAfterAutoplay.map(\.id), [first.id, second.id, third.id])
        let currentIndex = queueAfterAutoplay.firstIndex { $0.id == second.id }
        XCTAssertEqual(currentIndex.map { queueAfterAutoplay[$0 + 1].id }, third.id)
    }

    func testPlaybackQueueBackfillsAOneItemPersistedQueue() {
        let first = VideoItem(
            id: "persisted-video",
            title: "Persisted video",
            channel: "Example",
            views: "",
            age: "",
            duration: "",
            imageURL: nil,
            verified: false
        )
        let second = VideoItem(
            id: "next-video",
            title: "Next video",
            channel: "Example",
            views: "",
            age: "",
            duration: "",
            imageURL: nil,
            verified: false
        )
        let third = VideoItem(
            id: "following-video",
            title: "Following video",
            channel: "Example",
            views: "",
            age: "",
            duration: "",
            imageURL: nil,
            verified: false
        )

        let queue = YouGlassPlaybackQueuePolicy.prepare(
            for: first,
            existingQueue: [first],
            source: [first, second, third]
        )

        XCTAssertEqual(queue.map(\.id), [first.id, second.id, third.id])
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
        XCTAssertEqual(YouGlassFeedRefreshPolicy.manualRefreshMinimumInterval, 15)
        XCTAssertEqual(YouGlassFeedRefreshPolicy.accountSignalRefreshInterval, 90)
        XCTAssertEqual(YouGlassFeedRefreshPolicy.subscriptionRefreshInterval, 5 * 60)
        XCTAssertEqual(YouGlassFeedRefreshPolicy.homeSubscriptionChannelLimit, 12)
        XCTAssertEqual(YouGlassFeedRefreshPolicy.homeSubscriptionVideosPerChannel, 2)
        XCTAssertEqual(YouGlassFeedRefreshPolicy.homeSubscriptionFeedTimeout, 4)
        XCTAssertLessThan(
            YouGlassFeedRefreshPolicy.activeRefreshInterval,
            YouGlassFeedRefreshPolicy.subscriptionRefreshInterval
        )
    }

    func testRateLimitStateReportsCooldownWithoutSleeping() async {
        let state = YouGlassRateLimitState()
        let now = Date()

        let initiallyBlocked = await state.isBlocked(now: now)
        XCTAssertFalse(initiallyBlocked)
        await state.markRateLimited(cooldown: 30)
        let blocked = await state.isBlocked(now: now)
        XCTAssertTrue(blocked)
        await state.reset()
        let reset = await state.isBlocked()
        XCTAssertFalse(reset)
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
}
