import Combine
import XCTest
@testable import YouTubeMac

final class PlaybackUpdatePerformanceTests: XCTestCase {
    @MainActor
    func testRepeatedBridgeStateDoesNotPublish() {
        let controller = YouTubePlaybackController()
        controller.activeVideoID = "abcdefghijk"
        let payload: [String: Any] = [
            "videoID": "abcdefghijk", "muted": false,
            "captionsEnabled": true, "captionText": "A caption",
            "playing": true, "ended": false, "pipAvailable": true,
            "pipActive": false, "currentTime": 12.0, "duration": 100.0,
            "playbackRate": 1.0, "status": "Player ready", "frameReady": true
        ]
        controller.update(from: payload)
        var updates = 0
        let observation = controller.objectWillChange.sink { updates += 1 }
        controller.update(from: payload)
        XCTAssertEqual(updates, 0)
        controller.update(from: ["videoID": "abcdefghijk", "captionText": "Next caption"])
        XCTAssertEqual(updates, 1)
        XCTAssertTrue(controller.isSurfaceReady)
        withExtendedLifetime(observation) {}
    }
}
