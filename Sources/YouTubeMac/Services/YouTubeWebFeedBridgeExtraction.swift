import AppKit
import Foundation
import OSLog
@preconcurrency import WebKit

extension YouTubeWebFeedBridge {
    func extractVideosWithRetries(from webView: WKWebView, generation: Int) async {
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

    func mergeSnapshotVideos(_ existing: [VideoItem], with incoming: [VideoItem]) -> [VideoItem] {
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

    func shouldPrefer(_ candidate: VideoItem, over current: VideoItem) -> Bool {
        if current.imageURL == nil && candidate.imageURL != nil { return true }
        if current.channel == "YouTube" && candidate.channel != "YouTube" { return true }
        if current.views == "Recommended" && candidate.views != "Recommended" { return true }
        return current.age.isEmpty && !candidate.age.isEmpty
    }
}
