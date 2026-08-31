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
            guard YouGlassContentPolicy.allows(video) else { return }
            let seed = "\(video.channel) \(video.title)"
            recommendationSeeds.removeAll { $0 == seed }
            recommendationSeeds.insert(seed, at: 0)
            recommendationSeeds = Array(recommendationSeeds.prefix(6))
            defaults.set(recommendationSeeds, forKey: DefaultsKey.recommendationSeeds)
        }

        func rememberHistory(_ video: VideoItem) {
            guard YouGlassContentPolicy.allows(video) else { return }
            recentlyWatched.removeAll { $0.id == video.id }
            recentlyWatched.insert(video, at: 0)
            recentlyWatched = Array(recentlyWatched.prefix(100))
            persistVideos(recentlyWatched, key: DefaultsKey.recentlyWatched)
        }

        func decodeVideos(forKey key: String) -> [VideoItem] {
            guard let data = defaults.data(forKey: key),
                  let videos = try? JSONDecoder().decode([VideoItem].self, from: data) else { return [] }
            let filtered = nonShortVideos(videos)
            excludedShortFormIDs.formUnion(
                videos.filter { !YouGlassContentPolicy.allows($0) }.map(\.id)
            )
            if filtered.count != videos.count {
                persistVideos(filtered, key: key)
            }
            return filtered
        }

        func decodeRecommendationSeeds() -> [String] {
            let seeds = defaults.stringArray(forKey: DefaultsKey.recommendationSeeds) ?? []
            let filtered = seeds.filter { !YouGlassContentPolicy.isShortsText($0) }
            if filtered != seeds {
                defaults.set(filtered, forKey: DefaultsKey.recommendationSeeds)
            }
            return filtered
        }

        func decodeRecentlyPresentedRecommendationIDs() -> [String] {
            let ids = defaults.stringArray(forKey: DefaultsKey.recentlyPresentedRecommendationIDs) ?? []
            let filtered = Array(
                ids.filter { !$0.isEmpty }
                    .prefix(RecommendationRotationPolicy.rememberedRecommendationLimit)
            )
            if filtered != ids {
                defaults.set(filtered, forKey: DefaultsKey.recentlyPresentedRecommendationIDs)
            }
            return filtered
        }

        func nonShortVideos(_ videos: [VideoItem]) -> [VideoItem] {
            let filtered = YouGlassContentPolicy.nonShortVideos(from: videos)
            excludedShortFormIDs.formUnion(
                videos.filter { !YouGlassContentPolicy.allows($0) }.map(\.id)
            )
            return filtered
        }

        func decodePlaybackPositions() -> [String: Double] {
            guard let data = defaults.data(forKey: DefaultsKey.playbackPositions),
                  let positions = try? JSONDecoder().decode([String: Double].self, from: data) else {
                return [:]
            }
            return positions.filter {
                !$0.key.isEmpty
                    && !excludedShortFormIDs.contains($0.key)
                    && $0.value.isFinite
                    && $0.value > 0
            }
        }

        func decodePlaybackDurations() -> [String: Double] {
            guard let data = defaults.data(forKey: DefaultsKey.playbackDurations),
                  let durations = try? JSONDecoder().decode([String: Double].self, from: data) else {
                return [:]
            }
            return durations.filter {
                !excludedShortFormIDs.contains($0.key)
                    && $0.value.isFinite
                    && $0.value > 0
                    && playbackPositions[$0.key] != nil
            }
        }

        func decodePlaybackPositionDates() -> [String: Date] {
            guard let data = defaults.data(forKey: DefaultsKey.playbackPositionUpdatedAt),
                  let dates = try? JSONDecoder().decode([String: Date].self, from: data) else {
                return [:]
            }
            return dates.filter {
                !excludedShortFormIDs.contains($0.key)
                    && playbackPositions[$0.key] != nil
            }
        }

        func decodeSubscriptions() -> [SubscriptionItem] {
            guard let data = defaults.data(forKey: DefaultsKey.cachedSubscriptions),
                  let items = try? JSONDecoder().decode([SubscriptionItem].self, from: data) else {
                return []
            }
            return mergeSubscriptions(items)
        }

        func persistPlaybackPositions() {
            playbackPositions = playbackPositions.filter { !excludedShortFormIDs.contains($0.key) }
            playbackDurations = playbackDurations.filter { !excludedShortFormIDs.contains($0.key) }
            playbackPositionUpdatedAt = playbackPositionUpdatedAt.filter { !excludedShortFormIDs.contains($0.key) }
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
            var changed = false
            let filtered = collections.map { collection in
                var collection = collection
                let originalIDs = collection.videoIDs
                collection.videoIDs.removeAll { excludedShortFormIDs.contains($0) }
                changed = changed || originalIDs != collection.videoIDs
                return collection
            }
            let bounded = Array(filtered.prefix(40))
            if (changed || bounded.count != collections.count),
               let filteredData = try? JSONEncoder().encode(bounded) {
                defaults.set(filteredData, forKey: DefaultsKey.customCollections)
            }
            return bounded
        }

        func decodeVideoNotes() -> [YouGlassVideoNote] {
            guard let data = defaults.data(forKey: DefaultsKey.videoNotes),
                  let notes = try? JSONDecoder().decode([YouGlassVideoNote].self, from: data) else {
                return []
            }
            let filtered = notes.filter { !excludedShortFormIDs.contains($0.videoID) }
            let bounded = Array(filtered.prefix(200))
            if bounded.count != notes.count,
               let filteredData = try? JSONEncoder().encode(bounded) {
                defaults.set(filteredData, forKey: DefaultsKey.videoNotes)
            }
            return bounded
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
            playbackQueue = nonShortVideos(playbackQueue)
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
            if let data = try? JSONEncoder().encode(nonShortVideos(videos)) {
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
                guard YouGlassContentPolicy.allows(video) else { return }
                if !result.contains(where: { $0.id == video.id }) {
                    result.append(video)
                }
            }
        }

        func applyHomeVideos(_ videos: [VideoItem], message: String) {
            applyHomeVideos(videos, message: message, cacheFeed: true)
        }

        func applyHomeVideos(_ videos: [VideoItem], message: String, cacheFeed: Bool) {
            let merged = mergeVideos(nonShortVideos(videos))
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
            cacheFeed: Bool = true,
            favorFresh: Bool = false
        ) -> Bool {
            let ranked = RecommendationRanker.rank(
                videos,
                subscriptions: subscriptions,
                history: recentlyWatched,
                liked: locallyLikedVideos,
                seeds: recommendationSeeds,
                saved: savedVideos,
                recentlyPresentedIDs: favorFresh ? recentlyPresentedRecommendationIDs : [],
                favorFresh: favorFresh,
                limit: 40
            )
            guard !ranked.isEmpty else { return false }
            applyHomeVideos(ranked, message: message, cacheFeed: cacheFeed)
            if favorFresh {
                rememberPresentedRecommendations(feed.forYou)
            }
            return true
        }

        func rememberPresentedRecommendations(_ videos: [VideoItem]) {
            recentlyPresentedRecommendationIDs = RecommendationRotationPolicy.updatedRecentlyPresentedIDs(
                previous: recentlyPresentedRecommendationIDs,
                displayed: videos
            )
            defaults.set(
                recentlyPresentedRecommendationIDs,
                forKey: DefaultsKey.recentlyPresentedRecommendationIDs
            )
        }

        func clearRecentlyPresentedRecommendations() {
            recentlyPresentedRecommendationIDs = []
            defaults.removeObject(forKey: DefaultsKey.recentlyPresentedRecommendationIDs)
        }

        func cachePersonalizedFeed(_ videos: [VideoItem]) {
            let cacheCandidates = mergeVideos(nonShortVideos(videos))
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
