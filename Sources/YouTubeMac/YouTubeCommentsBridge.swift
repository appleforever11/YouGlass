import AppKit
import Foundation
import OSLog
@preconcurrency import WebKit

// The Data API remains the authoritative path when an API key or OAuth token
// is configured. This offscreen bridge makes public comments available from
// the user's existing YouTube web session when those API credentials are not.
@MainActor
final class YouTubeCommentsBridge: NSObject, WKNavigationDelegate, WKUIDelegate {
    static let shared = YouTubeCommentsBridge()

    private let logger = Logger(subsystem: "com.kevinhowe.YouGlass", category: "YouTubeComments")
    private var webView: WKWebView?
    private var hostWindow: NSWindow?
    private var requestedVideoID: String?
    private var loadedVideoID: String?
    private var navigationContinuation: CheckedContinuation<Bool, Never>?
    private var navigationTimeout: Task<Void, Never>?
    private var activeNavigation: WKNavigation?
    private var requestGeneration = 0
    private var maxResults = 24
    private var commentOffset = 0
    private var continuationTokens: [String: [Int: String]] = [:]
    private var activeContinuationToken: String?
    private var extractedNextContinuationToken: String?

    func load(videoID: String, maxResults: Int = 50, offset: Int = 0) async -> CommentPage {
        guard Self.isValidVideoID(videoID) else {
            return CommentPage(
                comments: [],
                totalCount: 0,
                isAvailable: false,
                message: "This video does not have a valid YouTube ID."
            )
        }

        await YouGlassHiddenWebKitCoordinator.shared.acquire("comments")
        defer { YouGlassHiddenWebKitCoordinator.shared.release("comments") }

        requestGeneration &+= 1
        let generation = requestGeneration

        self.maxResults = max(8, min(maxResults, 50))
        self.commentOffset = max(0, offset)
        if loadedVideoID != videoID {
            continuationTokens[videoID] = [:]
            let loaded = await navigate(to: videoID, generation: generation)
            guard loaded else {
                return CommentPage(
                    comments: [],
                    totalCount: 0,
                    isAvailable: false,
                    message: "YouTube comments could not be reached in the signed-in session."
                )
            }
        }
        activeContinuationToken = continuationTokens[videoID]?[self.commentOffset]

        var lastPage = CommentPage(
            comments: [],
            totalCount: 0,
            isAvailable: false,
            message: "Loading comments from your signed-in YouTube session..."
        )

        // Comments are a lazy-loaded section of the watch page. Scroll in
        // stages while retrying so the page has a chance to render them.
        for attempt in 0..<12 {
            if attempt == 1 || attempt == 4 || attempt == 7 {
                _ = try? await webView?.youGlassEvaluateJavaScript(
                    """
                    (() => {
                      const scrolling = document.scrollingElement || document.documentElement;
                      const host = document.querySelector('ytd-comments') || document.querySelector('ytd-comment-thread-renderer');
                      if (host) host.scrollIntoView({ block: 'center', behavior: 'instant' });
                      const target = Math.max(900, \(self.commentOffset + self.maxResults) * 110);
                      const bottom = Math.max(scrolling.scrollHeight, document.body ? document.body.scrollHeight : 0);
                      scrolling.scrollTop = Math.min(bottom, Math.max(scrolling.scrollTop + target, bottom - target));
                      window.scrollTo(0, scrolling.scrollTop);
                      for (const node of Array.from(document.querySelectorAll('*'))) {
                        if (node.scrollHeight > node.clientHeight + 80) node.scrollTop = node.scrollHeight;
                      }
                      const commentsHost = document.querySelector('ytd-comments#comments');
                      const continuation = Array.from(document.querySelectorAll('ytd-continuation-item-renderer'))
                        .find(node => String(node.className || '').includes('ytd-item-section-renderer'))
                        || (commentsHost
                          ? Array.from(commentsHost.querySelectorAll('ytd-continuation-item-renderer'))[0]
                          : document.querySelector('ytd-comments ytd-continuation-item-renderer'));
                      const continuationButton = continuation
                        ? (continuation.querySelector('#button, button') || continuation)
                        : null;
                      if (continuation) {
                        continuation.scrollIntoView({ block: 'center', behavior: 'instant' });
                        continuation.dispatchEvent(new Event('yt-interaction', { bubbles: true }));
                      }
                      if (continuationButton && typeof continuationButton.click === 'function') {
                        continuationButton.click();
                        continuationButton.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
                      }
                      document.dispatchEvent(new Event('scroll', { bubbles: true }));
                      return true;
                    })();
                    """
                )
            }

            let page = await extractCurrentPage()
            lastPage = page
            if let nextToken = extractedNextContinuationToken,
               !nextToken.isEmpty,
               !page.comments.isEmpty {
                continuationTokens[videoID, default: [:]][self.commentOffset + page.comments.count] = nextToken
            }
            // The comments host appears before its first lazy batch. Do not
            // return the two placeholder threads that YouTube often exposes
            // during that window; wait for a useful batch or let the retry
            // ceiling handle videos with only a few public comments.
            let hasUsefulInitialBatch = page.comments.count >= min(self.maxResults, 8)
            let hasSettledContinuation = page.nextPageToken != nil && attempt >= 5
            if page.message == "Comments are disabled for this video."
                || (page.isAvailable && (hasUsefulInitialBatch || hasSettledContinuation))
                || attempt >= 8 {
                return page
            }
            try? await Task.sleep(nanoseconds: 700_000_000)
        }

        return lastPage
    }

