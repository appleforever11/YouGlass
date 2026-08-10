import AppKit
import Foundation
import OSLog
import WebKit

@MainActor
final class YouTubeChannelBridge: NSObject, WKNavigationDelegate {
    static let shared = YouTubeChannelBridge()

    private let logger = Logger(subsystem: "com.kevinhowe.YouGlass", category: "YouTubeChannel")
    private var webView: WKWebView?
    private var hostWindow: NSWindow?
    private var continuation: CheckedContinuation<YouTubeChannelPage?, Never>?
    private var subscription: SubscriptionItem?
    private var maxResults = 30

    func loadChannel(_ subscription: SubscriptionItem, maxResults: Int = 30) async -> YouTubeChannelPage? {
        guard continuation == nil else { return nil }
        self.subscription = subscription
        self.maxResults = max(8, min(maxResults, 40))
        let requestedURL = subscription.channelURL?.absoluteString ?? "missing URL"
        logger.info("Loading native channel \(subscription.name, privacy: .public) at \(requestedURL, privacy: .public)")

        let timeout = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 18_000_000_000)
            guard let self, self.continuation != nil else { return }
            self.finish(nil)
        }

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<YouTubeChannelPage?, Never>) in
            self.continuation = continuation
            let webView = self.existingOrCreateWebView()
            webView.stopLoading()
            let baseURL = subscription.channelURL ?? URL(string: "https://www.youtube.com/@\(subscription.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? subscription.name)")
            guard let baseURL else {
                self.finish(nil)
                return
            }
            let channelURL = self.videoListingURL(for: baseURL)
            webView.load(URLRequest(url: channelURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 25))
        }
        timeout.cancel()
        self.subscription = nil
        return result
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let finishedURL = webView.url?.absoluteString ?? "missing URL"
        logger.info("Native channel navigation finished: \(finishedURL, privacy: .public)")
        Task { @MainActor [weak self, weak webView] in
            guard let self, let webView else { return }
            await self.extractWithRetries(from: webView)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        logger.error("Native channel navigation failed: \(error.localizedDescription, privacy: .public)")
        finish(nil)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        logger.error("Native channel provisional navigation failed: \(error.localizedDescription, privacy: .public)")
        finish(nil)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        finish(nil)
    }

    private func existingOrCreateWebView() -> WKWebView {
        if let webView { return webView }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.mediaTypesRequiringUserActionForPlayback = [.audio, .video]

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1440, height: 1800), configuration: configuration)
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

    private func videoListingURL(for url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !path.isEmpty, !path.hasSuffix("/videos") else {
            return url
        }
        components.path = "/" + path + "/videos"
        return components.url ?? url
    }

    private func extractWithRetries(from webView: WKWebView) async {
        var lastResult: ChannelBridgePayload?
        for attempt in 0..<12 {
            try? await Task.sleep(nanoseconds: attempt == 0 ? 1_000_000_000 : 700_000_000)
            if attempt == 2 || attempt == 5 || attempt == 8 {
                _ = try? await webView.evaluateJavaScript("window.scrollTo(0, Math.max(document.documentElement.scrollHeight * 0.55, 900)); void 0;")
            }

            guard let result = await extract(from: webView) else { continue }
            logger.info("Native channel extraction attempt \(attempt) found \(result.videos.count) videos for \(result.name, privacy: .public)")
            lastResult = result
            let targetCount = min(maxResults, 12)
            if result.videos.count >= targetCount || attempt >= 4 {
                finish(makePage(from: result))
                return
            }
        }
        if let lastResult {
            finish(makePage(from: lastResult))
            return
        }
        finish(nil)
    }

    private func extract(from webView: WKWebView) async -> ChannelBridgePayload? {
        let script = """
        (() => { try {
          const limit = \(maxResults);
          const clean = value => String(value || '').replace(/\\s+/g, ' ').trim();
          const text = node => clean(node ? (node.getAttribute('aria-label') || node.getAttribute('title') || node.textContent) : '');
          const textValue = value => {
            if (!value) return '';
            if (typeof value === 'string') return clean(value);
            if (value.simpleText) return clean(value.simpleText);
            if (Array.isArray(value.runs)) return clean(value.runs.map(run => run.text || '').join(''));
            if (value.accessibilityData && value.accessibilityData.label) return clean(value.accessibilityData.label);
            return '';
          };
          const thumbnail = value => {
            const thumbnails = value && value.thumbnails;
            return Array.isArray(thumbnails) && thumbnails.length ? (thumbnails[thumbnails.length - 1].url || '') : '';
          };
          const image = root => {
            const img = root && root.querySelector ? root.querySelector('img') : null;
            return img ? (img.currentSrc || img.src || '') : '';
          };
          const videoID = href => {
            try {
              const url = new URL(href, location.href);
              const watchID = url.searchParams.get('v');
              if (watchID && /^[A-Za-z0-9_-]{11}$/.test(watchID)) return watchID;
              const match = url.pathname.match(/\\/(?:shorts|live|embed)\\/([A-Za-z0-9_-]{11})/);
              return match ? match[1] : '';
            } catch (_) { return ''; }
          };
          const first = (root, selectors) => {
            for (const selector of selectors) {
              const node = root && root.querySelector ? root.querySelector(selector) : document.querySelector(selector);
              if (node) return node;
            }
            return null;
          };

          const path = location.pathname.split('/').filter(Boolean)[0] || '';
          const handle = path.startsWith('@') ? path : '';
          const initial = window.ytInitialData || window['ytInitialData'] || {};
          const header = (initial.header && (initial.header.c4TabbedHeaderRenderer || initial.header.pageHeaderViewModel)) || {};
          const metadata = (initial.metadata && initial.metadata.channelMetadataRenderer) || {};
          const nameNode = first(document, ['#channel-name', 'yt-page-header-view-model h1', 'yt-page-header-renderer h1', '#channel-header h1', 'h1']);
          const initialName = textValue(header.title) || textValue(metadata.title);
          const documentName = clean((document.title || '').replace(/\\s*-\\s*YouTube\\s*$/i, ''));
          const name = text(nameNode) || initialName || (handle ? handle.slice(1) : '') || documentName;
          if (!name || name.toLowerCase() === 'youtube') return null;

          const headerText = clean(document.body ? document.body.innerText : '');
          const subscriberLabel = textValue(header.subscriberCountText);
          const videoCountLabel = textValue(header.videosCountText);
          const subscriberMatch = (headerText + ' ' + subscriberLabel).match(/([0-9.,]+\\s*[KMB]?)\\s+subscribers/i);
          const videoCountMatch = (headerText + ' ' + videoCountLabel).match(/([0-9.,]+\\s*[KMB]?)\\s+videos/i);
          const descriptionNode = first(document, ['#description', '#channel-description', 'yt-about-this-channel-renderer #description']);
          const avatarNode = first(document, ['#avatar img', '#channel-header-container img', 'yt-page-header-view-model img']);
          const bannerNode = first(document, ['#channel-banner img', '#channel-header-container yt-img-shadow img', 'yt-page-header-view-model #background img']);
          const initialDescription = textValue(metadata.description) || textValue(header.description);
          const videos = [];
          const seen = new Set();
          const normalizeVideoID = value => {
            const raw = String(value || '');
            if (/^[A-Za-z0-9_-]{11}$/.test(raw)) return raw;
            return videoID(raw);
          };
          const addRenderer = renderer => {
            if (!renderer || typeof renderer !== 'object' || videos.length >= limit) return;
            const endpoint = renderer.navigationEndpoint && renderer.navigationEndpoint.watchEndpoint;
            const id = normalizeVideoID(renderer.videoId || (endpoint && endpoint.videoId));
            if (!id || seen.has(id)) return;
            const title = textValue(renderer.title) || textValue(renderer.headline) || textValue(renderer.accessibility);
            if (!title) return;
            const badges = textValue(renderer.badges) + ' ' + textValue(renderer.thumbnailOverlays);
            seen.add(id);
            videos.push({
              id,
              title,
              channel: textValue(renderer.ownerText) || textValue(renderer.shortBylineText) || name,
              views: textValue(renderer.viewCountText) || textValue(renderer.shortViewCountText) || 'YouTube',
              age: textValue(renderer.publishedTimeText),
              duration: textValue(renderer.lengthText),
              imageURL: thumbnail(renderer.thumbnail),
              isShort: title.toLowerCase().includes('#shorts'),
              isLive: badges.toLowerCase().includes('live')
            });
          };
          const walk = (node, depth) => {
            if (!node || typeof node !== 'object' || depth > 32 || videos.length >= limit) return;
            if (node.videoRenderer) addRenderer(node.videoRenderer);
            if (node.gridVideoRenderer) addRenderer(node.gridVideoRenderer);
            if (node.richItemRenderer && node.richItemRenderer.content) walk(node.richItemRenderer.content, depth + 1);
            if (node.reelItemRenderer) addRenderer(node.reelItemRenderer);
            for (const key of Object.keys(node)) {
              if (key === 'playerResponse' || key === 'responseContext') continue;
              const value = node[key];
              if (value && typeof value === 'object') walk(value, depth + 1);
            }
          };
          walk(initial, 0);
          const cards = Array.from(document.querySelectorAll([
            'ytd-rich-item-renderer',
            'ytd-grid-video-renderer',
            'ytd-video-renderer',
            'ytd-rich-grid-media',
            'yt-lockup-view-model'
          ].join(',')));
          for (const card of cards) {
            if (videos.length >= limit) break;
            const anchors = Array.from(card.querySelectorAll('a[href]'));
              const anchor = anchors.find(link => videoID(link.href));
              const id = anchor ? videoID(anchor.href) : '';
              if (!id || seen.has(id)) continue;
              const titleNode = first(card, ['#video-title', 'a#video-title-link', 'h3', '[role="heading"]', 'a[title]']);
              const metadata = Array.from(card.querySelectorAll('#metadata-line span, .metadata-line span, .yt-content-metadata-view-model__metadata-text')).map(text).filter(Boolean);
              const durationNode = first(card, ['ytd-thumbnail-overlay-time-status-renderer', '[aria-label*="minute"]', '[aria-label*="second"]']);
              const title = text(titleNode);
              if (!title) continue;
              const href = anchor.href || '';
              const isShort = href.includes('/shorts/') || clean(card.innerText).toLowerCase().includes('shorts');
              const isLive = clean(card.innerText).toLowerCase().includes('live') || href.includes('/live/');
              seen.add(id);
              videos.push({ id, title, channel: name, views: metadata[0] || 'YouTube', age: metadata[1] || '', duration: text(durationNode), imageURL: image(card), isShort, isLive });
          }
          return JSON.stringify({
            channelID: (location.pathname.match(/\\/channel\\/(UC[A-Za-z0-9_-]+)/) || [])[1] || header.channelId || metadata.externalId || '',
            name,
            handle,
            description: text(descriptionNode) || initialDescription,
            avatarURL: image(avatarNode && avatarNode.parentElement ? avatarNode.parentElement : avatarNode) || thumbnail(header.avatar) || thumbnail(metadata.avatar),
            bannerURL: image(bannerNode && bannerNode.parentElement ? bannerNode.parentElement : bannerNode) || thumbnail(header.banner),
            subscriberCount: subscriberMatch ? subscriberMatch[1] + ' subscribers' : 'Subscribers unavailable',
            videoCount: videoCountMatch ? videoCountMatch[1] + ' videos' : 'Videos unavailable',
            videos
          });
          } catch (error) {
            return JSON.stringify({
              __channelError: String(error && error.message ? error.message : error),
              __channelStack: String(error && error.stack ? error.stack : '')
            });
          }
        })();
        """

        do {
            let value = try await webView.evaluateJavaScript(script)
            guard let json = value as? String, let data = json.data(using: .utf8) else {
                let extractionURL = webView.url?.absoluteString ?? "missing URL"
                logger.error("Native channel extraction returned no JSON at \(extractionURL, privacy: .public)")
                return nil
            }
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = object["__channelError"] as? String {
                let stack = object["__channelStack"] as? String ?? ""
                logger.error("Native channel extraction JavaScript exception: \(message, privacy: .public) \(stack, privacy: .public)")
                return nil
            }
            return try JSONDecoder().decode(ChannelBridgePayload.self, from: data)
        } catch {
            logger.error("Native channel extraction JavaScript failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func makePage(from payload: ChannelBridgePayload) -> YouTubeChannelPage {
        let items = payload.videos.map {
            VideoItem(
                id: $0.id,
                title: $0.title,
                channel: $0.channel,
                views: $0.views,
                age: $0.age,
                duration: $0.duration,
                imageURL: URL(string: $0.imageURL),
                verified: false
            )
        }
        let shortsIDs = Set(payload.videos.filter(\.isShort).map(\.id))
        let liveIDs = Set(payload.videos.filter(\.isLive).map(\.id))
        let channel = YouTubeChannel(
            id: payload.channelID.isEmpty ? (subscription?.id ?? "channel") : payload.channelID,
            name: payload.name,
            handle: payload.handle.isEmpty ? (subscription?.name ?? "YouTube") : payload.handle,
            description: payload.description,
            avatarURL: URL(string: payload.avatarURL),
            bannerURL: URL(string: payload.bannerURL),
            subscriberCount: payload.subscriberCount,
            videoCount: payload.videoCount,
            isSubscribed: true
        )
        return YouTubeChannelPage(
            channel: channel,
            videos: items,
            shorts: items.filter { shortsIDs.contains($0.id) },
            live: items.filter { liveIDs.contains($0.id) }
        )
    }

    private func finish(_ page: YouTubeChannelPage?) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: page)
    }
}

private struct ChannelBridgePayload: Decodable {
    let channelID: String
    let name: String
    let handle: String
    let description: String
    let avatarURL: String
    let bannerURL: String
    let subscriberCount: String
    let videoCount: String
    let videos: [ChannelBridgeVideo]
}

private struct ChannelBridgeVideo: Decodable {
    let id: String
    let title: String
    let channel: String
    let views: String
    let age: String
    let duration: String
    let imageURL: String
    let isShort: Bool
    let isLive: Bool
}
