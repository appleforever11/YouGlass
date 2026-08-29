import AppKit
import Foundation
import OSLog
@preconcurrency import WebKit

extension YouTubeWebFeedBridge {
    nonisolated static func extractionScript(maxResults: Int) -> String {
        """
        (() => {
          const limit = \(maxResults);
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
          const isShortsRoute = value => String(value || '').toLowerCase().includes('/shorts/');
          const add = (entry) => {
            if (!entry || entry.isShort || !entry.id || seen.has(entry.id)) return;
            const title = String(entry.title || '').replace(/\\s+/g, ' ').trim();
            if (!title || title.length < 2) return;
            const titleLower = title.toLowerCase();
            if (titleLower.includes('#short') || titleLower.includes('youtube shorts') || titleLower.includes('short form')) return;
            seen.add(entry.id);
            items.push({
              id: entry.id,
              title,
              channel: String(entry.channel || 'YouTube').replace(/\\s+/g, ' ').trim(),
              views: String(entry.views || 'Recommended').replace(/\\s+/g, ' ').trim(),
              age: String(entry.age || '').replace(/\\s+/g, ' ').trim(),
              duration: String(entry.duration || '').replace(/\\s+/g, ' ').trim(),
              imageURL: entry.imageURL || ''
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
            const route = renderer.navigationEndpoint && renderer.navigationEndpoint.commandMetadata
              && renderer.navigationEndpoint.commandMetadata.webCommandMetadata
              && renderer.navigationEndpoint.commandMetadata.webCommandMetadata.url;
            add({ id, title, channel, views, age, duration, imageURL: thumbnail(renderer.thumbnail), isShort: isShort || isShortsRoute(route) });
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
            let id = '';
            for (const candidate of anchors) {
              id = normalizeId(candidate.href);
              if (id) break;
            }
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
    }

    func extractVideos(from webView: WKWebView) async -> YouTubeWebFeedResult {
        let script = Self.extractionScript(maxResults: maxResults)

        do {
            let result = try await webView.youGlassEvaluateJavaScript(script)
            guard let json = result,
                  let payload = Self.decodePayload(from: json) else {
                return .empty
            }

            let videos = Self.videoItems(from: payload)
            let diagnostics = "\(videos.count) cards; server data \(payload.initialCount), DOM cards \(payload.domCount)"
            logger.info("\(self.requestLabel, privacy: .public) extraction: \(diagnostics, privacy: .public); signed in: \(payload.signedIn, privacy: .public)")
            return YouTubeWebFeedResult(videos: videos, isSignedIn: payload.signedIn, diagnostics: diagnostics)
        } catch {
            logger.error("\(self.requestLabel, privacy: .public) extraction failed: \(error.localizedDescription, privacy: .public)")
            return .empty
        }
    }

    nonisolated static func decodePayload(from json: String) -> WebFeedPayload? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WebFeedPayload.self, from: data)
    }

    nonisolated static func videoItems(from payload: WebFeedPayload) -> [VideoItem] {
        payload.items.compactMap { entry in
            let video = VideoItem(
                id: entry.id,
                title: entry.title,
                channel: entry.channel.isEmpty ? "YouTube" : entry.channel,
                views: entry.views.isEmpty ? "Recommended" : entry.views,
                age: entry.age,
                duration: entry.duration,
                imageURL: URL(string: entry.imageURL),
                verified: false
            )
            return YouGlassContentPolicy.allows(video) ? video : nil
        }
    }
}
