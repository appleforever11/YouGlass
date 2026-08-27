import Foundation

extension YouTubeCommentsBridge {
    func load(videoID: String, maxResults: Int = 50, offset: Int = 0) async -> CommentPage {
        guard YouGlassHiddenWebKitPolicy.isEnabled() else {
            YouGlassDiagnostics.record(
                .notice,
                category: "webkit",
                message: "Hidden WebKit comments bridge skipped by stability policy",
                metadata: ["videoID": videoID]
            )
            return CommentPage(
                comments: [],
                totalCount: 0,
                isAvailable: false,
                message: "Signed-in web-session comments are disabled for stability. Connect the YouTube Data API to load comments."
            )
        }

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
    static func isValidVideoID(_ value: String) -> Bool {
        value.count == 11 && value.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
    }
}
