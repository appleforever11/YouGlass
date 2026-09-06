import AppKit
@preconcurrency import WebKit
import XCTest
@testable import YouTubeMac

@MainActor
final class PlayerViewportTests: XCTestCase {
    func testVideoStaysInViewportAcrossWideLayoutSwitch() async throws {
        let script = YouTubeInlinePlayerView.playerChromeScriptPart1
        let pattern = try NSRegularExpression(pattern: "const styleText = `([\\s\\S]*?)`;")
        let match = try XCTUnwrap(pattern.firstMatch(
            in: script, range: NSRange(script.startIndex..., in: script)
        ))
        let range = try XCTUnwrap(Range(match.range(at: 1), in: script))
        let style = String(script[range])
        let loaded = expectation(description: "Local player layout loaded")
        let navigation = ViewportNavigation { loaded.fulfill() }
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 380, height: 214))
        webView.navigationDelegate = navigation
        webView.loadHTMLString("""
        <html><head><style>
        \(style)
        .wide-layout-slot { display: none; }
        @media (min-width: 1000px) {
          .wide-layout-slot { display: block; height: 100vh; }
        }
        </style></head><body><ytd-watch-flexy>
          <div class="wide-layout-slot"></div>
          <div id="player"><div id="movie_player"><video></video></div></div>
        </ytd-watch-flexy></body></html>
        """, baseURL: nil)
        await fulfillment(of: [loaded], timeout: 10)
        defer { webView.stopLoading() }

        for size in [CGSize(width: 240, height: 135), CGSize(width: 380, height: 214),
                     CGSize(width: 988, height: 556), CGSize(width: 1036, height: 583),
                     CGSize(width: 1600, height: 900), CGSize(width: 380, height: 214)] {
            webView.setFrameSize(size)
            // WebKit applies native viewport updates on its process run loop.
            try await Task.sleep(for: .milliseconds(100))
            let result = try await webView.evaluateJavaScript("""
            (() => {
              const r = document.querySelector('video').getBoundingClientRect();
              return [r.x, r.y, r.width, r.height, innerWidth, innerHeight];
            })()
            """)
            let rect = try XCTUnwrap(result as? [Double])
            XCTAssertEqual(rect.count, 6)
            XCTAssertEqual(rect[0], 0, accuracy: 1, "At \(size)")
            XCTAssertEqual(rect[1], 0, accuracy: 1, "Video moved offscreen at \(size)")
            XCTAssertEqual(rect[2], size.width, accuracy: 1)
            XCTAssertEqual(rect[3], size.height, accuracy: 1)
            XCTAssertEqual(rect[4], size.width, accuracy: 1)
            XCTAssertEqual(rect[5], size.height, accuracy: 1)
        }
    }
}

@MainActor
private final class ViewportNavigation: NSObject, WKNavigationDelegate {
    let onFinish: () -> Void
    init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { onFinish() }
}
