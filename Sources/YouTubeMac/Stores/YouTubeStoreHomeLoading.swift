import AppKit
import Foundation
import SwiftUI

extension YouTubeStore {
        func loadHome(force: Bool = false, sectionGeneration: Int? = nil) async {
            guard canPublishSectionLoad(sectionGeneration) else { return }
            guard !homeLoadInProgress else {
                homeReloadPending = true
                homeReloadPendingForce = homeReloadPendingForce || force
                return
            }

            if !force {
                let now = Date()
                if let lastHomeLoadDate,
                   now.timeIntervalSince(lastHomeLoadDate) < 15,
                   !feed.forYou.isEmpty || !feed.trending.isEmpty || !feed.more.isEmpty || !feed.queue.isEmpty {
                    return
                }
                guard YouGlassFeedRefreshPolicy.needsRefresh(
                    lastUpdated: feedLastRefreshedDate,
                    now: now
                ) else {
                    return
                }
            }

            homeLoadInProgress = true
            isLoading = true
            sectionEmptyMessage = nil
            YouGlassDiagnostics.feed.info("Home load started; forced: \(force, privacy: .public)")
            YouGlassDiagnostics.record(
                .info,
                category: "feed",
                message: "Home feed load started",
                metadata: ["forced": String(force)]
            )
            if feed.forYou.isEmpty && feed.trending.isEmpty && feed.more.isEmpty && feed.queue.isEmpty,
               let data = defaults.data(forKey: DefaultsKey.cachedFeed),
               let cachedVideos = try? JSONDecoder().decode([VideoItem].self, from: data),
               !cachedVideos.isEmpty {
                if let age = YouGlassCachePolicy.age(of: cachedFeedUpdatedAt) {
                    YouGlassDiagnostics.feed.debug("Restoring cached feed age: \(age, privacy: .public) seconds")
                }
                _ = applyPrimaryHomeVideos(
                    cachedVideos,
                    message: "Saved YouTube recommendations",
                    cacheFeed: false
                )
            }
            defer {
                if canPublishSectionLoad(sectionGeneration) {
                    isLoading = false
                }
                homeLoadInProgress = false
                lastHomeLoadDate = Date()
                YouGlassDiagnostics.feed.info("Home load finished")
                YouGlassDiagnostics.record(.info, category: "feed", message: "Home feed load finished")
                if homeReloadPending {
                    homeReloadPending = false
                    let pendingForce = homeReloadPendingForce
                    homeReloadPendingForce = false
                    let recentlyFinished = lastHomeLoadDate.map {
                        Date().timeIntervalSince($0) < 15
                    } ?? false
                    let hasVisibleFeed = !feed.forYou.isEmpty
                        || !feed.trending.isEmpty
                        || !feed.more.isEmpty
                        || !feed.queue.isEmpty
                    if pendingForce || !recentlyFinished || !hasVisibleFeed {
                        scheduleHomeReload(force: pendingForce)
                    }
                }
            }

            if !isNetworkAvailable {
                guard canPublishSectionLoad(sectionGeneration) else { return }
                connectionMessage = "Offline — showing saved recommendations"
                return
            }

            guard canPublishSectionLoad(sectionGeneration) else { return }
            connectionMessage = "Loading YouTube homepage recommendations..."
            let hasOAuthSession = (try? await oauth.validAccessToken()) != nil
            guard canPublishSectionLoad(sectionGeneration) else { return }
            if hasOAuthSession && !isSignedIn {
                isSignedIn = true
                defaults.set(true, forKey: DefaultsKey.isSignedIn)
            }

            // OAuth-backed Data API calls are account-scoped and do not need the
            // hidden homepage bridge. Skipping it removes the largest source of
            // remote layer-tree activity for signed-in users while preserving the
            // web-session fallback for API-key-only installs.
            let webResult: YouTubeWebFeedResult
            if hasOAuthSession {
                YouGlassDiagnostics.record(
                    .debug,
                    category: "webkit",
                    message: "Skipped hidden homepage bridge for OAuth account"
                )
                webResult = .empty
            } else {
                webResult = await YouTubeWebFeedBridge.shared.loadHomeVideos(maxResults: 32)
            }
            guard canPublishSectionLoad(sectionGeneration) else { return }
            if let profileURL = webResult.profileImageURL {
                profileImageURL = profileURL
                defaults.set(profileURL.absoluteString, forKey: DefaultsKey.profileImageURL)
            }
            if webResult.isSignedIn && !isSignedIn {
                isSignedIn = true
                defaults.set(true, forKey: DefaultsKey.isSignedIn)
            }

            if isSignedIn {
                // The hidden YouTube homepage can return a Shorts-only public
                // surface even when the account session is valid. Build the
                // account feed from the user's actual subscriptions first.
                await loadSubscriptions(force: false)
                guard canPublishSectionLoad(sectionGeneration) else { return }
                let personalized = await personalizedAccountFeed(
                    webHomepageVideos: webResult.isSignedIn ? webResult.videos : []
                )
                guard canPublishSectionLoad(sectionGeneration) else { return }
                if !personalized.isEmpty,
                   applyPrimaryHomeVideos(
                        personalized,
                        message: "Personalized feed from your YouTube account"
                   ) {
                    cachePersonalizedFeed(personalized)
                    return
                }
            }

            if !webResult.videos.isEmpty && (!isSignedIn || webResult.isSignedIn) {
                let message = webResult.isSignedIn
                    ? "Using signed-in YouTube homepage recommendations"
                    : "Using YouTube homepage recommendations"
                if applyPrimaryHomeVideos(webResult.videos, message: message) {
                    return
                }
            }

            let hasCredentials = await client.hasCredentials()
            guard canPublishSectionLoad(sectionGeneration) else { return }
            guard hasCredentials else {
                let safariSignals = await safariHomeFeed.loadFeed(maxResultsPerChannel: 5)
                guard canPublishSectionLoad(sectionGeneration) else { return }
                if !safariSignals.isEmpty,
                   applyPrimaryHomeVideos(
                        safariSignals,
                        message: "Safari Home-style channel recommendations (\(safariSignals.count) fresh uploads)"
                   ) {
                    return
                }

                connectionMessage = isSignedIn
                    ? "Signed in; web feed unavailable (\(webResult.diagnostics))"
                    : "API key needed for live YouTube (\(webResult.diagnostics))"
                return
            }

            do {
                let personalized = await personalizedVideos(maxResults: 12)
                guard canPublishSectionLoad(sectionGeneration) else { return }
                let accountSignals = await accountSignalVideos(maxResults: 12)
                guard canPublishSectionLoad(sectionGeneration) else { return }
                let popular = try await client.mostPopularVideos(maxResults: 8)
                guard canPublishSectionLoad(sectionGeneration) else { return }
                let appleTech = try await client.searchVideos(query: "Apple Vision Pro technology creators", maxResults: 6, order: "relevance", videoCategoryId: "28")
                guard canPublishSectionLoad(sectionGeneration) else { return }
                let candidates = accountSignals + personalized + popular + appleTech
                if !applyPrimaryHomeVideos(
                    candidates,
                    message: "Recommended by YouTube API account signals"
                ) {
                    _ = applyPrimaryHomeVideos(popular + appleTech, message: "Popular on YouTube")
                }
            } catch {
                guard canPublishSectionLoad(sectionGeneration) else { return }
                // Keep a cached or signed-in web feed visible when the Data API
                // project is temporarily rate-limited. Calling search again here
                // only compounds the quota problem and can replace useful content
                // with an error state.
                connectionMessage = feed.forYou.isEmpty && feed.trending.isEmpty && feed.more.isEmpty
                    ? error.localizedDescription
                    : "Using saved recommendations. \(error.localizedDescription)"
            }
        }
}
