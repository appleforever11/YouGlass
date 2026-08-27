import Foundation
@preconcurrency import WebKit

extension YouTubeCommentsBridge {
    func extractCurrentPage() async -> CommentPage {
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
}
