import AppKit
import Foundation
import SwiftUI

extension YouTubeStore {
        var colorScheme: ColorScheme {
            theme.colorScheme
        }

        func setTheme(_ theme: AppTheme) {
            self.theme = theme
            defaults.set(theme.rawValue, forKey: DefaultsKey.theme)
        }

        func setVisualTheme(_ visualTheme: YouGlassThemeFamily) {
            self.visualTheme = visualTheme
            defaults.set(visualTheme.rawValue, forKey: DefaultsKey.visualTheme)
        }

        func setBackgroundGlow(_ value: Double) {
            backgroundGlow = min(max(value, 0.35), 1.0)
            defaults.set(backgroundGlow, forKey: DefaultsKey.backgroundGlow)
        }

        func setGlassIntensity(_ value: Double) {
            glassIntensity = min(max(value, 0.25), 1.0)
            defaults.set(glassIntensity, forKey: DefaultsKey.glassIntensity)
        }

        func setAmbientPalette(_ palette: VideoAmbientPalette) {
            ambientPalette = palette
        }

        func resetAmbientPalette() {
            ambientPalette = .neutral
        }

        @discardableResult
        func registerPlaybackStopHandler(_ handler: @escaping () -> Void) -> UUID {
            playbackStopHandler = handler
            let token = UUID()
            playbackStopHandlerToken = token
            return token
        }

        func unregisterPlaybackStopHandler() {
            playbackStopHandler = nil
            playbackStopHandlerToken = nil
        }

        func unregisterPlaybackStopHandler(_ token: UUID) {
            guard playbackStopHandlerToken == token else { return }
            playbackStopHandler = nil
            playbackStopHandlerToken = nil
        }

        @discardableResult
        func registerPlaybackCommandHandler(
            _ handler: @escaping (YouGlassPlaybackCommand) -> Void
        ) -> UUID {
            let token = UUID()
            playbackCommandHandler = handler
            playbackCommandHandlerToken = token
            return token
        }

        func unregisterPlaybackCommandHandler(_ token: UUID) {
            guard playbackCommandHandlerToken == token else { return }
            playbackCommandHandler = nil
            playbackCommandHandlerToken = nil
        }

        func sendPlaybackCommand(_ command: YouGlassPlaybackCommand) {
            guard selectedVideo != nil else { return }
            playbackCommandHandler?(command)
        }

        func prewarmPlayback(for video: VideoItem) {
            Task.detached(priority: .utility) {
                await YouTubePlaybackPrewarmer.shared.prewarm(video)
            }
        }

        var hasDataAPIKey: Bool { client.canConnect }

        var hasOAuthClientID: Bool { oauth.hasClientID }

        var hasOAuthClientSecret: Bool { oauth.hasClientSecret }

        func saveDataAPIKey(_ value: String) {
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { return }
            KeychainStore.write(clean, service: "com.kevinhowe.YouGlass", account: "YOUTUBE_API_KEY")
            client = YouTubeAPIClient(apiKey: clean, oauth: oauth)
            invalidateAccountSignalCache()
            connectionMessage = "YouTube Data API key saved"
        }

        func saveOAuthClientID(_ value: String) {
            oauth.saveClientID(value)
            invalidateAccountSignalCache()
            connectionMessage = oauth.hasClientID
                ? "Google OAuth client ID saved"
                : "Google OAuth client ID is empty"
        }

        func saveOAuthClientSecret(_ value: String) {
            oauth.saveClientSecret(value)
            invalidateAccountSignalCache()
            connectionMessage = oauth.hasClientSecret
                ? "Google OAuth client secret saved"
                : "Google OAuth client secret is empty"
        }

        func resetYouTubeCredentials() {
            oauth.clearStoredCredentials()
            KeychainStore.remove(service: "com.kevinhowe.YouGlass", account: "YOUTUBE_API_KEY")
            client = YouTubeAPIClient(oauth: oauth)
            isSignedIn = false
            profileImageURL = nil
            subscriptions = []
            subscriptionsLoaded = false
            defaults.removeObject(forKey: DefaultsKey.cachedSubscriptions)
            defaults.removeObject(forKey: DefaultsKey.cachedSubscriptionsDate)
            cachedSubscriptionsUpdatedAt = nil
            lastAccountSyncDate = nil
            recommendationSeeds = []
            invalidateAccountSignalCache()
            defaults.set(false, forKey: DefaultsKey.isSignedIn)
            defaults.removeObject(forKey: DefaultsKey.profileImageURL)
            defaults.removeObject(forKey: DefaultsKey.recommendationSeeds)
            defaults.removeObject(forKey: DefaultsKey.cachedPersonalizedFeed)
            defaults.removeObject(forKey: DefaultsKey.cachedPersonalizedFeedDate)
            defaults.removeObject(forKey: DefaultsKey.lastAccountSyncDate)
            cachedPersonalizedFeedUpdatedAt = nil
            feedLastRefreshedDate = cachedFeedUpdatedAt
            YouTubeBrowserWindow.shared.clearAuthenticationSession()
            connectionMessage = "YouTube sign-in data reset"
        }

        func clearCachedRecommendationData() {
            defaults.removeObject(forKey: DefaultsKey.cachedFeed)
            defaults.removeObject(forKey: DefaultsKey.cachedFeedDate)
            defaults.removeObject(forKey: DefaultsKey.cachedPersonalizedFeed)
            defaults.removeObject(forKey: DefaultsKey.cachedPersonalizedFeedDate)
            cachedFeedUpdatedAt = nil
            cachedPersonalizedFeedUpdatedAt = nil
            feedLastRefreshedDate = nil
            cachedAccountSignalVideos = []
            lastHomeLoadDate = nil
            feed = VideoItem.loadingFeed
            sectionEmptyMessage = nil
            connectionMessage = "Cached recommendation data cleared"
        }

        func setAutoMuteOnStart(_ value: Bool) {
            autoMuteOnStart = value
            defaults.set(value, forKey: DefaultsKey.autoMuteOnStart)
            connectionMessage = value
                ? "Videos will start muted"
                : "Videos will start with audio"
        }

        func setCompactPlayerCorner(_ corner: CompactPlayerCorner) {
            compactPlayerCorner = corner
            defaults.set(corner.rawValue, forKey: DefaultsKey.compactPlayerCorner)
        }
}
