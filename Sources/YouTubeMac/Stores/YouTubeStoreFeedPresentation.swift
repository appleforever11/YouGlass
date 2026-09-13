import Foundation

extension YouTubeStore {
        func applyHomeVideos(_ videos: [VideoItem], message: String) {
            applyHomeVideos(videos, message: message, cacheFeed: true)
        }

        func applyHomeVideos(_ videos: [VideoItem], message: String, cacheFeed: Bool) {
            let merged = mergeVideos(nonShortVideos(videos))
            guard !merged.isEmpty else { return }
            sectionEmptyMessage = nil
            feed.replaceVideos(merged)
            connectionMessage = message
            if cacheFeed, selectedSection == "Home", let data = try? JSONEncoder().encode(merged) {
                defaults.set(data, forKey: DefaultsKey.cachedFeed)
                let refreshedAt = Date()
                cachedFeedUpdatedAt = refreshedAt
                defaults.set(cachedFeedUpdatedAt, forKey: DefaultsKey.cachedFeedDate)
                feedLastRefreshedDate = refreshedAt
            }
        }

        func restoreHomeRecommendations() {
            let cached = decodeVideos(forKey: DefaultsKey.cachedFeed)
            guard !cached.isEmpty else { return }
            _ = applyPrimaryHomeVideos(cached, message: "Saved YouTube recommendations", cacheFeed: false,
                                       preserveSourceOrder: defaults.bool(forKey: "YouGlass.cachedHomePreservesYouTubeOrder"))
        }

        @discardableResult
        func applyPrimaryHomeVideos(
            _ videos: [VideoItem],
            message: String,
            cacheFeed: Bool = true,
            favorFresh: Bool = false,
            preserveSourceOrder: Bool = false
        ) -> Bool {
            let ranked = preserveSourceOrder ? Array(mergeVideos(nonShortVideos(videos)).prefix(40)) : RecommendationRanker.rank(
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
            homeRecommendationsAreFromYouTube = preserveSourceOrder
            if cacheFeed { defaults.set(preserveSourceOrder, forKey: "YouGlass.cachedHomePreservesYouTubeOrder") }
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
