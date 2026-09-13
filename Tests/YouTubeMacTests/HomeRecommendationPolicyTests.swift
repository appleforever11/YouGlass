import XCTest
@testable import YouTubeMac

final class HomeRecommendationPolicyTests: XCTestCase {
    private func video(_ id: String, _ title: String, channel: String = "Other") -> VideoItem {
        VideoItem(id: id, title: title, channel: channel, views: "", age: "",
                  duration: "12:00", imageURL: nil, verified: false)
    }

    func testDefaultHomePromotesInterestsWithoutDiversifyingIntoUnrelatedTopics() {
        let history = [video("watched", "Astronomy telescope", channel: "Space")]
        let unrelated = video("unrelated", "Cooking pasta", channel: "Kitchen")
        let first = video("first", "Astronomy telescope guide", channel: "Space")
        let second = video("second", "Astronomy telescope comparison", channel: "Space")
        let result = HomeRecommendationPolicy.rank([unrelated, first, second],
            subscriptions: [], history: history, liked: [], saved: [])
        XCTAssertEqual(result.map(\.id), [first.id, second.id, unrelated.id])
    }

    func testSubscribedChannelsMoveAheadOfGenericWebSuggestions() {
        let subscription = SubscriptionItem(id: "space", name: "Space", avatarURL: nil, isLive: false)
        let generic = video("generic", "Cooking pasta")
        let subscribed = video("subscribed", "Tonight's sky", channel: "Space")
        XCTAssertEqual(HomeRecommendationPolicy.rank([generic, subscribed],
            subscriptions: [subscription], history: [], liked: [], saved: []).first?.id, subscribed.id)
    }

    func testCacheRestorationIsStableAndUnwatchedSuggestionsPrecedeReplays() {
        let watched = video("watched", "Astronomy telescope", channel: "Space")
        let related = video("related", "Astronomy telescope guide", channel: "Science")
        let discovery = video("discovery", "Cooking pasta", channel: "Kitchen")
        let first = HomeRecommendationPolicy.rank([watched, discovery, related],
            subscriptions: [], history: [watched], liked: [], saved: [])
        let restored = HomeRecommendationPolicy.rank(first,
            subscriptions: [], history: [watched], liked: [], saved: [])
        XCTAssertEqual(first.map(\.id), [related.id, discovery.id, watched.id])
        XCTAssertEqual(restored.map(\.id), first.map(\.id))
    }

    func testNoSignalsPreserveYouTubeOrderAndBoundContent() {
        let videos = [video("one", "Cooking pasta"), video("two", "Astronomy telescope")]
        let shorts = video("short", "Quick tip #shorts")
        XCTAssertEqual(HomeRecommendationPolicy.rank([shorts] + videos + videos,
            subscriptions: [], history: [], liked: [], saved: []).map(\.id), videos.map(\.id))
        XCTAssertEqual(HomeRecommendationPolicy.rank(videos,
            subscriptions: [], history: [], liked: [], saved: [], limit: 1).count, 1)
    }
}
