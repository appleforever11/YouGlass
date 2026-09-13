import JavaScriptCore
import XCTest
@testable import YouTubeMac

@MainActor
final class PlaybackScriptLifecycleTests: XCTestCase {
    private func context() throws -> JSContext {
        let context = try XCTUnwrap(JSContext())
        context.evaluateScript("""
        var window = this;
        var messages = [], pending = [], timers = [], plays = 0;
        var HTMLMediaElement = { HAVE_METADATA: 1, HAVE_CURRENT_DATA: 2, NETWORK_LOADING: 2 };
        var media = {
          isConnected: true, currentSrc: 'first', src: '', dataset: {},
          readyState: 1, duration: 100, currentTime: 0, playbackRate: 1,
          videoWidth: 0, videoHeight: 0, paused: true, muted: true, volume: 0,
          addEventListener() {}, closest() { return null; },
          pause() { this.paused = true; },
          play() {
            plays++;
            return { then(callback) {
              var request = { resolve: callback };
              pending.push(request);
              return { catch(callback) { request.reject = callback; } };
            } };
          }
        };
        var style = { textContent: '' };
        var document = {
          head: {}, documentElement: {},
          getElementById() { return style; },
          querySelector(selector) { return selector === 'video' ? media : null; },
          querySelectorAll() { return []; }, addEventListener() {}
        };
        window.webkit = { messageHandlers: { youglassPlayback: {
          postMessage(message) { messages.push(message); }
        } } };
        window.setInterval = callback => { timers.push(callback); return timers.length; };
        window.clearInterval = () => {};
        window.setTimeout = callback => { timers.push(callback); return timers.length; };
        var observer;
        var MutationObserver = function(callback) {
          observer = callback;
          this.observe = () => {};
          this.disconnect = () => {};
        };
        """);
        return context
    }

    private var script: String {
        YouTubeInlinePlayerView.playerChromeScript
            .replacingOccurrences(of: "__YOUGLASS_AUTO_MUTE__", with: "false")
            .replacingOccurrences(of: "__YOUGLASS_VIDEO_ID__", with: "M7lc1UVf-VE")
    }

    func testNavigationReinjectionPreservesPausedChoiceAndBridgeGeneration() throws {
        let context = try context()
        context.evaluateScript(script)
        XCTAssertNil(context.exception)
        context.evaluateScript("window.__youglassUserPlaybackChoice = 'paused'; var generation = window.__youglassPlaybackScriptGeneration;")
        context.evaluateScript(script)
        XCTAssertNil(context.exception)
        XCTAssertTrue(context.evaluateScript("window.__youglassPlaybackScriptGeneration === generation")!.toBool())
        XCTAssertEqual(context.evaluateScript("window.__youglassUserPlaybackChoice")?.toString(), "paused")
        XCTAssertEqual(context.evaluateScript("plays")?.toInt32(), 1)
    }

    func testSourceReplacementCanStartWhileOldPlayIsPending() throws {
        let context = try context()
        context.evaluateScript(script)
        XCTAssertNil(context.exception)
        context.evaluateScript("media.currentSrc = 'replacement'; window.__youglassControls.startPlayback();")
        XCTAssertEqual(context.evaluateScript("plays")?.toInt32(), 2)
        context.evaluateScript("pending[0].reject();")
        XCTAssertTrue(context.evaluateScript("window.__youglassPlayRequestInFlight")!.toBool())
        context.evaluateScript("pending[1].resolve();")
        XCTAssertFalse(context.evaluateScript("window.__youglassPlayRequestInFlight")!.toBool())
        XCTAssertNil(context.exception)
    }

    func testMutationBurstsScheduleOneRefresh() throws {
        let context = try context()
        context.evaluateScript(script)
        context.evaluateScript("var timerCount = timers.length; for (var i = 0; i < 100; i++) observer();")
        XCTAssertNil(context.exception)
        XCTAssertEqual(context.evaluateScript("timers.length - timerCount")?.toInt32(), 1)
    }

    func testDuplicateTransportUpdatesAreSuppressed() throws {
        let context = try context()
        context.evaluateScript(script)
        context.evaluateScript("media.readyState = 2; media.videoWidth = 640; media.videoHeight = 360; media.paused = false; window.__youglassControls.startPlayback(); var count = messages.length;")
        context.evaluateScript("for (var i = 0; i < 100; i++) window.__youglassControls.startPlayback();")
        XCTAssertNil(context.exception)
        XCTAssertEqual(context.evaluateScript("messages.length - count")?.toInt32(), 0)
    }
}