    private func navigate(to videoID: String, generation: Int) async -> Bool {
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

    private func existingOrCreateWebView() -> WKWebView {
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

    private func finishNavigation(_ succeeded: Bool, generation: Int? = nil) {
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

    private func isCurrentNavigation(_ navigation: WKNavigation?) -> Bool {
        guard let activeNavigation else { return true }
        return navigation == nil || navigation === activeNavigation
    }

    private func extractCurrentPage() async -> CommentPage {
        guard let webView else {
            return CommentPage(comments: [], totalCount: 0, isAvailable: false, message: "Comments are unavailable.")
        }

        extractedNextContinuationToken = nil
        let continuationTokenLiteral: String
        if let data = try? JSONSerialization.data(withJSONObject: activeContinuationToken ?? ""),
           let value = String(data: data, encoding: .utf8) {
            continuationTokenLiteral = value
        } else {
            continuationTokenLiteral = "\"\""
        }

        let script = """
        (() => {
          const limit = \(maxResults);
          const offset = \(commentOffset);
          const requestedContinuationToken = \(continuationTokenLiteral);
          const clean = value => String(value || '').replace(/\\s+/g, ' ').trim();
          const roots = [document];
          for (const frame of Array.from(document.querySelectorAll('iframe'))) {
            try { if (frame.contentDocument) roots.push(frame.contentDocument); } catch (_) {}
          }
          const queryDeep = (root, selector) => {
            const found = [];
            const seen = new Set();
            const walk = current => {
              if (!current || typeof current.querySelectorAll !== 'function') return;
              if (typeof current.matches === 'function' && current.matches(selector) && !seen.has(current)) {
                seen.add(current);
                found.push(current);
              }
              for (const node of Array.from(current.querySelectorAll(selector))) {
                if (!seen.has(node)) {
                  seen.add(node);
                  found.push(node);
                }
              }
              if (current.shadowRoot) walk(current.shadowRoot);
              for (const element of Array.from(current.querySelectorAll('*'))) {
                if (element.shadowRoot) walk(element.shadowRoot);
              }
            };
            walk(root);
            return found;
          };
          const queryAll = selector => roots.flatMap(root => queryDeep(root, selector));
          const queryWithin = (root, selector) => queryDeep(root, selector);
          const text = node => clean(node ? node.textContent : '');
          const image = node => {
            const img = node ? queryWithin(node, 'img')[0] : null;
            return img ? (img.currentSrc || img.src || img.getAttribute('data-src') || '') : '';
          };
          const bodyText = roots.map(root => clean(root.body ? root.body.innerText : '')).join(' ');
          const commentsDisabled = /comments are turned off|comments are disabled|comments have been disabled/i.test(bodyText);
          const channelID = clean(
            window.ytInitialPlayerResponse && window.ytInitialPlayerResponse.videoDetails
              ? window.ytInitialPlayerResponse.videoDetails.channelId
              : ''
          );
          const threadNodes = queryAll('ytd-comment-thread-renderer');
          const valueText = value => {
            if (!value) return '';
            if (typeof value === 'string') return clean(value);
            if (value.simpleText) return clean(value.simpleText);
            if (Array.isArray(value.runs)) return clean(value.runs.map(run => run.text || '').join(''));
            return '';
          };
          const thumbnailURL = value => {
            const thumbnails = value && Array.isArray(value.thumbnails) ? value.thumbnails : [];
            return thumbnails.length > 0 ? (thumbnails[thumbnails.length - 1].url || '') : '';
          };
          const parseContinuationResponse = response => {
            const comments = [];
            const seen = new Set();
            const nextTokens = [];
            const actionLists = [];
            const visitActions = node => {
              if (!node || typeof node !== 'object') return;
              for (const key of ['appendContinuationItemsAction', 'reloadContinuationItemsCommand']) {
                const items = node[key] && node[key].continuationItems;
                if (Array.isArray(items)) actionLists.push(items);
              }
              for (const [key, value] of Object.entries(node)) {
                if (key === 'commentThreadRenderer' || key === 'commentRenderer' || key === 'replies') continue;
                if (value && typeof value === 'object') visitActions(value);
              }
            };
            const appendThread = item => {
              const renderer = item && item.commentThreadRenderer && item.commentThreadRenderer.comment
                ? item.commentThreadRenderer.comment.commentRenderer
                : null;
              if (!renderer) return;
              const id = renderer.commentId || `${valueText(renderer.authorText)}|${valueText(renderer.publishedTimeText)}|${valueText(renderer.contentText)}`;
              if (seen.has(id)) return;
              seen.add(id);
              comments.push({
                id,
                author: valueText(renderer.authorText) || 'YouTube viewer',
                text: valueText(renderer.contentText),
                age: valueText(renderer.publishedTimeText) || 'now',
                likes: valueText(renderer.voteCount),
                avatarURL: thumbnailURL(renderer.authorThumbnail)
              });
            };
            visitActions(response);
            for (const items of actionLists) {
              for (const item of items) {
                appendThread(item);
                const token = item && item.continuationItemRenderer && item.continuationItemRenderer.continuationEndpoint
                  ? item.continuationItemRenderer.continuationEndpoint.continuationCommand?.token
                  : null;
                if (token) nextTokens.push(token);
              }
            }
            return { comments, nextToken: nextTokens.length > 0 ? nextTokens[nextTokens.length - 1] : null };
          };
          let continuationPayload = null;
          if (offset > 0 && requestedContinuationToken) {
            const requestKey = `${offset}:${requestedContinuationToken}`;
            let requestState = window.__youglassCommentContinuation;
            if (!requestState || requestState.key !== requestKey) {
              requestState = { key: requestKey, status: 'loading', data: null, error: null };
              window.__youglassCommentContinuation = requestState;
              const config = window.ytcfg && typeof window.ytcfg.get === 'function'
                ? {
                    apiKey: window.ytcfg.get('INNERTUBE_API_KEY'),
                    context: window.ytcfg.get('INNERTUBE_CONTEXT'),
                    clientName: window.ytcfg.get('INNERTUBE_CONTEXT_CLIENT_NAME'),
                    clientVersion: window.ytcfg.get('INNERTUBE_CONTEXT_CLIENT_VERSION')
                  }
                : (window.ytcfg && window.ytcfg.data_) || {};
              if (!config.apiKey || !config.context) {
                requestState.status = 'error';
                requestState.error = 'YouTube continuation credentials are unavailable.';
              } else {
                const headers = { 'Content-Type': 'application/json' };
                if (config.clientName) headers['X-YouTube-Client-Name'] = String(config.clientName);
                if (config.clientVersion) headers['X-YouTube-Client-Version'] = String(config.clientVersion);
                fetch(`${location.origin}/youtubei/v1/next?key=${encodeURIComponent(config.apiKey)}`, {
                  method: 'POST',
                  credentials: 'include',
                  headers,
                  body: JSON.stringify({ context: config.context, continuation: requestedContinuationToken })
                }).then(async response => ({ ok: response.ok, data: await response.json() }))
                  .then(result => {
                    const current = window.__youglassCommentContinuation;
                    if (!current || current.key !== requestKey) return;
                    if (!result.ok) {
                      current.status = 'error';
                      current.error = 'YouTube did not return the next comments page.';
                    } else {
                      current.status = 'done';
                      current.data = result.data;
                    }
                  })
                  .catch(error => {
                    const current = window.__youglassCommentContinuation;
                    if (!current || current.key !== requestKey) return;
                    current.status = 'error';
                    current.error = String(error && error.message ? error.message : error);
                  });
              }
            }
            requestState = window.__youglassCommentContinuation;
            if (requestState && requestState.status === 'done') {
              continuationPayload = parseContinuationResponse(requestState.data);
            } else {
              return JSON.stringify({
                comments: [],
                totalCount: 0,
                isAvailable: false,
                message: requestState && requestState.error ? requestState.error : 'Loading more comments from the signed-in YouTube session...',
                nextPageToken: `bridge-offset:${offset}`,
                nextContinuationToken: null,
                channelID
              });
            }
          }
          const comments = [];
          const seen = new Set();
          let nextContinuationToken = continuationPayload ? continuationPayload.nextToken : null;
          if (continuationPayload) {
            continuationPayload.comments.forEach(item => {
              if (!item.text || seen.has(item.id)) return;
              seen.add(item.id);
              comments.push(item);
            });
          } else {
            threadNodes.slice(offset, offset + limit).forEach(thread => {
              const node = queryWithin(thread, 'ytd-comment-renderer')[0] || thread;
              const author = text(queryWithin(node, '#author-text, #author-name, #header-author')[0]) || 'YouTube viewer';
              const message = text(queryWithin(node, '#content-text, #content')[0]);
              if (!message) return;
              const publishedAt = text(queryWithin(node, '#published-time-text, #published-time')[0]) || 'now';
              const likes = text(queryWithin(node, '#vote-count-middle, #vote-count')[0]) || '';
              const id = node.getAttribute('data-comment-id') || thread.getAttribute('data-comment-id') || node.id || `${author}|${publishedAt}|${message}`;
              if (seen.has(id)) return;
              seen.add(id);
              comments.push({
                id,
                author,
                text: message,
                age: publishedAt,
                likes,
                avatarURL: image(queryWithin(node, '#author-thumbnail, #author-photo, #author-photo-container')[0])
              });
            });
          }

          const countNode = queryAll('ytd-comments-header-renderer #count, ytd-comments-header-renderer #count .count-text, ytd-comments-header-renderer h2').find(Boolean);
          const countText = text(countNode);
          const countMatch = countText.match(/([0-9][0-9,.]*)(?:\\s*([KMB]))?/i);
          let totalCount = comments.length;
          if (countMatch) {
            const raw = Number(countMatch[1].replace(/,/g, ''));
            const suffix = (countMatch[2] || '').toUpperCase();
            const multiplier = suffix === 'B' ? 1000000000 : suffix === 'M' ? 1000000 : suffix === 'K' ? 1000 : 1;
            if (Number.isFinite(raw)) totalCount = Math.max(comments.length, Math.round(raw * multiplier));
          }

          let status = null;
          if (commentsDisabled) status = 'Comments are disabled for this video.';
          else if (comments.length === 0) status = 'No public comments were returned for this video.';
          // The outer ytd-comments host exists before its lazy content is
          // ready. Treat the header/threads as the loaded surface so the
          // SwiftUI view keeps retrying during that initial render window.
          const commentsSurface = queryAll('ytd-comment-thread-renderer, ytd-comments-header-renderer').length > 0;
          const continuationCount = queryAll('ytd-continuation-item-renderer').length;
          const mainContinuation = queryAll('ytd-continuation-item-renderer')
            .find(node => String(node.className || '').includes('ytd-item-section-renderer')) || null;
          const domContinuationToken = mainContinuation && mainContinuation.data && mainContinuation.data.continuationEndpoint && mainContinuation.data.continuationEndpoint.continuationCommand
            ? mainContinuation.data.continuationEndpoint.continuationCommand.token
            : null;
          if (!nextContinuationToken) nextContinuationToken = domContinuationToken;
          const nextPageToken = (comments.length > 0 || commentsSurface) && nextContinuationToken
            ? `bridge-offset:${offset + comments.length}`
            : null;
          return JSON.stringify({
            comments,
            totalCount,
            isAvailable: !commentsDisabled && (comments.length > 0 || commentsSurface || Boolean(nextContinuationToken)),
            message: status,
            nextPageToken,
            nextContinuationToken,
            channelID
          });
        })();
        """

        do {
            let value = try await webView.youGlassEvaluateJavaScript(script)
            guard let json = value,
                  let data = json.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(CommentBridgePayload.self, from: data) else {
                return CommentPage(comments: [], totalCount: 0, isAvailable: false, message: "Comments are still loading.")
            }

            extractedNextContinuationToken = payload.nextContinuationToken

            logger.info("Comment page offset=\(self.commentOffset) returned=\(payload.comments.count)")

            return CommentPage(
                comments: payload.comments.map { item in
                    VideoComment(
                        id: item.id,
                        author: item.author,
                        text: item.text,
                        age: item.age,
                        likes: item.likes,
                        avatarURL: URL(string: item.avatarURL)
                    )
                },
                totalCount: payload.totalCount,
                isAvailable: payload.isAvailable,
                message: payload.message,
                nextPageToken: payload.nextPageToken,
                channelID: payload.channelID
            )
        } catch {
            logger.error("Comment extraction failed: \(error.localizedDescription, privacy: .public)")
            return CommentPage(comments: [], totalCount: 0, isAvailable: false, message: "Comments are unavailable right now.")
        }
    }

    private static func isValidVideoID(_ value: String) -> Bool {
        value.count == 11 && value.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
    }
}

private struct CommentBridgePayload: Decodable {
    let comments: [CommentBridgeItem]
    let totalCount: Int
    let isAvailable: Bool
    let message: String?
    let nextPageToken: String?
    let nextContinuationToken: String?
    let channelID: String?
}

private struct CommentBridgeItem: Decodable {
    let id: String
    let author: String
    let text: String
    let age: String
    let likes: String
    let avatarURL: String
}
