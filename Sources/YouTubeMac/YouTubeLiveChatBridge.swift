import AppKit
import Foundation
import OSLog
@preconcurrency import WebKit

// The Data API is the primary path. This bridge keeps the signed-in YouTube
// session useful for live chat when the user has not configured an API key.
// It is hosted offscreen and never creates a visible browser window.
@MainActor
final class YouTubeLiveChatBridge: NSObject, WKNavigationDelegate, WKUIDelegate {
    static let shared = YouTubeLiveChatBridge()

    private let logger = Logger(subsystem: "com.kevinhowe.YouGlass", category: "YouTubeLiveChat")
    private var webView: WKWebView?
    private var hostWindow: NSWindow?
    private var requestedVideoID: String?
    private var loadedVideoID: String?
    private var navigationContinuation: CheckedContinuation<Bool, Never>?
    private var navigationTimeout: Task<Void, Never>?

    func load(videoID: String) async -> LiveChatPage {
        guard Self.isValidVideoID(videoID) else {
            return .unavailable
        }

        if loadedVideoID != videoID {
            let loaded = await navigate(to: videoID)
            guard loaded else {
                return LiveChatPage(
                    messages: [],
                    nextPageToken: nil,
                    pollingInterval: 5_000_000_000,
                    isLive: false,
                    isAvailable: false,
                    message: "YouTube live chat could not be reached."
                )
            }
        }

        var lastPage = LiveChatPage(
            messages: [],
            nextPageToken: nil,
            pollingInterval: 5_000_000_000,
            isLive: false,
            isAvailable: false,
            message: "Connecting to live chat..."
        )

        // The live-chat custom elements can arrive after navigation completes.
        // A short retry window handles that without delaying subsequent polls.
        for attempt in 0..<8 {
            let page = await extractCurrentPage()
            lastPage = page
            if page.isLive || page.isAvailable || attempt >= 4 {
                return page
            }
            try? await Task.sleep(nanoseconds: 650_000_000)
        }

        return lastPage
    }

    private func navigate(to videoID: String) async -> Bool {
        guard navigationContinuation == nil else { return false }
        requestedVideoID = videoID
        loadedVideoID = nil

        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            navigationContinuation = continuation
            navigationTimeout?.cancel()

            let webView = existingOrCreateWebView()
            webView.stopLoading()

            var components = URLComponents(string: "https://www.youtube.com/live_chat")!
            components.queryItems = [
                URLQueryItem(name: "v", value: videoID),
                URLQueryItem(name: "is_popout", value: "1"),
                URLQueryItem(name: "dark_theme", value: "1")
            ]
            var request = URLRequest(
                url: components.url!,
                cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                timeoutInterval: 25
            )
            request.setValue("https://www.youtube.com/", forHTTPHeaderField: "Referer")
            webView.load(request)

            navigationTimeout = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard !Task.isCancelled else { return }
                self?.finishNavigation(false)
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationTimeout?.cancel()
        Task { @MainActor [weak self, weak webView] in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            guard let self, webView != nil, !Task.isCancelled else { return }
            self.finishNavigation(true)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        logger.error("Live chat navigation failed: \(error.localizedDescription, privacy: .public)")
        finishNavigation(false)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        logger.error("Live chat provisional navigation failed: \(error.localizedDescription, privacy: .public)")
        finishNavigation(false)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        loadedVideoID = nil
        finishNavigation(false)
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
            let isYouTubeHost = host == "youtube.com" || host.hasSuffix(".youtube.com")
            let isGoogleHost = host == "google.com" || host.hasSuffix(".google.com") || host == "gstatic.com" || host.hasSuffix(".gstatic.com")
            let isMediaHost = host == "googlevideo.com" || host.hasSuffix(".googlevideo.com") || host == "ytimg.com" || host.hasSuffix(".ytimg.com")
            let policy: WKNavigationActionPolicy =
                url.scheme == "about" || url.scheme == "data" || url.scheme == "blob" || isYouTubeHost || isGoogleHost || isMediaHost
                    ? .allow
                    : .cancel

            decisionHandler(policy)
        }
    }

