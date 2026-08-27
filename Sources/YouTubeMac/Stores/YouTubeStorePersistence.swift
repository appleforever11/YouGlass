import AppKit
import Foundation
import SwiftUI

extension YouTubeStore {
        func isAuthenticationError(_ error: Error) -> Bool {
            guard let apiError = error as? YouTubeAPIError else { return false }
            if case .authenticationRequired = apiError { return true }
            return false
        }

        func rememberRecommendationSeed(_ video: VideoItem) {
            let seed = "\(video.channel) \(video.title)"
            recommendationSeeds.removeAll { $0 == seed }
            recommendationSeeds.insert(seed, at: 0)
            recommendationSeeds = Array(recommendationSeeds.prefix(6))
            defaults.set(recommendationSeeds, forKey: DefaultsKey.recommendationSeeds)
        }

        func rememberHistory(_ video: VideoItem) {
            recentlyWatched.removeAll { $0.id == video.id }
            recentlyWatched.insert(video, at: 0)
            recentlyWatched = Array(recentlyWatched.prefix(100))
            persistVideos(recentlyWatched, key: DefaultsKey.recentlyWatched)
        }

        func decodeVideos(forKey key: String) -> [VideoItem] {
            guard let data = defaults.data(forKey: key),
                  let videos = try? JSONDecoder().decode([VideoItem].self, from: data) else { return [] }
            return videos
        }

        func decodePlaybackPositions() -> [String: Double] {
            guard let data = defaults.data(forKey: DefaultsKey.playbackPositions),
                  let positions = try? JSONDecoder().decode([String: Double].self, from: data) else {
                return [:]
            }
            return positions.filter { $0.value.isFinite && $0.value > 0 }
        }

        func decodePlaybackDurations() -> [String: Double] {
            guard let data = defaults.data(forKey: DefaultsKey.playbackDurations),
                  let durations = try? JSONDecoder().decode([String: Double].self, from: data) else {
                return [:]
            }
            return durations.filter { $0.value.isFinite && $0.value > 0 && playbackPositions[$0.key] != nil }
        }

        func decodePlaybackPositionDates() -> [String: Date] {
            guard let data = defaults.data(forKey: DefaultsKey.playbackPositionUpdatedAt),
                  let dates = try? JSONDecoder().decode([String: Date].self, from: data) else {
                return [:]
            }
            return dates.filter { playbackPositions[$0.key] != nil }
        }

        func decodeSubscriptions() -> [SubscriptionItem] {
            guard let data = defaults.data(forKey: DefaultsKey.cachedSubscriptions),
                  let items = try? JSONDecoder().decode([SubscriptionItem].self, from: data) else {
                return []
            }
            return mergeSubscriptions(items)
        }

        func persistPlaybackPositions() {
            guard let positionsData = try? JSONEncoder().encode(playbackPositions),
                  let durationsData = try? JSONEncoder().encode(playbackDurations),
                  let datesData = try? JSONEncoder().encode(playbackPositionUpdatedAt) else { return }
            defaults.set(positionsData, forKey: DefaultsKey.playbackPositions)
            defaults.set(durationsData, forKey: DefaultsKey.playbackDurations)
            defaults.set(datesData, forKey: DefaultsKey.playbackPositionUpdatedAt)
        }

        func decodeCollections() -> [YouGlassLibraryCollection] {
            guard let data = defaults.data(forKey: DefaultsKey.customCollections),
                  let collections = try? JSONDecoder().decode([YouGlassLibraryCollection].self, from: data) else {
                return []
            }
            return Array(collections.prefix(40))
        }

        func decodeVideoNotes() -> [YouGlassVideoNote] {
            guard let data = defaults.data(forKey: DefaultsKey.videoNotes),
                  let notes = try? JSONDecoder().decode([YouGlassVideoNote].self, from: data) else {
                return []
            }
            return Array(notes.prefix(200))
        }

        func decodeThemeCustomization() -> YouGlassThemeCustomization {
            guard let data = defaults.data(forKey: DefaultsKey.themeCustomization),
                  let customization = try? JSONDecoder().decode(YouGlassThemeCustomization.self, from: data),
                  customization.normalizedAccentHex != nil else {
                return .empty
            }
            return YouGlassThemeCustomization(accentHex: customization.normalizedAccentHex)
        }

