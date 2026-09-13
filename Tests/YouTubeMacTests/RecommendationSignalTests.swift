import XCTest
@testable import YouTubeMac

final class RecommendationSignalTests: XCTestCase {
    private func video(_ id: String, _ title: String, channel: String = "Channel", channelID: String? = nil) -> VideoItem {
        VideoItem(id: id, title: title, channel: channel, views: "", age: "",
                  duration: "12:00", imageURL: nil, verified: false, channelID: channelID)
    }

    func testLikesStillTeachTopicsWithLongHistory() {
        let history = (0..<100).map { video("history-\($0)", "Gardening", channel: "Garden") }
        let liked = video("liked", "Astronomy telescope", channel: "Space")
        let candidate = video("new", "Astronomy telescope review", channel: "Science")
        let unrelated = video("other", "Cooking pasta", channel: "Kitchen")
        let ranked = RecommendationRanker.rank([unrelated, candidate], subscriptions: [],
                                               history: history, liked: [liked], seeds: [])
        XCTAssertEqual(ranked.first?.id, candidate.id)
    }

    func testChannelAffinityDoesNotConfuseIdenticalNamesWithDifferentIDs() {
        let liked = video("liked", "Something", channelID: "UC1234567890123456789012")
        let impostor = video("other", "Unrelated", channelID: "UC9999999999999999999999")
        let signals = RecommendationSignals(history: [], liked: [liked], saved: [])
        XCTAssertEqual(signals.score(impostor), 0)
    }

    func testContextExcludesCurrentVideoBeforeApplyingLimit() {
        let current = video("current", "Astronomy telescope", channel: "Space")
        let related = video("related", "Astronomy telescope guide", channel: "Science")
        let unrelated = video("other", "Cooking pasta", channel: "Kitchen")
        let ranked = RecommendationRanker.rank([current, unrelated, related], subscriptions: [],
                                               history: [], liked: [], seeds: [],
                                               contextVideo: current, limit: 2)
        XCTAssertEqual(ranked.map(\.id), [related.id, unrelated.id])
    }

    func testChannelDiversityDoesNotPromoteRepeatedVideosOverUnseenOnes() {
        let first = video("first", "Astronomy")
        let second = video("second", "Astronomy")
        let repeated = video("repeated", "Astronomy", channel: "Different")
        let ranked = RecommendationRanker.rank([first, repeated, second], subscriptions: [],
                                               history: [], liked: [], seeds: [],
                                               recentlyPresentedIDs: [repeated.id], favorFresh: true)
        XCTAssertEqual(ranked.map(\.id), [first.id, second.id, repeated.id])
    }

    func testRotatingWindowsReachAllSubscriptionsWithoutDuplicates() {
        let channels = Array(0..<31)
        let windows = (0..<31).map {
            RecommendationSourcePolicy.rotatingWindow(channels, limit: 12,
                now: Date(timeIntervalSince1970: Double($0) * 300))
        }
        XCTAssertTrue(windows.allSatisfy { $0.count == 12 && Set($0).count == 12 })
        XCTAssertEqual(Set(windows.flatMap { $0 }), Set(channels))
        XCTAssertEqual(RecommendationSourcePolicy.rotatingWindow(channels, limit: 0), [])
    }

    func testGenericWordsAndDuplicateSignalsDoNotInflateAffinity() {
        let liked = video("liked", "The official full video", channel: "Source")
        let candidate = video("candidate", "The official full video", channel: "Other")
        XCTAssertEqual(RecommendationSignals(history: [], liked: [liked], saved: []).score(candidate), 0)
        let once = RecommendationSignals(history: [], liked: [liked], saved: []).score(liked)
        let repeated = RecommendationSignals(history: [], liked: [liked, liked], saved: []).score(liked)
        XCTAssertEqual(once, repeated)
    }

    func testFeedPartitionPreservesEveryLoadedVideoInOrder() {
        let videos = (0..<100).map { video("video-\($0)", "Long form") }
        var feed = HomeFeed(hero: videos[0], queue: [], forYou: [], trending: [], more: [])
        feed.replaceVideos(videos)
        XCTAssertEqual((feed.forYou + feed.trending + feed.more + feed.queue).map(\.id), videos.map(\.id))
        XCTAssertEqual(feed.hero.id, videos[0].id)
    }

    func testUpNextTopicOutranksUnrelatedSubscribedFavorite() {
        let current = video("current", "MacBook Neo review", channel: "Tech")
        let related = video("related", "MacBook Neo guide", channel: "Computers")
        let favorite = video("favorite", "Courtroom analysis", channel: "Crime")
        let subscription = SubscriptionItem(id: "crime", name: "Crime", avatarURL: nil, isLive: false)
        let ranked = RecommendationRanker.rank([favorite, related], subscriptions: [subscription],
            history: [favorite], liked: [favorite], seeds: [], saved: [favorite], contextVideo: current)
        XCTAssertEqual(ranked.first?.id, related.id)
    }
}
