import AppKit
import Foundation
import OSLog
@preconcurrency import WebKit

struct YouTubeWebFeedResult {
    let videos: [VideoItem]
    let isSignedIn: Bool
    let diagnostics: String

    static let empty = YouTubeWebFeedResult(
        videos: [],
        isSignedIn: false,
        diagnostics: "No YouTube video cards were available"
    )
}

@MainActor
final class YouTubeWebFeedBridge: NSObject, WKNavigationDelegate {
    static let shared = YouTubeWebFeedBridge()

    private let logger = Logger(subsystem: "com.kevinhowe.YouGlass", category: "YouTubeWebFeed")
    private var webView: WKWebView?
    private var hostWindow: NSWindow?
    private var continuation: CheckedContinuation<YouTubeWebFeedResult, Never>?
    private var extractionTask: Task<Void, Never>?
    private var activeNavigation: WKNavigation?
    private var requestGeneration = 0
    private var requestActive = false
    private var requestWaiters: [CheckedContinuation<Void, Never>] = []
    private var maxResults = 20
    private var sessionCookiePresent = false
    private var requestLabel = "YouTube homepage"
    private var includeShorts = false

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

    func loadHomeVideos(maxResults: Int = 20) async -> YouTubeWebFeedResult {
        var components = URLComponents(string: "https://www.youtube.com/")!
        components.queryItems = [
            URLQueryItem(name: "youglass_refresh", value: UUID().uuidString)
        ]

        return await loadVideos(
            at: components.url!,
            maxResults: maxResults,
            label: "YouTube homepage",
            includeShorts: false
        )
    }

    func loadHistoryVideos(maxResults: Int = 100) async -> YouTubeWebFeedResult {
        var components = URLComponents(string: "https://www.youtube.com/feed/history")!
        components.queryItems = [
            URLQueryItem(name: "youglass_refresh", value: UUID().uuidString)
        ]

        return await loadVideos(
            at: components.url!,
            maxResults: maxResults,
            label: "YouTube watch history",
            includeShorts: true
        )
    }

    func searchVideos(query: String, maxResults: Int = 12) async -> YouTubeWebFeedResult {
        let searchTerm = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchTerm.isEmpty else { return .empty }

        var components = URLComponents(string: "https://www.youtube.com/results")!
        components.queryItems = [URLQueryItem(name: "search_query", value: searchTerm)]
        guard let url = components.url else { return .empty }

        return await loadVideos(
            at: url,
            maxResults: maxResults,
            label: "YouTube search",
            includeShorts: false
        )
    }

    private func loadVideos(
        at url: URL,
        maxResults: Int,
        label: String,
        includeShorts: Bool
    ) async -> YouTubeWebFeedResult {
        guard YouGlassHiddenWebKitPolicy.isEnabled() else {
            YouGlassDiagnostics.record(
                .notice,
                category: "webkit",
                message: "Hidden WebKit feed bridge skipped by stability policy",
                metadata: ["request": label]
            )
            return .empty
        }

        await waitUntilAvailable()
        await YouGlassHiddenWebKitCoordinator.shared.acquire("home-feed")
        defer { YouGlassHiddenWebKitCoordinator.shared.release("home-feed") }

        requestGeneration &+= 1
        let generation = requestGeneration
        requestActive = true

        self.maxResults = maxResults
        requestLabel = label
        self.includeShorts = includeShorts
        let cookieSession = await hasYouTubeSessionCookie()
        sessionCookiePresent = cookieSession
        let webView = existingOrCreateWebView()
        extractionTask?.cancel()
        logger.info("Loading \(label, privacy: .public); session cookie present: \(cookieSession, privacy: .public)")

        let request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 25
        )

