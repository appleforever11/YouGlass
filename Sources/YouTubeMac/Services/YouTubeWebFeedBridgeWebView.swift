import AppKit
import Foundation
import OSLog
@preconcurrency import WebKit

extension YouTubeWebFeedBridge {
    func existingOrCreateWebView() -> WKWebView {
        if let webView {
            return webView
        }

        let configuration = WKWebViewConfiguration()
        configuration.youGlassDisableWebMaterialsOnAffectedSystems()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        // This view only extracts homepage metadata. Do not let a hidden
        // homepage preview create a media layer or start audio in the app.
        configuration.mediaTypesRequiringUserActionForPlayback = [.audio, .video]

        let webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 1440, height: 1800),
            configuration: configuration
        )
        webView.navigationDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.isHidden = true
        webView.setValue(true, forKey: "drawsBackground")

        // WebKit needs a real AppKit view hierarchy to hydrate custom elements and
        // run the same homepage code path as the visible sign-in web window.
        let hostView = NSView(frame: NSRect(x: 0, y: 0, width: 1440, height: 1800))
        hostView.addSubview(webView)

        let hostWindow = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: 1440, height: 1800),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        hostWindow.contentView = hostView
        hostWindow.isOpaque = true
        hostWindow.backgroundColor = .white
        hostWindow.hasShadow = false
        hostWindow.ignoresMouseEvents = true
        hostWindow.alphaValue = 0.001
        hostWindow.isExcludedFromWindowsMenu = true
        hostWindow.collectionBehavior = [.transient, .ignoresCycle]
        hostWindow.orderOut(nil)

        self.hostWindow = hostWindow
        self.webView = webView
        return webView
    }

    func hasYouTubeSessionCookie() async -> Bool {
        await withCheckedContinuation { continuation in
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                let signedIn = cookies.contains { cookie in
                    let domain = cookie.domain.lowercased()
                    let youtubeDomain = domain.contains("youtube.com") || domain.contains("google.com")
                    return youtubeDomain && Self.sessionCookieNames.contains(cookie.name)
                }
                continuation.resume(returning: signedIn)
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard isCurrentNavigation(navigation) else { return }
        extractionTask?.cancel()
        let generation = requestGeneration
        extractionTask = Task { @MainActor [weak self, weak webView] in
            guard let self, let webView else { return }
            await self.extractVideosWithRetries(from: webView, generation: generation)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard isCurrentNavigation(navigation) else { return }
        logger.error("\(self.requestLabel, privacy: .public) navigation failed: \(error.localizedDescription, privacy: .public)")
        finish(YouTubeWebFeedResult(videos: [], isSignedIn: false, diagnostics: "\(requestLabel) navigation failed"), generation: requestGeneration)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard isCurrentNavigation(navigation) else { return }
        logger.error("\(self.requestLabel, privacy: .public) provisional navigation failed: \(error.localizedDescription, privacy: .public)")
        finish(YouTubeWebFeedResult(videos: [], isSignedIn: false, diagnostics: "\(requestLabel) could not be reached"), generation: requestGeneration)
    }

    func finish(_ result: YouTubeWebFeedResult, generation: Int? = nil) {
        if let generation, generation != requestGeneration { return }
        extractionTask?.cancel()
        extractionTask = nil
        activeNavigation = nil
        guard let continuation else {
            requestActive = false
            let waiters = requestWaiters
            requestWaiters.removeAll()
            waiters.forEach { $0.resume() }
            return
        }
        requestActive = false
        self.continuation = nil
        continuation.resume(returning: result)
        let waiters = requestWaiters
        requestWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func isCurrentNavigation(_ navigation: WKNavigation?) -> Bool {
        guard let activeNavigation else { return true }
        return navigation == nil || navigation === activeNavigation
    }
}
