import Foundation

struct YouGlassPlaybackQueueState: Codable, Equatable {
    var videos: [VideoItem]
    var autoplay = true
}

enum YouGlassPlaybackQueuePolicy {
    static let maxEntries = 24

    /// Keep an already-enqueued selection in place so the queue remains an
    /// ordered cursor for automatic next-video playback. When that queue is
    /// only a persisted selection, append the newly available source after it;
    /// new selections are inserted at the front and then followed by the
    /// existing queue and catalog.
    static func prepare(
        for video: VideoItem,
        existingQueue: [VideoItem],
        source: [VideoItem]
    ) -> [VideoItem] {
        guard YouGlassContentPolicy.allows(video) else { return existingQueue }

        var prepared: [VideoItem] = []
        let selectionIsAlreadyQueued = existingQueue.contains { $0.id == video.id }
        let candidates = selectionIsAlreadyQueued
            ? existingQueue + source
            : [video] + existingQueue + source
        for candidate in candidates {
            guard YouGlassContentPolicy.allows(candidate),
                  !prepared.contains(where: { $0.id == candidate.id }) else { continue }
            prepared.append(candidate)
            if prepared.count == maxEntries { break }
        }
        return prepared
    }
}
