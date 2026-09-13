import XCTest
import WebKit
@testable import YouTubeMac

final class PlaybackAttachmentTests: XCTestCase {
    @MainActor
    func testRetiredSurfaceCannotCancelCurrentSurfaceTasks() {
        let controller = YouTubePlaybackController()
        let oldSurface = WKWebView()
        let currentSurface = WKWebView()
        controller.webView = currentSurface
        let watchdog = Task { @MainActor in }
        let bootstrap = Task { @MainActor in }
        controller.loadWatchdogTask = watchdog
        controller.playbackBootstrapTask = bootstrap

        controller.detach(from: oldSurface)

        XCTAssertTrue(controller.webView === currentSurface)
        XCTAssertNotNil(controller.loadWatchdogTask)
        XCTAssertNotNil(controller.playbackBootstrapTask)
        XCTAssertFalse(watchdog.isCancelled)
        XCTAssertFalse(bootstrap.isCancelled)

        controller.detach(from: currentSurface)
        XCTAssertNil(controller.webView)
        XCTAssertNil(controller.loadWatchdogTask)
        XCTAssertNil(controller.playbackBootstrapTask)
    }
}
