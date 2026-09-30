import Foundation

/// Keeps the legacy key and payload fields readable by earlier app versions.
struct YouGlassQueueRepository {
    let defaults: UserDefaults
    let key: String

    func restore() -> YouGlassPlaybackQueueState? {
        guard let data = defaults.data(forKey: key),
              let state = try? JSONDecoder().decode(YouGlassPlaybackQueueState.self, from: data) else { return nil }
        return normalized(state)
    }

    func save(_ state: YouGlassPlaybackQueueState) {
        guard let data = try? JSONEncoder().encode(normalized(state)) else { return }
        defaults.set(data, forKey: key)
    }

    private func normalized(_ state: YouGlassPlaybackQueueState) -> YouGlassPlaybackQueueState {
        var seen = Set<String>()
        let videos = state.videos.filter {
            !$0.id.isEmpty && YouGlassContentPolicy.allows($0) && seen.insert($0.id).inserted
        }
        return .init(videos: Array(videos.prefix(YouGlassPlaybackQueuePolicy.maxEntries)), autoplay: state.autoplay)
    }
}
