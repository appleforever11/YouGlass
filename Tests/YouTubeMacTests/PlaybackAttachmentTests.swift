import XCTest
import WebKit
@testable import YouTubeMac

final class PlaybackAttachmentTests: XCTestCase {
    @MainActor
    func testSurfaceHandoffKeepsPlaybackAndLateOldHostTeardownCannotStopIt() {
        let controller = YouTubePlaybackController()
        let surface = WKWebView()
        let oldHost = YouTubeInlinePlayerHostView(webView: surface)
        controller.webView = surface
        controller.isSurfaceReady = true
        controller.currentTime = 42
        controller.isTransferringSurface = true

        controller.dismantleSurface(in: oldHost)
        XCTAssertTrue(controller.webView === surface)
        let newHost = YouTubeInlinePlayerHostView(webView: surface)
        controller.isTransferringSurface = false
        controller.dismantleSurface(in: oldHost)
        XCTAssertTrue(controller.webView === surface)
        XCTAssertTrue(surface.superview === newHost)
        XCTAssertTrue(controller.isSurfaceReady)
        XCTAssertEqual(controller.currentTime, 42)

        controller.stopPlayback()
        XCTAssertNil(controller.webView)
        XCTAssertFalse(controller.isSurfaceReady)
    }

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
