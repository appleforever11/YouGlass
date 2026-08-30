import Foundation

struct YouGlassPlaybackQueueState: Codable, Equatable {
    var videos: [VideoItem]
    var autoplay = true
}

enum YouGlassPlaybackQueuePolicy {
    static let maxEntries = 24

    /// Keep an already-enqueued selection in place so the queue remains an
    /// ordered cursor for automatic next-video playback. New selections are
    /// inserted at the front and then followed by the existing catalog.
    static func prepare(
        for video: VideoItem,
        existingQueue: [VideoItem],
        source: [VideoItem]
    ) -> [VideoItem] {
        guard YouGlassContentPolicy.allows(video) else { return existingQueue }

        if existingQueue.contains(where: { $0.id == video.id }) {
            return Array(existingQueue.prefix(maxEntries))
        }

        var prepared: [VideoItem] = []
        for candidate in [video] + existingQueue + source {
            guard YouGlassContentPolicy.allows(candidate),
                  !prepared.contains(where: { $0.id == candidate.id }) else { continue }
            prepared.append(candidate)
            if prepared.count == maxEntries { break }
        }
        return prepared
    }
}
