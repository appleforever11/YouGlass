import Foundation

extension YouTubeStore {
    func connectRuntimeServices() {
        networkMonitor = YouGlassNetworkMonitor { [weak self] isAvailable in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isNetworkAvailable = isAvailable
                self.networkStatus = isAvailable ? "Online" : "Offline — using saved data"
            }
        }
        networkMonitor?.start()
        YouGlassDockMenuController.shared.store = self

        authObservers = [
            NotificationCenter.default.addObserver(
                forName: .youTubeBrowserDidAuthenticate,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let profileURL = (notification.userInfo?[YouTubeAuthBridge.profileImageURLKey] as? String)
                    .flatMap(URL.init(string:))
                Task { @MainActor in
                    guard let self else { return }
                    self.invalidateAccountRequests()
                    self.isSignedIn = true
                    self.connectionMessage = "Signed in to YouTube"
                    self.defaults.set(true, forKey: DefaultsKey.isSignedIn)
                    if let url = profileURL {
                        self.profileImageURL = url
                        self.defaults.set(url.absoluteString, forKey: DefaultsKey.profileImageURL)
                    } else {
                        await self.refreshProfileImage()
                    }
                    self.lastAccountSyncDate = nil
                    self.invalidateAccountSignalCache()
                    self.scheduleSubscriptionsLoad(force: true)
                    self.scheduleHomeReload(force: true)
                }
            },
            NotificationCenter.default.addObserver(
                forName: .youTubeBrowserDidSignOut,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.invalidateAccountRequests()
                    self?.isSignedIn = false
                    self?.subscriptions = []
                    self?.selectedSubscriptionGroupID = nil
                    self?.subscriptionGroupVideos = []
                    self?.subscriptionsLoaded = false
                    self?.profileImageURL = nil
                    self?.lastAccountSyncDate = nil
                    self?.invalidateAccountSignalCache()
                    self?.clearRecentlyPresentedRecommendations()
                    self?.cachedSubscriptionsUpdatedAt = nil
                    self?.defaults.set(false, forKey: DefaultsKey.isSignedIn)
                    self?.defaults.removeObject(forKey: DefaultsKey.profileImageURL)
                    self?.defaults.removeObject(forKey: DefaultsKey.cachedSubscriptions)
                    self?.defaults.removeObject(forKey: DefaultsKey.cachedSubscriptionsDate)
                    self?.defaults.removeObject(forKey: DefaultsKey.cachedPersonalizedFeed)
                    self?.defaults.removeObject(forKey: DefaultsKey.cachedPersonalizedFeedDate)
                    self?.defaults.removeObject(forKey: DefaultsKey.lastAccountSyncDate)
                    self?.cachedPersonalizedFeedUpdatedAt = nil
                    self?.feedLastRefreshedDate = self?.cachedFeedUpdatedAt
                    self?.scheduleHomeReload(force: true)
                }
            }
        ]

        if isSignedIn {
            Task { @MainActor [weak self] in
                await self?.refreshProfileImage()
            }
        }

        YouTubeBrowserWindow.shared.checkAuthenticationState()
    }
}
