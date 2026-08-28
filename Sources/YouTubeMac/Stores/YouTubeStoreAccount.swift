import AppKit
import Foundation
import SwiftUI

extension YouTubeStore {
        func refreshAccount() {
            accountSyncTask?.cancel()
            accountSyncGeneration &+= 1
            let generation = accountSyncGeneration
            subscriptionsLoaded = false
            invalidateAccountSignalCache()
            connectionMessage = "Refreshing your YouTube account..."
            accountSyncStatus = nil
            accountSyncInProgress = true

            accountSyncTask = Task { @MainActor [weak self] in
                guard let self else { return }
                defer {
                    if self.accountSyncGeneration == generation {
                        self.accountSyncInProgress = false
                        self.accountSyncTask = nil
                    }
                }

                // OAuth is authoritative for API-backed account data. Checking it
                // first prevents a stale cookie-based sign-in flag from racing the
                // subscription and recommendation requests.
                let hasOAuthSession: Bool
                do {
                    hasOAuthSession = try await self.oauth.validAccessToken() != nil
                } catch {
                    hasOAuthSession = false
                }

                guard !Task.isCancelled, self.accountSyncGeneration == generation else { return }
                let browserSession = await YouTubeBrowserWindow.shared.hasAuthenticatedYouTubeSession()
                guard !Task.isCancelled, self.accountSyncGeneration == generation else { return }
                let hasBrowserSession = hasOAuthSession || browserSession
                self.isSignedIn = hasBrowserSession
                self.defaults.set(hasBrowserSession, forKey: DefaultsKey.isSignedIn)
                if !hasBrowserSession {
                    self.profileImageURL = nil
                    self.defaults.removeObject(forKey: DefaultsKey.profileImageURL)
                }

                guard !Task.isCancelled, self.accountSyncGeneration == generation else { return }
                await self.loadSubscriptions(force: true)
                guard !Task.isCancelled, self.accountSyncGeneration == generation else { return }
                await self.loadHome(force: true)
                guard !Task.isCancelled, self.accountSyncGeneration == generation else { return }

                self.accountSyncStatus = self.isSignedIn
                    ? "Account, subscriptions, and recommendations refreshed"
                    : "Sign in to refresh account data"
            }
        }

        func scheduleSubscriptionsLoad(force: Bool) {
            Task { @MainActor [weak self] in
                await self?.loadSubscriptions(force: force)
            }
        }

        func loadSubscriptions(force: Bool) async {
            guard !subscriptionLoadInProgress else {
                if force { subscriptionReloadPending = true }
                await withCheckedContinuation { continuation in
                    subscriptionLoadWaiters.append(continuation)
                }
                return
            }
            let lastSubscriptionRefresh = cachedSubscriptionsUpdatedAt ?? lastAccountSyncDate
            guard force || !subscriptionsLoaded || YouGlassFeedRefreshPolicy.needsRefresh(
                lastUpdated: lastSubscriptionRefresh,
                maxAge: YouGlassFeedRefreshPolicy.subscriptionRefreshInterval
            ) else { return }
            guard isSignedIn else {
                subscriptions = []
                subscriptionsLoaded = false
                return
            }

            subscriptionLoadInProgress = true
            YouGlassDiagnostics.auth.info("Subscription load started; forced: \(force, privacy: .public)")
            defer {
                subscriptionLoadInProgress = false
                YouGlassDiagnostics.auth.info("Subscription load finished")
                let waiters = subscriptionLoadWaiters
                subscriptionLoadWaiters.removeAll()
                waiters.forEach { $0.resume() }
                if subscriptionReloadPending {
                    subscriptionReloadPending = false
                    Task { @MainActor [weak self] in
                        await self?.loadSubscriptions(force: true)
                    }
                }
            }

            var apiSubscriptions: [SubscriptionItem] = []
            var apiRequestSucceeded = false
            do {
                apiSubscriptions = try await client.mySubscriptions(maxResults: 200)
                apiRequestSucceeded = true
                YouGlassDiagnostics.auth.debug("Subscription API returned \(apiSubscriptions.count, privacy: .public) items")
            } catch {
                YouGlassDiagnostics.auth.error("Subscription API request failed")
                connectionMessage = error.localizedDescription
            }

            // The OAuth list has stable channel IDs and is authoritative, including
            // an authenticated empty response. Only scrape the signed-in web
            // session when the API request itself failed.
            let webSubscriptions = apiRequestSucceeded
                ? []
                : await subscriptionBridge.loadSubscriptions(maxResults: 200)

            let mergedSubscriptions = mergeSubscriptions(apiSubscriptions + webSubscriptions)
            if !mergedSubscriptions.isEmpty {
                subscriptions = mergedSubscriptions
                subscriptionsLoaded = true
                persistSubscriptions(mergedSubscriptions)
                lastAccountSyncDate = Date()
                defaults.set(lastAccountSyncDate, forKey: DefaultsKey.lastAccountSyncDate)
                connectionMessage = "Loaded \(mergedSubscriptions.count) subscriptions from YouTube"
                return
            }

            if apiRequestSucceeded {
                // An authenticated empty response is meaningful. Clear stale
                // subscriptions instead of continuing to display old channels.
                subscriptions = []
                subscriptionsLoaded = true
                persistSubscriptions([])
                lastAccountSyncDate = Date()
                defaults.set(lastAccountSyncDate, forKey: DefaultsKey.lastAccountSyncDate)
                connectionMessage = "Your YouTube account has no subscriptions"
                return
            }

            if webSubscriptions.isEmpty && apiSubscriptions.isEmpty {
                connectionMessage = connectionMessage == "Refreshing your YouTube account..."
                    ? "Your YouTube account has no subscriptions"
                    : connectionMessage
            }
            subscriptionsLoaded = false
        }

        func mergeSubscriptions(_ items: [SubscriptionItem]) -> [SubscriptionItem] {
            items.reduce(into: [SubscriptionItem]()) { result, item in
                let duplicate = result.contains { existing in
                    if let channelID = item.canonicalChannelID,
                       let existingChannelID = existing.canonicalChannelID {
                        return channelID == existingChannelID
                    }
                    return existing.matches(channelID: nil, channelName: item.name)
                }
                if !duplicate {
                    result.append(item)
                }
            }
        }
}
