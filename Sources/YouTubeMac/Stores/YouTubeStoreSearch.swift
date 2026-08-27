import AppKit
import Foundation
import SwiftUI

extension YouTubeStore {
        func search(_ term: String? = nil) async {
            let searchTerm = (term ?? query).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !searchTerm.isEmpty else { return }

            // Navigate immediately so a slow API or web-session fallback cannot
            // leave the user looking at the previous Home surface.
            query = searchTerm
            selectedSection = "Search"
            selectedPlaylist = nil
            selectedChannelItem = nil
            channelPage = nil
            sectionEmptyMessage = nil
            searchResults = []
            isLoading = true
            connectionMessage = "Searching YouTube..."
            YouGlassDiagnostics.feed.info("Search started")
            defer { isLoading = false }

            if let directVideo = VideoItem.fromYouTubeInput(searchTerm) {
                connectionMessage = "Opening YouTube video in the native player"
                open(directVideo)
                return
            }

            let hasCredentials = await client.hasCredentials()
            guard hasCredentials else {
                await applySearchFallback(for: searchTerm, apiError: nil)
                return
            }

            do {
                let videos = try await client.searchVideos(query: searchTerm, maxResults: 12)
                if !videos.isEmpty {
                    applySearchResults(videos, message: "Connected to YouTube")
                } else {
                    await applySearchFallback(for: searchTerm, apiError: nil)
                }
            } catch {
                // Data API search is quota-expensive and can be throttled even
                // when the signed-in YouTube website still works. Reuse the
                // authenticated hidden web session before showing an error.
                await applySearchFallback(for: searchTerm, apiError: error)
            }
        }

        func applySearchResults(_ videos: [VideoItem], message: String) {
            let merged = mergeVideos(videos)
            guard !merged.isEmpty else {
                searchResults = []
                sectionEmptyMessage = "No matching YouTube videos were found."
                return
            }
            sectionEmptyMessage = nil
            searchResults = merged
            feed.hero = merged.first ?? feed.hero
            feed.forYou = Array(merged.prefix(8))
            feed.trending = Array(merged.dropFirst(8).prefix(8))
            feed.more = Array(merged.dropFirst(16).prefix(8))
            feed.queue = Array(merged.suffix(min(4, merged.count)))
            connectionMessage = message
        }

        func applySearchFallback(for searchTerm: String, apiError: Error?) async {
            let webResult = await YouTubeWebFeedBridge.shared.searchVideos(query: searchTerm, maxResults: 20)
            if !webResult.videos.isEmpty {
                applySearchResults(
                    webResult.videos,
                    message: webResult.isSignedIn
                        ? "Personalized YouTube search results"
                        : "YouTube search results"
                )
                return
            }

            var localPoolSource = feed.forYou
            localPoolSource += feed.trending
            localPoolSource += feed.more
            localPoolSource += feed.queue
            localPoolSource += recentlyWatched
            localPoolSource += savedVideos
            localPoolSource += locallyLikedVideos
            localPoolSource += VideoItem.samples
            let localPool = mergeVideos(localPoolSource)
            let matches = localPool.filter { video in
                video.title.localizedCaseInsensitiveContains(searchTerm) ||
                video.channel.localizedCaseInsensitiveContains(searchTerm)
            }
            if !matches.isEmpty {
                applySearchResults(matches, message: "Showing saved results while YouTube search recovers")
                return
            }

            feed.forYou = []
            feed.trending = []
            feed.more = []
            feed.queue = []
            searchResults = []
            sectionEmptyMessage = "YouTube search is temporarily unavailable. Try again shortly."
            connectionMessage = searchFailureMessage(apiError: apiError, webDiagnostics: webResult.diagnostics)
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
