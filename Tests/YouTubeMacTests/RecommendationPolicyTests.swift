import XCTest
@testable import YouTubeMac

final class RecommendationPolicyTests: XCTestCase {
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

    func testRecommendationRankerFavorsCandidatesNotRecentlyPresented() {
        let previouslyPresented = VideoItem(
            id: "previously-presented",
            title: "Older subscribed upload",
            channel: "Subscribed Channel",
            views: "",
            age: "1 day ago",
            duration: "",
            imageURL: nil,
            verified: false,
            channelID: "UC1234567890123456789012"
        )
        let freshCandidate = VideoItem(
            id: "fresh-candidate",
            title: "New upload from another channel",
            channel: "Another Channel",
            views: "",
            age: "just now",
            duration: "",
            imageURL: nil,
            verified: false,
            channelID: "UC9999999999999999999999"
        )
        let subscription = SubscriptionItem(
            id: "UC1234567890123456789012",
            name: "Subscribed Channel",
            avatarURL: nil,
            isLive: false
        )

        let ranked = RecommendationRanker.rank(
            [previouslyPresented, freshCandidate],
            subscriptions: [subscription],
            history: [],
            liked: [],
            seeds: [],
            recentlyPresentedIDs: [previouslyPresented.id],
            favorFresh: true,
            limit: 2
        )

        XCTAssertEqual(ranked.map(\.id), [freshCandidate.id, previouslyPresented.id])
    }

    func testRecommendationRotationPolicyKeepsNewestPresentedIDsBounded() {
        let displayed = (1...3).map { index in
            VideoItem(
                id: "displayed-\(index)",
                title: "Video \(index)",
                channel: "Channel",
                views: "",
                age: "",
                duration: "",
                imageURL: nil,
                verified: false
            )
        }

        let result = RecommendationRotationPolicy.updatedRecentlyPresentedIDs(
            previous: ["old-1", "displayed-2", "old-2"],
            displayed: displayed,
            limit: 4
        )

        XCTAssertEqual(result, ["displayed-1", "displayed-2", "displayed-3", "old-1"])
    }
}
