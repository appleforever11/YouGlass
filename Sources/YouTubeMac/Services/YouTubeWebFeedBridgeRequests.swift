import AppKit
import Foundation
import OSLog
@preconcurrency import WebKit

extension YouTubeWebFeedBridge {
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

    func loadVideos(
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

    func waitUntilAvailable() async {
        while requestActive {
            await withCheckedContinuation { waiter in
                requestWaiters.append(waiter)
            }
        }
    }
}
