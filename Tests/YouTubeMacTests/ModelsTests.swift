import XCTest
@testable import YouTubeMac

final class ModelsTests: XCTestCase {
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
    }

    func testYouTubeAPIErrorExplainsAuthorizationFailures() {
        let unauthorized = YouTubeAPIError.httpStatus(401, reason: "authError", message: "Invalid Credentials")
        XCTAssertFalse(unauthorized.isRetryable)
        XCTAssertTrue(unauthorized.localizedDescription.localizedCaseInsensitiveContains("authorization"))
    }

}
