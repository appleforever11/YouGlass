import AppKit
import Foundation
import WebKit

@MainActor
final class YouTubeSubscriptionBridge: NSObject, WKNavigationDelegate {
    static let shared = YouTubeSubscriptionBridge()

    private static let sessionCookieNames: Set<String> = [
        "APISID",
        "HSID",
        "LOGIN_INFO",
        "SAPISID",
        "SID",
        "SSID",
        "__Secure-1PAPISID",
        "__Secure-1PSID",
        "__Secure-1PSIDTS",
        "__Secure-3PAPISID",
        "__Secure-3PSID",
        "__Secure-3PSIDTS"
    ]

    private var webView: WKWebView?
    private var hostWindow: NSWindow?
    private var continuation: CheckedContinuation<[SubscriptionItem], Never>?
    private var extractionTask: Task<Void, Never>?
    private var requestedMaxResults = 40
    private var triedDedicatedSubscriptionsRoute = false

    func loadSubscriptions(maxResults: Int = 40) async -> [SubscriptionItem] {
        guard continuation == nil else { return [] }
        guard await hasYouTubeSessionCookie() else { return [] }

        requestedMaxResults = max(1, min(maxResults, 200))
        triedDedicatedSubscriptionsRoute = false

        let webView = existingOrCreateWebView()
        webView.stopLoading()
        extractionTask?.cancel()

        let timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 18_000_000_000)
            guard let self, self.continuation != nil else { return }
            self.finish([])
        }

        // The signed-in homepage contains the same account-owned subscription
        // rail that YouGlass already uses for personalized recommendations.
        // The dedicated /feed/channels route changed its renderer structure
        // and no longer exposes reliable channel cards to this metadata pass.
        let request = URLRequest(
            url: URL(string: "https://www.youtube.com/")!,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 20
        )

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<[SubscriptionItem], Never>) in
            self.continuation = continuation
            webView.load(request)
        }

        timeoutTask.cancel()
        extractionTask?.cancel()
        extractionTask = nil
        return result
    }

    private func existingOrCreateWebView() -> WKWebView {
        if let webView {
            return webView
        }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.mediaTypesRequiringUserActionForPlayback = [.audio, .video]

        let webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 1440, height: 1800),
            configuration: configuration
        )
        webView.navigationDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.isHidden = true
        webView.setValue(false, forKey: "drawsBackground")

        let hostView = NSView(frame: NSRect(x: 0, y: 0, width: 1440, height: 1800))
        hostView.addSubview(webView)

        let hostWindow = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: 1440, height: 1800),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        hostWindow.contentView = hostView
        hostWindow.isOpaque = false
        hostWindow.backgroundColor = .clear
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

    private func hasYouTubeSessionCookie() async -> Bool {
        await withCheckedContinuation { continuation in
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                let signedIn = cookies.contains { cookie in
                    let domain = cookie.domain.lowercased()
                    let isYouTubeDomain = domain.contains("youtube.com") || domain.contains("google.com")
                    return isYouTubeDomain && Self.sessionCookieNames.contains(cookie.name)
                }
                continuation.resume(returning: signedIn)
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        extractionTask?.cancel()
        extractionTask = Task { @MainActor [weak self, weak webView] in
            guard let self, let webView else { return }

            for attempt in 0..<10 {
                try? await Task.sleep(nanoseconds: attempt == 0 ? 1_000_000_000 : 750_000_000)

                if attempt == 2 || attempt == 5 || attempt == 8 {
                    _ = try? await webView.evaluateJavaScript(
                        "window.scrollTo(0, Math.max(document.documentElement.scrollHeight * 0.55, 900)); void 0;"
                    )
                }

                let subscriptions = await self.extractSubscriptions(from: webView, maxResults: self.requestedMaxResults)
                if !subscriptions.isEmpty {
                    self.finish(subscriptions)
                    return
                }

                if attempt == 3,
                   !self.triedDedicatedSubscriptionsRoute,
                   webView.url?.path != "/feed/channels" {
                    self.triedDedicatedSubscriptionsRoute = true
                    webView.load(URLRequest(
                        url: URL(string: "https://www.youtube.com/feed/channels")!,
                        cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                        timeoutInterval: 20
                    ))
                    return
                }
            }

            self.finish([])
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish([])
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish([])
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        finish([])
    }

    private func extractSubscriptions(from webView: WKWebView, maxResults: Int) async -> [SubscriptionItem] {
        let script = """
        (() => {
          const limit = \(maxResults);
          const seen = new Set();
          const items = [];
          const clean = value => String(value || '').replace(/\\s+/g, ' ').trim();
          const channelPattern = /\\/(?:channel\\/UC[A-Za-z0-9_-]+|@[A-Za-z0-9._-]+)/;

          const handleName = href => {
            const match = String(href || '').match(/\\/@([^/?#]+)/);
            return match ? decodeURIComponent(match[1].slice(1)).replace(/[._-]+/g, ' ') : '';
          };

          const add = (card, fallbackLink) => {
            const links = Array.from((card && card.querySelectorAll) ? card.querySelectorAll('a[href]') : []);
            const link = links.find(candidate => channelPattern.test(candidate.getAttribute('href') || '')) || fallbackLink;
            if (!link) return;

            let href = link.href || link.getAttribute('href') || '';
            try { href = new URL(href, location.href).href.split('?')[0]; } catch (_) {}
            if (!channelPattern.test(href) || seen.has(href)) return;

            const nameNode = card && card.querySelector ? card.querySelector([
              '#channel-title',
              '#channel-name',
              'yt-formatted-string#channel-title',
              '#text',
              'h3',
              '[role="heading"]',
              '[aria-label]'
            ].join(',')) : null;
            const name = clean(nameNode ? (nameNode.getAttribute('aria-label') || nameNode.textContent) : link.textContent)
              || handleName(href);
            if (!name || name.length < 2 || name.toLowerCase() === 'subscriptions') return;

            const image = card && card.querySelector ? card.querySelector('img') : null;
            const avatarURL = image ? (image.currentSrc || image.src || image.getAttribute('data-src') || '') : '';
            const isLive = Boolean(card && card.querySelector && card.querySelector('[aria-label*="live" i], .badge-shape-wiz__text'));
            seen.add(href);
            items.push({ id: href, name, avatarURL, channelURL: href, isLive });
          };

          const cards = Array.from(document.querySelectorAll([
            'ytd-channel-renderer',
            'ytd-grid-channel-renderer',
            'ytd-guide-entry-renderer',
            'ytd-channel-list-sub-menu-renderer a[href]',
            'ytd-guide-collapsible-section-entry-renderer',
            'ytd-mini-guide-entry-renderer'
          ].join(',')));
          for (const card of cards) add(card, card.matches && card.matches('a[href]') ? card : null);

          if (items.length < limit) {
            const rail = document.querySelector([
              '#guide-content',
              '#guide-inner-content',
              'ytd-guide-renderer',
              'ytd-multi-page-menu-renderer'
            ].join(','));
            const links = Array.from(rail ? rail.querySelectorAll('a[href]') : [])
              .filter(link => channelPattern.test(link.getAttribute('href') || ''));
            for (const link of links) add(link.parentElement || link, link);
          }

          return JSON.stringify({ items: items.slice(0, limit) });
        })();
        """

        do {
            let result = try await webView.evaluateJavaScript(script)
            guard let json = result as? String,
                  let data = json.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(SubscriptionPayload.self, from: data) else {
                return []
            }

            return payload.items.map { item in
                SubscriptionItem(
                    id: item.id,
                    name: item.name,
                    avatarURL: URL(string: item.avatarURL),
                    channelURL: URL(string: item.channelURL),
                    isLive: item.isLive
                )
            }
        } catch {
            return []
        }
    }

    private func finish(_ subscriptions: [SubscriptionItem]) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: subscriptions)
    }
}

private struct SubscriptionPayload: Decodable {
    let items: [SubscriptionPayloadItem]
}

private struct SubscriptionPayloadItem: Decodable {
    let id: String
    let name: String
    let avatarURL: String
    let channelURL: String
    let isLive: Bool
}
