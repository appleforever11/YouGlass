import AppKit
import Foundation
@preconcurrency import WebKit

extension YouTubeCommentsBridge {
    func navigate(to videoID: String, generation: Int) async -> Bool {
        guard navigationContinuation == nil else { return false }
        requestedVideoID = videoID
        loadedVideoID = nil

        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            navigationContinuation = continuation
            navigationTimeout?.cancel()

            let webView = existingOrCreateWebView()
            var components = URLComponents(string: "https://www.youtube.com/watch")!
            components.queryItems = [URLQueryItem(name: "v", value: videoID)]

            var request = URLRequest(
                url: components.url!,
                cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                timeoutInterval: 25
            )
            request.setValue("https://www.youtube.com/", forHTTPHeaderField: "Referer")
            self.activeNavigation = webView.load(request)

            navigationTimeout = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard let self,
                      !Task.isCancelled,
                      self.requestGeneration == generation else { return }
                self.finishNavigation(false, generation: generation)
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard isCurrentNavigation(navigation) else { return }
        navigationTimeout?.cancel()
        let generation = requestGeneration
        Task { @MainActor [weak self, weak webView] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard let self,
                  webView != nil,
                  !Task.isCancelled,
                  self.requestGeneration == generation,
                  self.navigationContinuation != nil else { return }
            self.finishNavigation(true, generation: generation)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard isCurrentNavigation(navigation) else { return }
        logger.error("Comments navigation failed: \(error.localizedDescription, privacy: .public)")
        finishNavigation(false, generation: requestGeneration)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard isCurrentNavigation(navigation) else { return }
        logger.error("Comments provisional navigation failed: \(error.localizedDescription, privacy: .public)")
        finishNavigation(false, generation: requestGeneration)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        loadedVideoID = nil
        finishNavigation(false, generation: requestGeneration)
    }

    nonisolated func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        nil
    }

    nonisolated func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        Task { @MainActor in
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let host = url.host?.lowercased() ?? ""
            let isYouTubeHost = host == "youtube.com" || host.hasSuffix(".youtube.com") || host == "youtube-nocookie.com" || host.hasSuffix(".youtube-nocookie.com")
            let isGoogleHost = host == "google.com" || host.hasSuffix(".google.com") || host == "gstatic.com" || host.hasSuffix(".gstatic.com")
            let isMediaHost = host == "googlevideo.com" || host.hasSuffix(".googlevideo.com") || host == "ytimg.com" || host.hasSuffix(".ytimg.com") || host == "ggpht.com" || host.hasSuffix(".ggpht.com") || host == "googleusercontent.com" || host.hasSuffix(".googleusercontent.com")
            let policy: WKNavigationActionPolicy =
                url.scheme == "about" || url.scheme == "data" || url.scheme == "blob" || isYouTubeHost || isGoogleHost || isMediaHost
                    ? .allow
                    : .cancel

            decisionHandler(policy)
        }
    }

    func existingOrCreateWebView() -> WKWebView {
        if let webView { return webView }

        let configuration = WKWebViewConfiguration()
        configuration.youGlassDisableWebMaterialsOnAffectedSystems()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.mediaTypesRequiringUserActionForPlayback = [.audio, .video]

        let webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 1200, height: 1800),
            configuration: configuration
        )
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.isHidden = true
        webView.setValue(true, forKey: "drawsBackground")

        let hostView = NSView(frame: NSRect(x: 0, y: 0, width: 1200, height: 1800))
        hostView.addSubview(webView)

        let hostWindow = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: 1200, height: 1800),
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

        self.webView = webView
        self.hostWindow = hostWindow
        return webView
    }

    func finishNavigation(_ succeeded: Bool, generation: Int? = nil) {
        if let generation, generation != requestGeneration { return }
        navigationTimeout?.cancel()
        navigationTimeout = nil
        activeNavigation = nil
        guard let continuation = navigationContinuation else { return }
        navigationContinuation = nil
        if succeeded {
            loadedVideoID = requestedVideoID
        }
        continuation.resume(returning: succeeded)
    }

    func isCurrentNavigation(_ navigation: WKNavigation?) -> Bool {
        guard let activeNavigation else { return true }
        return navigation == nil || navigation === activeNavigation
    }
}
