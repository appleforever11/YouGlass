import Foundation

/// Refines the web session's suggestions using interests known to this app.
/// Stable groups preserve upstream order and make cache restoration idempotent.
enum HomeRecommendationPolicy {
    static func rank(
        _ videos: [VideoItem],
        subscriptions: [SubscriptionItem],
        history: [VideoItem],
        liked: [VideoItem],
        saved: [VideoItem],
        limit: Int = 40
    ) -> [VideoItem] {
        guard limit > 0 else { return [] }
        let signals = RecommendationSignals(history: history, liked: liked, saved: saved)
        let watched = Set(history.prefix(24).map(\.id))
        let deliberate = Set((liked + saved).map(\.id))
        var seen = Set<String>()
        var relevant: [VideoItem] = []
        var discovery: [VideoItem] = []
        var replays: [VideoItem] = []
        for video in videos where YouGlassContentPolicy.allows(video) && seen.insert(video.id).inserted {
            if watched.contains(video.id) && !deliberate.contains(video.id) {
                replays.append(video)
            } else if deliberate.contains(video.id) || signals.score(video) >= 6 ||
                        subscriptions.contains(where: {
                            $0.matches(channelID: video.channelID, channelName: video.channel)
                        }) {
                relevant.append(video)
            } else {
                discovery.append(video)
            }
        }
        return Array((relevant + discovery + replays).prefix(limit))
    }
}
