import XCTest
@testable import YouTubeMac

final class HomeRecommendationPolicyTests: XCTestCase {
    private func video(_ id: String, _ title: String, channel: String = "Other") -> VideoItem {
        VideoItem(id: id, title: title, channel: channel, views: "", age: "",
                  duration: "12:00", imageURL: nil, verified: false)
    }

    func testLocalInterestsDoNotOverrideYouTubeRanking() {
        let unrelated = video("unrelated", "Cooking pasta", channel: "Kitchen")
        let first = video("first", "Astronomy telescope guide", channel: "Space")
        let second = video("second", "Astronomy telescope comparison", channel: "Space")
        let result = HomeRecommendationPolicy.sourceOrdered([unrelated, first, second])
        XCTAssertEqual(result.map(\.id), [unrelated.id, first.id, second.id])
    }

    func testSubscriptionsDoNotOverrideYouTubeRanking() {
        let generic = video("generic", "Cooking pasta")
        let subscribed = video("subscribed", "Tonight's sky", channel: "Space")
        XCTAssertEqual(HomeRecommendationPolicy.sourceOrdered([generic, subscribed]).first?.id, generic.id)
    }

    func testCacheRestorationPreservesReplaysInYouTubeOrder() {
        let watched = video("watched", "Astronomy telescope", channel: "Space")
        let related = video("related", "Astronomy telescope guide", channel: "Science")
        let discovery = video("discovery", "Cooking pasta", channel: "Kitchen")
        let first = HomeRecommendationPolicy.sourceOrdered([watched, discovery, related])
        let restored = HomeRecommendationPolicy.sourceOrdered(first)
        XCTAssertEqual(first.map(\.id), [watched.id, discovery.id, related.id])
        XCTAssertEqual(restored.map(\.id), first.map(\.id))
    }

    func testNoSignalsPreserveYouTubeOrderAndBoundContent() {
        let videos = [video("one", "Cooking pasta"), video("two", "Astronomy telescope")]
        let shorts = video("short", "Quick tip #shorts")
        XCTAssertEqual(HomeRecommendationPolicy.sourceOrdered([shorts] + videos + videos).map(\.id), videos.map(\.id))
        XCTAssertEqual(HomeRecommendationPolicy.sourceOrdered(videos, limit: 1).count, 1)
        XCTAssertTrue(HomeRecommendationPolicy.sourceOrdered(videos, limit: 0).isEmpty)
        XCTAssertEqual(HomeRecommendationPolicy.sourceOrdered((0..<60).map {
            video("video\($0)", "Long form video")
        }, limit: 80).count, 40)
    }
}
