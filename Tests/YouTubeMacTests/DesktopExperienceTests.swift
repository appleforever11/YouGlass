import XCTest
@testable import YouTubeMac

final class DesktopExperienceTests: XCTestCase {
    func testLibrarySearchMatchesAcrossTitleAndChannelWithoutChangingOrder() {
        let videos = (1...4).map(makeVideo)
        XCTAssertEqual(YouGlassLibrarySearch.videos(matching: "example VIDEO", in: videos).map(\.id), videos.map(\.id))
        XCTAssertEqual(YouGlassLibrarySearch.videos(matching: "Example 2", in: videos).map(\.id), ["video-2"])
        XCTAssertTrue(YouGlassLibrarySearch.videos(matching: "missing", in: videos).isEmpty)
    }

    func testLibrarySearchTreatsWhitespaceAsNoFilter() {
        let videos = (1...3).map(makeVideo)
        XCTAssertEqual(YouGlassLibrarySearch.videos(matching: " \n\t ", in: videos), videos)
        XCTAssertTrue(YouGlassLibrarySearch.videos(matching: "example", in: []).isEmpty)
    }

    func testPlayNextInsertsImmediatelyAfterCurrentQueueCursor() {
        let queue = (1...4).map(makeVideo)
        let inserted = makeVideo(index: 99)

        let updated = YouGlassPlaybackQueuePolicy.insertingNext(
            inserted,
            into: queue,
            currentVideoID: queue[1].id
        )

        XCTAssertEqual(
            updated.map(\.id),
            [queue[0].id, queue[1].id, inserted.id, queue[2].id, queue[3].id]
        )
    }

    func testPlayNextRemainsReachableWhenBoundedQueueIsFull() {
        let queue = (1...YouGlassPlaybackQueuePolicy.maxEntries).map(makeVideo)
        let inserted = makeVideo(index: 99)

        let updated = YouGlassPlaybackQueuePolicy.insertingNext(
            inserted,
            into: queue,
            currentVideoID: queue.last?.id
        )

        XCTAssertEqual(updated.count, YouGlassPlaybackQueuePolicy.maxEntries)
        XCTAssertEqual(updated.suffix(2).map(\.id), [queue.last!.id, inserted.id])
    }

    func testPlayNextWithoutCursorSurvivesBoundedQueue() {
        let queue = (1...YouGlassPlaybackQueuePolicy.maxEntries).map(makeVideo)
        let inserted = makeVideo(index: 99)

        let updated = YouGlassPlaybackQueuePolicy.insertingNext(
            inserted,
            into: queue,
            currentVideoID: nil
        )

        XCTAssertEqual(updated.count, YouGlassPlaybackQueuePolicy.maxEntries)
        XCTAssertEqual(updated.last?.id, inserted.id)
    }

    func testSettingsSearchMatchesPagesByFeatureKeyword() {
        XCTAssertTrue(YouGlassSettingsPage.playback.matches("captions"))
        XCTAssertTrue(YouGlassSettingsPage.account.matches("API key"))
        XCTAssertTrue(YouGlassSettingsPage.appearance.matches("dark"))
        XCTAssertTrue(YouGlassSettingsPage.privacy.matches("keychain"))
        XCTAssertFalse(YouGlassSettingsPage.notifications.matches("playback speed"))
        XCTAssertTrue(YouGlassSettingsPage.about.matches("  "))
    }

    private func makeVideo(index: Int) -> VideoItem {
        VideoItem(
            id: "video-\(index)",
            title: "Video \(index)",
            channel: "Example",
            views: "",
            age: "",
            duration: "10:00",
            imageURL: nil,
            verified: false
        )
    }
}
