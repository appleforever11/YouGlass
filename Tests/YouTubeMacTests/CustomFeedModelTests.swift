import XCTest
@testable import YouTubeMac

final class CustomFeedModelTests: XCTestCase {
    func testCustomFeedPromptInterpreterExtractsLocalPreferences() {
        let intent = YouGlassCustomFeedPromptInterpreter.interpret(
            "Show long-form courtroom analysis from my subscriptions this week, no Shorts"
        )

        XCTAssertEqual(intent.searchQuery, "courtroom analysis")
        XCTAssertEqual(intent.keywords, ["courtroom", "analysis"])
        XCTAssertTrue(intent.subscribedOnly)
        XCTAssertEqual(intent.freshnessHours, 168)
        XCTAssertEqual(intent.duration, .long)
        XCTAssertTrue(intent.excludesShorts)
        XCTAssertEqual(
            YouGlassCustomFeedPromptInterpreter.suggestedName(
                for: "Show long-form courtroom analysis from my subscriptions this week, no Shorts"
            ),
            "Courtroom Analysis"
        )
    }

    func testCustomFeedPromptInterpreterKeepsTopicWordsAndBoundsKeywords() {
        let intent = YouGlassCustomFeedPromptInterpreter.interpret(
            "Find the latest Apple Vision Pro reviews and setup guides"
        )

        XCTAssertEqual(intent.searchQuery, "apple vision pro reviews setup guides")
        XCTAssertEqual(intent.freshnessHours, 72)
        XCTAssertFalse(intent.subscribedOnly)
        XCTAssertNil(intent.duration)
    }

    func testCustomFeedIntentMatchesSubscriptionsDurationAndFreshness() {
        let subscription = SubscriptionItem(
            id: "UC1234567890123456789012",
            name: "Courtroom Channel",
            avatarURL: nil,
            isLive: false
        )
        let intent = YouGlassCustomFeedIntent(
            searchQuery: "courtroom",
            keywords: ["courtroom"],
            subscribedOnly: true,
            freshnessHours: 48,
            duration: .long,
            excludesShorts: true
        )
        let eligible = VideoItem(
            id: "eligible-custom-feed-video",
            title: "Courtroom analysis",
            channel: "Courtroom Channel",
            views: "",
            age: "1 day ago",
            duration: "32:00",
            imageURL: nil,
            verified: false,
            channelID: subscription.id
        )
        let old = VideoItem(
            id: "old-custom-feed-video",
            title: "Courtroom analysis",
            channel: "Courtroom Channel",
            views: "",
            age: "3 days ago",
            duration: "32:00",
            imageURL: nil,
            verified: false,
            channelID: subscription.id
        )
        let unrelated = VideoItem(
            id: "unrelated-custom-feed-video",
            title: "Courtroom analysis",
            channel: "Another Channel",
            views: "",
            age: "1 day ago",
            duration: "32:00",
            imageURL: nil,
            verified: false,
            channelID: "UC9999999999999999999999"
        )

        XCTAssertTrue(intent.matches(eligible, subscriptions: [subscription]))
        XCTAssertFalse(intent.matches(old, subscriptions: [subscription]))
        XCTAssertFalse(intent.matches(unrelated, subscriptions: [subscription]))
        XCTAssertEqual(YouGlassCustomFeedIntent.durationSeconds("1:02:03"), 3_723)
    }

    func testCustomFeedDefinitionsRoundTripWithoutVideoResults() throws {
        let feed = YouGlassCustomFeed(
            name: "Courtroom Analysis",
            prompt: "Long-form courtroom analysis from my subscriptions"
        )

        let data = try JSONEncoder().encode(feed)
        let decoded = try JSONDecoder().decode(YouGlassCustomFeed.self, from: data)

        XCTAssertEqual(decoded, feed)
        XCTAssertEqual(decoded.intent.searchQuery, "courtroom analysis")
        XCTAssertNil(decoded.intent.freshnessHours)
    }
}
