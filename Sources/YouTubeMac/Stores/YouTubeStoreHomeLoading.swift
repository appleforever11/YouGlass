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

            let now = Date()
            if force {
                if let lastHomeLoadDate,
                   now.timeIntervalSince(lastHomeLoadDate) < YouGlassFeedRefreshPolicy.manualRefreshMinimumInterval {
                    return
                }
            } else {
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
                    cacheFeed: false,
                    preserveSourceOrder: defaults.bool(forKey: "YouGlass.cachedHomePreservesYouTubeOrder")
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
            connectionMessage = force
                ? "Refreshing fresh YouTube recommendations..."
                : "Loading YouTube homepage recommendations..."
            let hasOAuthSession = (try? await oauth.validAccessToken()) != nil
            guard canPublishSectionLoad(sectionGeneration) else { return }
            if hasOAuthSession && !isSignedIn {
                isSignedIn = true
                defaults.set(true, forKey: DefaultsKey.isSignedIn)
            }

            // Read the actual web homepage without a hidden rendering surface.
            // OAuth alone does not provide YouTube Home's recommendation order.
            let webResult = await YouTubeHomepageClient().load(maxResults: 40)
            guard canPublishSectionLoad(sectionGeneration) else { return }
            YouGlassDiagnostics.record(.info, category: "feed", message: "YouTube Home response",
                                       metadata: ["count": String(webResult.videos.count),
                                                  "signedIn": String(webResult.isSignedIn)])
            if let profileURL = webResult.profileImageURL {
                profileImageURL = profileURL
                defaults.set(profileURL.absoluteString, forKey: DefaultsKey.profileImageURL)
            }
            if webResult.isSignedIn && !isSignedIn {
                isSignedIn = true
                defaults.set(true, forKey: DefaultsKey.isSignedIn)
            }

            if !webResult.videos.isEmpty,
               applyPrimaryHomeVideos(webResult.videos,
                                      message: "Live suggestions from YouTube Home",
                                      preserveSourceOrder: true) {
                cachePersonalizedFeed(webResult.videos)
                if subscriptions.isEmpty { scheduleSubscriptionsLoad(force: false) }
                return
            }

            if isSignedIn {
                // If the web homepage is unavailable, build the
                // account feed from the user's actual subscriptions first.
                // A Home refresh should not block on full subscription
                // pagination when a persisted snapshot is already available.
                // The account refresh action still forces it, and a stale Home
                // snapshot is refreshed in the background by the subscription
                // age policy.
                let lastSubscriptionRefresh = cachedSubscriptionsUpdatedAt ?? lastAccountSyncDate
                let needsSubscriptionRefresh = !subscriptionsLoaded
                    || YouGlassFeedRefreshPolicy.needsRefresh(
                        lastUpdated: lastSubscriptionRefresh,
                        now: Date(),
                        maxAge: YouGlassFeedRefreshPolicy.subscriptionRefreshInterval
                    )
                if needsSubscriptionRefresh {
                    if subscriptions.isEmpty {
                        await loadSubscriptions(force: force && !subscriptionsLoaded)
                    } else {
                        scheduleSubscriptionsLoad(force: false)
                    }
                }
                guard canPublishSectionLoad(sectionGeneration) else { return }
                let personalized = await personalizedAccountFeed(
                    webHomepageVideos: webResult.isSignedIn ? webResult.videos : [],
                    forceFresh: force
                )
                guard canPublishSectionLoad(sectionGeneration) else { return }
                if !personalized.isEmpty,
                   applyPrimaryHomeVideos(
                        personalized,
                        message: "Personalized feed from your YouTube account",
                        favorFresh: true
                   ) {
                    cachePersonalizedFeed(personalized)
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
                        message: "Safari Home-style channel recommendations (\(safariSignals.count) fresh uploads)",
                        favorFresh: true
                   ) {
                    return
                }

                connectionMessage = isSignedIn
                    ? "Signed in; web feed unavailable (\(webResult.diagnostics))"
                    : "API key needed for live YouTube (\(webResult.diagnostics))"
                return
            }

            // Start every independent API source together. The request gate
            // still spaces the individual requests for quota safety, but no
            // source waits for a previous source to finish before it can
            // reserve its request slot. Search is intentionally limited to
            // one seed here; the normal signed-in subscription path already
            // has fresh RSS and account signals without spending a burst of
            // expensive search requests.
            async let personalized = personalizedVideos(
                maxResults: 12,
                forceFresh: force,
                seedLimit: 1
            )
            async let accountSignals = accountSignalVideos(maxResults: 12, forceRefresh: force)
            async let popular: [VideoItem] = (try? await client.mostPopularVideos(
                maxResults: 8,
                forceFresh: force
            )) ?? []
            let (personalizedVideos, accountSignalVideos, popularVideos) = await (
                personalized,
                accountSignals,
                popular
            )
            guard canPublishSectionLoad(sectionGeneration) else { return }
            let candidates = accountSignalVideos + personalizedVideos + popularVideos
            if !applyPrimaryHomeVideos(
                candidates,
                message: "Recommended by YouTube API account signals",
                favorFresh: true
            ) {
                _ = applyPrimaryHomeVideos(
                    popularVideos,
                    message: "Popular on YouTube",
                    favorFresh: true
                )
            }
            if candidates.isEmpty {
                connectionMessage = feed.forYou.isEmpty && feed.trending.isEmpty && feed.more.isEmpty
                    ? "Fresh YouTube recommendations are unavailable right now"
                    : "Using saved recommendations; no fresh items were available"
            }
        }
}
