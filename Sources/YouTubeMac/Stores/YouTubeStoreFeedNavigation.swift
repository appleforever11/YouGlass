import AppKit
import Foundation
import SwiftUI

extension YouTubeStore {
        func refreshHomeIfNeeded(now: Date = Date()) async {
            guard !homeLoadInProgress else { return }
            if let lastHomeLoadDate,
               now.timeIntervalSince(lastHomeLoadDate) < 15 {
                return
            }
            guard YouGlassFeedRefreshPolicy.needsRefresh(
                lastUpdated: feedLastRefreshedDate,
                now: now
            ) else {
                return
            }
            await loadHome(force: false)
        }

        func startAutomaticFeedRefresh() {
            guard homeRefreshTask == nil else { return }

            let nanoseconds = UInt64(YouGlassFeedRefreshPolicy.activeRefreshInterval * 1_000_000_000)
            homeRefreshTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    do {
                        try await Task.sleep(nanoseconds: nanoseconds)
                    } catch {
                        return
                    }

                    guard let self, !Task.isCancelled else { return }
                    await self.refreshHomeIfNeeded()
                }
            }
        }

        func stopAutomaticFeedRefresh() {
            homeRefreshTask?.cancel()
            homeRefreshTask = nil
        }

        func handleScenePhaseChange(_ phase: ScenePhase) {
            switch phase {
            case .active:
                startAutomaticFeedRefresh()
                Task { @MainActor [weak self] in
                    await self?.refreshHomeIfNeeded()
                }
            case .inactive, .background:
                stopAutomaticFeedRefresh()
            @unknown default:
                break
            }
        }

        func showSection(_ title: String, query: String? = nil) {
            if selectedVideo != nil {
                isPlayerCompact = true
            }
            selectedPlaylist = nil
            playlistItems = []
            playlistError = nil
            selectedSection = title
            self.query = query ?? (title == "Home" ? "" : self.query)
            Task { @MainActor [weak self] in
                await self?.loadSection(title, query: query)
            }
        }

        func loadSection(_ title: String, query: String?) async {
            switch title {
            case "Home":
                await loadHome()
            case "Shorts":
                await loadShorts()
            case "History":
                await loadHistory()
            case "Watch Later":
                if savedVideos.isEmpty {
                    showEmptySection("Your Watch Later list is empty")
                } else {
                    applyHomeVideos(savedVideos, message: "Saved in YouGlass Watch Later")
                }
            case "Liked Videos":
                await loadLikedVideos()
            case "Library":
                sectionEmptyMessage = nil
                connectionMessage = "Your local YouGlass library"
            case "Playlists":
                await loadPlaylists()
            case "Subscriptions":
                await loadSubscriptionFeed()
            default:
                if let query, !query.isEmpty { await search(query) }
            }
        }

        func loadHistory() async {
            isLoading = true
            defer { isLoading = false }

            // YouTube does not expose account watch history through Data API v3.
            // Show YouGlass's durable local history immediately, then reconcile it
            // with the optional signed-in web session only when that bridge is
            // explicitly enabled. This keeps History useful without mounting a
            // hidden WebKit surface on systems where it has been unstable.
            if !recentlyWatched.isEmpty {
                applyHomeVideos(
                    recentlyWatched,
                    message: "Videos watched in YouGlass on this Mac",
                    cacheFeed: false
                )
            }

            // Data API v3 intentionally does not return the private system
            // watch-history playlist. The signed-in YouTube session is the
            // authoritative source for this page.
            YouGlassDiagnostics.record(
                .debug,
                category: "account",
                message: "Loading account watch history from the signed-in YouTube session"
            )
            let webResult = await YouTubeWebFeedBridge.shared.loadHistoryVideos(maxResults: 100)
            if webResult.isSignedIn && !isSignedIn {
                isSignedIn = true
                defaults.set(true, forKey: DefaultsKey.isSignedIn)
            }
            if !webResult.videos.isEmpty {
                let reconciled = mergeVideos(webResult.videos + recentlyWatched)
                applyHomeVideos(
                    reconciled,
                    message: "YouTube session history combined with YouGlass history",
                    cacheFeed: false
                )
                YouGlassDiagnostics.feed.info("Loaded \(webResult.videos.count, privacy: .public) account watch-history videos from the signed-in web session")
                return
            }

            if !recentlyWatched.isEmpty { return }

            if isSignedIn {
                showEmptySection("Your YouTube watch history is unavailable in the current session. Reconnect YouTube and try again.")
            } else {
                showEmptySection("Sign in with Google to load your YouTube watch history")
            }
        }

        func loadShorts() async {
            guard await client.hasCredentials() else {
                connectionMessage = "Sign in with Google or add a YouTube API key to load Shorts"
                return
            }
            isLoading = true
            defer { isLoading = false }
            do {
                let shorts = try await client.searchVideos(
                    query: "shorts",
                    maxResults: 12,
                    order: "date",
                    videoDuration: "short"
                )
                applyHomeVideos(shorts, message: "Latest Shorts from YouTube")
            } catch {
                connectionMessage = "Using saved Shorts. \(error.localizedDescription)"
            }
        }

        func loadLikedVideos() async {
            if isSignedIn, await client.hasCredentials() {
                do {
                    let liked = try await client.likedVideos(maxResults: 50)
                    applyHomeVideos(
                        liked.isEmpty ? locallyLikedVideos : liked,
                        message: liked.isEmpty ? "No liked videos returned by YouTube" : "Liked videos from YouTube"
                    )
                    return
                } catch {
                    connectionMessage = "Using saved liked videos. \(error.localizedDescription)"
                }
            }
            if locallyLikedVideos.isEmpty {
                showEmptySection("Like a video to build this list")
            } else {
                applyHomeVideos(locallyLikedVideos, message: "Liked videos saved in YouGlass")
            }
        }

        func loadSubscriptionFeed() async {
            await loadSubscriptions(force: false)
            guard isSignedIn else {
                connectionMessage = "Sign in with Google to load subscription uploads"
                return
            }

            isLoading = true
            defer { isLoading = false }

            let subscribedChannels = subscriptions.compactMap { subscription -> SafariHomeFeedClient.Channel? in
                let source = subscription.channelURL
                    ?? (subscription.id.hasPrefix("UC")
                        ? URL(string: "https://www.youtube.com/channel/\(subscription.id)")
                        : nil)
                guard let source else { return nil }
                return SafariHomeFeedClient.Channel(
                    name: subscription.name,
                    source: source,
                    category: "Subscriptions",
                    channelID: subscription.canonicalChannelID
                )
            }

            var uploads = await safariHomeFeed.loadFeed(
                channels: Array(subscribedChannels.prefix(40)),
                maxResultsPerChannel: 4
            )
            if uploads.isEmpty {
                uploads = await accountSignalVideos(maxResults: 16)
            }
            if uploads.isEmpty {
                showEmptySection("No recent subscription uploads were returned")
            } else {
                applyHomeVideos(uploads, message: "Latest uploads from your subscriptions")
            }
        }

        func loadPlaylists() async {
            guard isSignedIn else {
                playlists = []
                showEmptySection("Sign in with Google to load your YouTube playlists")
                return
            }

            guard await client.hasCredentials() else {
                showEmptySection("Add a YouTube API key or reconnect Google in Settings")
                return
            }

            playlistLoading = true
            playlistError = nil
            defer { playlistLoading = false }

            do {
                let loaded = try await client.myPlaylists(maxResults: 100)
                playlists = loaded
                if loaded.isEmpty {
                    showEmptySection("No YouTube playlists were found on this account")
                } else {
                    sectionEmptyMessage = nil
                    connectionMessage = "Loaded \(loaded.count) playlists from YouTube"
                }
            } catch {
                playlistError = error.localizedDescription
                if playlists.isEmpty {
                    showEmptySection(error.localizedDescription)
                } else {
                    connectionMessage = error.localizedDescription
                }
            }
        }
}
