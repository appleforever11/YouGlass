import AppKit
import Foundation
import SwiftUI

extension YouTubeStore {
        func startSearch(_ term: String? = nil) {
            let generation = beginNavigation()
            selectedSubscriptionGroupID = nil
            subscriptionGroupVideos = []
            sectionLoadTask = Task { @MainActor [weak self] in
                guard let self else { return }
                await self.search(term, sectionGeneration: generation)
                self.finishSearch(generation)
            }
        }

        private func finishSearch(_ generation: Int) {
            sectionRequests.finish(generation)
        }

        func search(_ term: String? = nil, sectionGeneration: Int? = nil) async {
            let searchTerm = (term ?? query).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !searchTerm.isEmpty else { return }
            guard canPublishSectionLoad(sectionGeneration) else { return }

            // Navigate immediately so a slow API or web-session fallback cannot
            // leave the user looking at the previous Home surface.
            query = searchTerm
            searchState.query = searchTerm
            searchState.emptyMessage = nil
            searchState.message = "Searching YouTube…"
            searchState.isLoading = true
            selectedSection = "Search"
            selectedPlaylist = nil
            selectedChannelItem = nil
            channelPage = nil
            sectionEmptyMessage = nil
            searchResults = []
            isLoading = true
            connectionMessage = "Searching YouTube..."
            YouGlassDiagnostics.feed.info("Search started")
            defer {
                if canPublishSectionLoad(sectionGeneration) {
                    isLoading = false
                    searchState.isLoading = false
                }
            }

            if let directVideo = VideoItem.fromYouTubeInput(searchTerm) {
                connectionMessage = "Opening YouTube video in the native player"
                open(directVideo)
                return
            }

            if YouGlassContentPolicy.isShortsURL(searchTerm)
                || YouGlassContentPolicy.isShortsSearch(searchTerm) {
                searchResults = []
                sectionEmptyMessage = "YouTube Shorts are disabled in YouGlass"
                searchState.emptyMessage = sectionEmptyMessage
                connectionMessage = "Short-form YouTube content is excluded"
                return
            }

            if !isNetworkAvailable {
                applyLocalSearch(searchTerm, failure: "You are offline. No matching videos were found in your library or cached feed.")
                return
            }

            let hasCredentials = await searchService.hasCredentials()
            guard canPublishSectionLoad(sectionGeneration) else { return }
            guard hasCredentials else {
                await applySearchFallback(
                    for: searchTerm,
                    apiError: nil,
                    sectionGeneration: sectionGeneration
                )
                return
            }

            do {
                let videos = try await searchService.search(searchTerm)
                guard canPublishSectionLoad(sectionGeneration) else { return }
                if !videos.isEmpty {
                    applySearchResults(videos, message: "Connected to YouTube")
                } else {
                    await applySearchFallback(
                        for: searchTerm,
                        apiError: nil,
                        sectionGeneration: sectionGeneration
                    )
                }
            } catch {
                // Data API search is quota-expensive and can be throttled even
                // when the signed-in YouTube website still works. Reuse the
                // authenticated hidden web session before showing an error.
                await applySearchFallback(
                    for: searchTerm,
                    apiError: error,
                    sectionGeneration: sectionGeneration
                )
            }
        }

        func applySearchResults(_ videos: [VideoItem], message: String) {
            let merged = mergeVideos(videos)
            guard !merged.isEmpty else {
                searchResults = []
                sectionEmptyMessage = "No matching YouTube videos were found."
                searchState.emptyMessage = sectionEmptyMessage
                return
            }
            sectionEmptyMessage = nil
            searchResults = merged
            searchState.emptyMessage = nil
            searchState.message = message
            connectionMessage = message
        }

        func applySearchFallback(
            for searchTerm: String,
            apiError: Error?,
            sectionGeneration: Int? = nil
        ) async {
            guard canPublishSectionLoad(sectionGeneration) else { return }
            let webResult = await searchService.webSearch(searchTerm)
            guard canPublishSectionLoad(sectionGeneration) else { return }
            if !webResult.videos.isEmpty {
                applySearchResults(
                    webResult.videos,
                    message: webResult.isSignedIn
                        ? "Personalized YouTube search results"
                        : "YouTube search results"
                )
                return
            }

            let failure = searchFailureMessage(apiError: apiError, webDiagnostics: webResult.diagnostics)
            applyLocalSearch(searchTerm, failure: failure)
        }

        private func applyLocalSearch(_ searchTerm: String, failure: String) {
            var localPoolSource = feed.forYou
            localPoolSource += feed.trending
            localPoolSource += feed.more
            localPoolSource += feed.queue
            localPoolSource += recentlyWatched
            localPoolSource += savedVideos
            localPoolSource += locallyLikedVideos
            localPoolSource += playbackQueue
            let localPool = mergeVideos(localPoolSource)
            let matches = YouGlassLibrarySearch.videos(matching: searchTerm, in: localPool)
            if !matches.isEmpty {
                sectionEmptyMessage = nil
                searchResults = Array(matches.prefix(40))
                connectionMessage = isNetworkAvailable
                    ? "Showing library and cached results while YouTube search recovers"
                    : "Offline results from your library and cached feed"
                searchState.message = connectionMessage
                searchState.emptyMessage = nil
                return
            }

            searchResults = []
            sectionEmptyMessage = failure
            searchState.emptyMessage = failure
            searchState.message = failure
            connectionMessage = failure
        }

        func searchFailureMessage(apiError: Error?, webDiagnostics: String) -> String {
            if let youtubeError = apiError as? YouTubeAPIError,
               case .httpStatus(let status, let reason, _) = youtubeError,
               status == 429 || reason == "rateLimitExceeded" || reason == "quotaExceeded" || reason == "dailyLimitExceeded" {
                return "YouTube search is temporarily unavailable. Try again shortly."
            }

            if let apiError {
                return "Search unavailable: \(apiError.localizedDescription)"
            }
            return webDiagnostics
        }
}