        func persistLibrary() {
            if let collectionsData = try? JSONEncoder().encode(customCollections) {
                defaults.set(collectionsData, forKey: DefaultsKey.customCollections)
            }
            if let notesData = try? JSONEncoder().encode(videoNotes) {
                defaults.set(notesData, forKey: DefaultsKey.videoNotes)
            }
        }

        func persistPlaybackQueue() {
            let state = YouGlassPlaybackQueueState(videos: playbackQueue, autoplay: queueAutoplay)
            if let data = try? JSONEncoder().encode(state) {
                defaults.set(data, forKey: DefaultsKey.playbackQueue)
            }
        }

        func persistSubscriptions(_ items: [SubscriptionItem]) {
            guard !items.isEmpty else {
                defaults.removeObject(forKey: DefaultsKey.cachedSubscriptions)
                defaults.removeObject(forKey: DefaultsKey.cachedSubscriptionsDate)
                cachedSubscriptionsUpdatedAt = nil
                return
            }
            guard let data = try? JSONEncoder().encode(items) else { return }
            defaults.set(data, forKey: DefaultsKey.cachedSubscriptions)
            cachedSubscriptionsUpdatedAt = Date()
            defaults.set(cachedSubscriptionsUpdatedAt, forKey: DefaultsKey.cachedSubscriptionsDate)
        }

        func persistVideos(_ videos: [VideoItem], key: String) {
            if let data = try? JSONEncoder().encode(videos) {
                defaults.set(data, forKey: key)
            }
        }

        func recommendationQuery(for video: VideoItem) -> String {
            let titleWords = video.title
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 3 }
                .prefix(7)
                .joined(separator: " ")
            let history = recommendationSeeds.prefix(2).joined(separator: " ")
            return "\(video.channel) \(titleWords) \(history)".trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func mergeVideos(_ videos: [VideoItem]) -> [VideoItem] {
            videos.reduce(into: [VideoItem]()) { result, video in
                if !result.contains(where: { $0.id == video.id }) {
                    result.append(video)
                }
            }
        }

        func applyHomeVideos(_ videos: [VideoItem], message: String) {
            applyHomeVideos(videos, message: message, cacheFeed: true)
        }

        func applyHomeVideos(_ videos: [VideoItem], message: String, cacheFeed: Bool) {
            let merged = mergeVideos(videos)
            guard !merged.isEmpty else { return }
            sectionEmptyMessage = nil
            feed.hero = merged.first ?? feed.hero
            feed.forYou = Array(merged.prefix(8))
            feed.trending = Array(merged.dropFirst(8).prefix(8))
            feed.more = Array(merged.dropFirst(16).prefix(8))
            feed.queue = Array(merged.dropFirst(24).prefix(4))
            connectionMessage = message
            if cacheFeed, let data = try? JSONEncoder().encode(merged) {
                defaults.set(data, forKey: DefaultsKey.cachedFeed)
                let refreshedAt = Date()
                cachedFeedUpdatedAt = refreshedAt
                defaults.set(cachedFeedUpdatedAt, forKey: DefaultsKey.cachedFeedDate)
                feedLastRefreshedDate = refreshedAt
            }
        }

        @discardableResult
        func applyPrimaryHomeVideos(
            _ videos: [VideoItem],
            message: String,
            cacheFeed: Bool = true
        ) -> Bool {
            let ranked = RecommendationRanker.rank(
                videos,
                subscriptions: subscriptions,
                history: recentlyWatched,
                liked: locallyLikedVideos,
                seeds: recommendationSeeds,
                saved: savedVideos,
                limit: 40,
                excludeShortForm: hideShortsFromHome
            )
            guard !ranked.isEmpty else { return false }
            applyHomeVideos(ranked, message: message, cacheFeed: cacheFeed)
            return true
        }

        func cachePersonalizedFeed(_ videos: [VideoItem]) {
            let cacheCandidates = mergeVideos(videos).filter { video in
                !hideShortsFromHome || !video.isShortForm
            }
            guard let data = try? JSONEncoder().encode(Array(cacheCandidates.prefix(40))) else { return }
            defaults.set(data, forKey: DefaultsKey.cachedPersonalizedFeed)
            cachedPersonalizedFeedUpdatedAt = Date()
            defaults.set(cachedPersonalizedFeedUpdatedAt, forKey: DefaultsKey.cachedPersonalizedFeedDate)
        }

        func showEmptySection(_ message: String) {
            feed.forYou = []
            feed.trending = []
            feed.more = []
            feed.queue = []
            sectionEmptyMessage = message
            connectionMessage = message
        }
}