    private func existingOrCreateWebView() -> WKWebView {
        if let webView { return webView }

        let configuration = WKWebViewConfiguration()
        configuration.youGlassDisableWebMaterialsOnAffectedSystems()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.mediaTypesRequiringUserActionForPlayback = [.audio, .video]

        let webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 980, height: 900),
            configuration: configuration
        )
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.isHidden = true
        webView.setValue(true, forKey: "drawsBackground")

        let hostView = NSView(frame: NSRect(x: 0, y: 0, width: 980, height: 900))
        hostView.addSubview(webView)

        let hostWindow = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: 980, height: 900),
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

    private func finishNavigation(_ succeeded: Bool) {
        navigationTimeout?.cancel()
        navigationTimeout = nil
        guard let continuation = navigationContinuation else { return }
        navigationContinuation = nil
        if succeeded {
            loadedVideoID = requestedVideoID
        }
        continuation.resume(returning: succeeded)
    }

    private func extractCurrentPage() async -> LiveChatPage {
        guard let webView else { return .unavailable }

        let script = """
        (() => {
          const clean = value => String(value || '').replace(/\\s+/g, ' ').trim();
          const roots = [document];
          for (const frame of Array.from(document.querySelectorAll('iframe'))) {
            try { if (frame.contentDocument) roots.push(frame.contentDocument); } catch (_) {}
          }
          const queryAll = selector => roots.flatMap(root => Array.from(root.querySelectorAll(selector)));
          const bodyText = roots.map(root => clean(root.body ? root.body.innerText : '')).join(' ');
          const replay = /live chat replay|chat replay|live chat is disabled|comments are turned off/i.test(bodyText);
          const messageNodes = queryAll([
            'yt-live-chat-text-message-renderer',
            'yt-live-chat-paid-message-renderer',
            'yt-live-chat-membership-item-renderer',
            'yt-live-chat-ticker-paid-message-item-renderer'
          ].join(','));
          const chatSurface = queryAll([
            'yt-live-chat-app',
            'yt-live-chat-item-list-renderer',
            '#item-scroller',
            '#items',
            '[role="log"]'
          ].join(',')).length > 0;
          const liveFrame = queryAll('ytd-live-chat-frame').length > 0;
          const isLive = !replay && (messageNodes.length > 0 || chatSurface || liveFrame);
          const text = node => clean(node ? node.textContent : '');
          const image = node => {
            const img = node && node.querySelector ? node.querySelector('img') : null;
            return img ? (img.currentSrc || img.src || img.getAttribute('data-src') || '') : '';
          };
          const messages = [];
          const seen = new Set();
          messageNodes.slice(-100).forEach(node => {
            const author = text(node.querySelector('#author-name, #author-name yt-formatted-string')) || 'YouTube viewer';
            const message = text(node.querySelector('#message, #content')) || text(node);
            if (!message) return;
            const publishedAt = text(node.querySelector('#timestamp')) || 'now';
            const id = node.getAttribute('data-id') || node.getAttribute('data-timestamp') || `${author}|${publishedAt}|${message}`;
            if (seen.has(id)) return;
            seen.add(id);
            messages.push({
              id,
              author,
              text: message,
              publishedAt,
              avatarURL: image(node.querySelector('#author-photo, #author-photo-container')),
              isHighlighted: Boolean(node.matches('yt-live-chat-paid-message-renderer, yt-live-chat-membership-item-renderer') || node.querySelector('#purchase-amount'))
            });
          });
          let status = '';
          if (replay) status = 'This broadcast has ended; live chat is not active.';
          else if (isLive && messages.length === 0) status = 'Waiting for live messages...';
          else if (!isLive) status = 'Live chat is only available while this broadcast is live.';
          return JSON.stringify({
            messages,
            isLive,
            isAvailable: isLive,
            message: status
          });
        })();
        """

        do {
            let value = try await webView.youGlassEvaluateJavaScript(script)
            guard let json = value,
                  let data = json.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(LiveChatBridgePayload.self, from: data) else {
                return .unavailable
            }

            let messages = payload.messages.map { item in
                LiveChatMessage(
                    id: item.id,
                    author: item.author,
                    text: item.text,
                    publishedAt: item.publishedAt,
                    avatarURL: URL(string: item.avatarURL),
                    isHighlighted: item.isHighlighted
                )
            }
            return LiveChatPage(
                messages: messages,
                nextPageToken: nil,
                pollingInterval: 4_000_000_000,
                isLive: payload.isLive,
                isAvailable: payload.isAvailable,
                message: payload.message
            )
        } catch {
            logger.error("Live chat extraction failed: \(error.localizedDescription, privacy: .public)")
            return .unavailable
        }
    }

    private static func isValidVideoID(_ value: String) -> Bool {
        value.count == 11 && value.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
    }
}

private struct LiveChatBridgePayload: Decodable {
    let messages: [LiveChatBridgeMessage]
    let isLive: Bool
    let isAvailable: Bool
    let message: String?
}

private struct LiveChatBridgeMessage: Decodable {
    let id: String
    let author: String
    let text: String
    let publishedAt: String
    let avatarURL: String
    let isHighlighted: Bool
}