        let timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 18_000_000_000)
            guard let self,
                  self.continuation != nil,
                  self.requestGeneration == generation else { return }
            self.finish(YouTubeWebFeedResult(
                videos: [],
                isSignedIn: cookieSession,
                diagnostics: "\(label) timed out before cards were rendered"
            ), generation: generation)
        }

        let result = await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.activeNavigation = webView.load(request)
        }
        timeoutTask.cancel()
        return result
    }

    private func waitUntilAvailable() async {
        while requestActive {
            await withCheckedContinuation { waiter in
                requestWaiters.append(waiter)
            }
        }
    }

    private func existingOrCreateWebView() -> WKWebView {
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

    private func hasYouTubeSessionCookie() async -> Bool {
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

    private func extractVideosWithRetries(from webView: WKWebView, generation: Int) async {
        var bestResult = YouTubeWebFeedResult.empty

        for attempt in 0..<12 {
            guard generation == requestGeneration, continuation != nil else { return }
            try? await Task.sleep(nanoseconds: attempt == 0 ? 1_200_000_000 : 850_000_000)
            guard generation == requestGeneration, continuation != nil else { return }

            if attempt == 2 || attempt == 5 || attempt == 8 {
                _ = try? await webView.youGlassEvaluateJavaScript(
                    "window.scrollTo(0, Math.max(document.documentElement.scrollHeight * 0.55, 900)); void 0;"
                )
            }
            if attempt == 10 {
                _ = try? await webView.youGlassEvaluateJavaScript("window.scrollTo(0, 0); void 0;")
            }

            let result = await extractVideos(from: webView)
            let sessionResult = YouTubeWebFeedResult(
                videos: result.videos,
                isSignedIn: result.isSignedIn || sessionCookiePresent,
                diagnostics: result.diagnostics
            )

            // The homepage hydrates incrementally. Merge snapshots instead of
            // keeping only the largest one: a later pass often adds the real
            // thumbnail and channel metadata to cards already discovered.
            let mergedVideos = mergeSnapshotVideos(bestResult.videos, with: sessionResult.videos)
            if !mergedVideos.isEmpty || sessionResult.isSignedIn || bestResult.isSignedIn {
                bestResult = YouTubeWebFeedResult(
                    videos: Array(mergedVideos.prefix(maxResults)),
                    isSignedIn: bestResult.isSignedIn || sessionResult.isSignedIn,
                    diagnostics: sessionResult.diagnostics
                )
            }

            if bestResult.videos.count >= maxResults {
                finish(bestResult, generation: generation)
                return
            }
        }

        if !bestResult.videos.isEmpty {
            finish(bestResult, generation: generation)
            return
        }

        let liveSession = await hasYouTubeSessionCookie()
        let currentSession = sessionCookiePresent || liveSession
        finish(YouTubeWebFeedResult(
            videos: [],
            isSignedIn: currentSession,
            diagnostics: "\(requestLabel) loaded, but no video cards were exposed"
        ), generation: generation)
    }

    private func mergeSnapshotVideos(_ existing: [VideoItem], with incoming: [VideoItem]) -> [VideoItem] {
        var merged = existing

        for candidate in incoming {
            guard let index = merged.firstIndex(where: { $0.id == candidate.id }) else {
                merged.append(candidate)
                continue
            }

            let current = merged[index]
            if shouldPrefer(candidate, over: current) {
                merged[index] = candidate
            }
        }

        return merged
    }

    private func shouldPrefer(_ candidate: VideoItem, over current: VideoItem) -> Bool {
        if current.imageURL == nil && candidate.imageURL != nil { return true }
        if current.channel == "YouTube" && candidate.channel != "YouTube" { return true }
        if current.views == "Recommended" && candidate.views != "Recommended" { return true }
        return current.age.isEmpty && !candidate.age.isEmpty
    }

    private func extractVideos(from webView: WKWebView) async -> YouTubeWebFeedResult {
        let script = """
        (() => {
          const limit = \(maxResults);
          const includeShorts = \(includeShorts ? "true" : "false");
          const seen = new Set();
          const items = [];
          let initialCount = 0;
          let domCount = 0;

          const text = (value) => {
            if (!value) return '';
            if (typeof value === 'string') return value.trim();
            if (value.simpleText) return String(value.simpleText).trim();
            if (Array.isArray(value.runs)) return value.runs.map(run => run.text || '').join('').trim();
            if (value.accessibilityData && value.accessibilityData.label) return String(value.accessibilityData.label).trim();
            return '';
          };
          const firstText = (object, keys) => {
            for (const key of keys) {
              const value = text(object && object[key]);
              if (value) return value;
            }
            return '';
          };
          const thumbnail = (object) => {
            const thumbnails = object && object.thumbnails;
            return Array.isArray(thumbnails) && thumbnails.length ? thumbnails[thumbnails.length - 1].url || '' : '';
          };
          const normalizeId = (value) => {
            try {
              const url = new URL(String(value || ''), location.href);
              const watchId = url.searchParams.get('v');
              if (watchId && /^[A-Za-z0-9_-]{11}$/.test(watchId)) return watchId;
              const match = url.pathname.match(/\\/(?:shorts|live|embed)\\/([A-Za-z0-9_-]{11})/);
              return match ? match[1] : '';
            } catch (_) { return ''; }
          };
          const add = (entry) => {
            if (!entry || (!includeShorts && entry.isShort) || !entry.id || seen.has(entry.id)) return;
            const title = String(entry.title || '').replace(/\\s+/g, ' ').trim();
            if (!title || title.length < 2) return;
            const titleLower = title.toLowerCase();
            if (!includeShorts && (titleLower.includes('#short') || titleLower.includes('youtube shorts') || titleLower.includes('short form'))) return;
            seen.add(entry.id);
            items.push({
              id: entry.id,
              title,
              channel: String(entry.channel || 'YouTube').replace(/\\s+/g, ' ').trim(),
              views: String(entry.views || 'Recommended').replace(/\\s+/g, ' ').trim(),
              age: String(entry.age || '').replace(/\\s+/g, ' ').trim(),
              duration: String(entry.duration || '').replace(/\\s+/g, ' ').trim(),
              imageURL: entry.imageURL || '',
              isShort: Boolean(entry.isShort)
            });
          };
          const addRenderer = (renderer, isShort = false) => {
            if (!renderer || typeof renderer !== 'object') return;
            const id = normalizeId(renderer.videoId || (renderer.navigationEndpoint && renderer.navigationEndpoint.watchEndpoint && 'https://www.youtube.com/watch?v=' + renderer.navigationEndpoint.watchEndpoint.videoId));
            if (!id) return;
            const title = firstText(renderer, ['title', 'headline', 'accessibility']);
            const channel = firstText(renderer, ['ownerText', 'shortBylineText', 'longBylineText', 'subtitle']);
            const views = firstText(renderer, ['viewCountText', 'shortViewCountText']);
            const age = firstText(renderer, ['publishedTimeText']);
            const duration = firstText(renderer, ['lengthText']);
            add({ id, title, channel, views, age, duration, imageURL: thumbnail(renderer.thumbnail), isShort });
          };
          const walk = (node, depth) => {
            if (!node || typeof node !== 'object' || depth > 32 || items.length >= limit * 3) return;
            if (node.videoRenderer) { initialCount += 1; addRenderer(node.videoRenderer); }
            if (node.compactVideoRenderer) { initialCount += 1; addRenderer(node.compactVideoRenderer); }
            if (node.gridVideoRenderer) { initialCount += 1; addRenderer(node.gridVideoRenderer); }
            if (node.richItemRenderer && node.richItemRenderer.content) walk(node.richItemRenderer.content, depth + 1);
            if (node.reelItemRenderer) {
              initialCount += 1;
              addRenderer(node.reelItemRenderer, true);
            }
            for (const key of Object.keys(node)) {
              if (key === 'playerResponse' || key === 'responseContext') continue;
              const value = node[key];
              if (value && typeof value === 'object') walk(value, depth + 1);
            }
          };

          const initial = window.ytInitialData || window['ytInitialData'];
          if (initial) walk(initial, 0);

          const cards = Array.from(document.querySelectorAll([
            'ytd-rich-item-renderer',
            'ytd-rich-grid-media',
            'ytd-rich-grid-slim-media',
            'ytd-video-renderer',
            'ytd-compact-video-renderer',
            'ytd-reel-item-renderer',
            'yt-lockup-view-model'
          ].join(',')));
          domCount = cards.length;
          for (const card of cards) {
            const anchors = Array.from(card.querySelectorAll('a[href]'));
            const anchor = anchors.find(candidate => normalizeId(candidate.href));
            const id = anchor ? normalizeId(anchor.href) : '';
            if (!id) continue;
            const isShortCard = card.matches('ytd-reel-item-renderer')
              || anchors.some(candidate => /\\/shorts\\//i.test(candidate.href));
            const titleNode = card.querySelector([
              '#video-title',
              'a#video-title-link',
              'a[title]',
              '[role="heading"]',
              'h3',
              '.yt-lockup-metadata-view-model__heading-reset',
              'yt-formatted-string#video-title'
            ].join(','));
            const title = titleNode ? (titleNode.getAttribute('title') || titleNode.textContent || '') : '';
            const channelNode = card.querySelector([
              'ytd-channel-name a',
              '#channel-name a',
              'a[href*="/@"]',
              '.yt-content-metadata-view-model__metadata-text'
            ].join(','));
            const metadata = Array.from(card.querySelectorAll('#metadata-line span, .metadata-line span, .yt-content-metadata-view-model__metadata-text'))
              .map(node => (node.textContent || '').trim()).filter(Boolean);
            const image = card.querySelector('img');
            const srcset = image ? (image.getAttribute('srcset') || '') : '';
            const srcsetURL = srcset.split(',')[0].trim().split(' ')[0] || '';
            const durationNode = card.querySelector('ytd-thumbnail-overlay-time-status-renderer span, .badge-shape-wiz__text');
            add({
              id,
              title,
              channel: channelNode ? channelNode.textContent : 'YouTube',
              views: metadata[0] || 'Recommended',
              age: metadata[1] || '',
              duration: durationNode ? durationNode.textContent : '',
              imageURL: image ? (
                image.currentSrc || image.src || image.getAttribute('data-src') ||
                image.getAttribute('data-thumb') || image.getAttribute('data-original') ||
                srcsetURL
              ) : '',
              isShort: isShortCard
            });
          }

          const signedIn = Boolean(document.querySelector([
            '#avatar-btn',
            'button#avatar-btn',
            'ytd-topbar-menu-button-renderer',
            'a[href*="/channel/"] img[src*="googleusercontent.com"]',
            'img[src*="googleusercontent.com"]'
          ].join(',')));
          return JSON.stringify({
            items: items.slice(0, limit),
            signedIn,
            title: document.title || '',
            url: location.href,
            initialCount,
            domCount
          });
        })();
        """

        do {
            let result = try await webView.youGlassEvaluateJavaScript(script)
            guard let json = result,
                  let data = json.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(WebFeedPayload.self, from: data) else {
                return .empty
            }

            let videos = payload.items.map { entry in
                VideoItem(
                    id: entry.id,
                    title: entry.title,
                    channel: entry.channel.isEmpty ? "YouTube" : entry.channel,
                    views: entry.views.isEmpty ? "Recommended" : entry.views,
                    age: entry.age,
                    duration: entry.duration,
                    imageURL: URL(string: entry.imageURL),
                    verified: false
                )
            }
            let diagnostics = "\(videos.count) cards; server data \(payload.initialCount), DOM cards \(payload.domCount)"
            logger.info("\(self.requestLabel, privacy: .public) extraction: \(diagnostics, privacy: .public); signed in: \(payload.signedIn, privacy: .public)")
            return YouTubeWebFeedResult(videos: videos, isSignedIn: payload.signedIn, diagnostics: diagnostics)
        } catch {
            logger.error("\(self.requestLabel, privacy: .public) extraction failed: \(error.localizedDescription, privacy: .public)")
            return .empty
        }
    }

    private func finish(_ result: YouTubeWebFeedResult, generation: Int? = nil) {
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

    private func isCurrentNavigation(_ navigation: WKNavigation?) -> Bool {
        guard let activeNavigation else { return true }
        return navigation == nil || navigation === activeNavigation
    }
}

private struct WebFeedPayload: Decodable {
    let items: [WebFeedEntry]
    let signedIn: Bool
    let title: String
    let url: String
    let initialCount: Int
    let domCount: Int
}

private struct WebFeedEntry: Decodable {
    let id: String
    let title: String
    let channel: String
    let views: String
    let age: String
    let duration: String
    let imageURL: String
}
