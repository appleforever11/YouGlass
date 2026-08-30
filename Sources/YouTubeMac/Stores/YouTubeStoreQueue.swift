import Foundation

extension YouTubeStore {
    var currentQueueIndex: Int? {
        guard let selectedVideo else { return nil }
        return playbackQueue.firstIndex { $0.id == selectedVideo.id }
    }

    var nextQueuedVideo: VideoItem? {
        guard let index = currentQueueIndex else { return nil }
        let nextIndex = playbackQueue.index(after: index)
        return playbackQueue.indices.contains(nextIndex) ? playbackQueue[nextIndex] : nil
    }

    var previousQueuedVideo: VideoItem? {
        guard let index = currentQueueIndex, index > playbackQueue.startIndex else { return nil }
        return playbackQueue[playbackQueue.index(before: index)]
    }

    func preparePlaybackQueue(for video: VideoItem) {
        guard YouGlassContentPolicy.allows(video) else { return }
        let source = feed.forYou + feed.trending + feed.more + feed.queue + recentlyWatched + savedVideos
        let nextQueue = YouGlassPlaybackQueuePolicy.prepare(
            for: video,
            existingQueue: playbackQueue,
            source: source
        )
        guard nextQueue.map(\.id) != playbackQueue.map(\.id) else { return }
        playbackQueue = nextQueue
        persistPlaybackQueue()
    }

    /// Recommendations can finish loading after the player has already
    /// started. Append them after the current queue so an early one-item
    /// persisted queue still has a next item when the media reaches `ended`.
    /// If the bounded queue is full, discard only entries before the current
    /// cursor when there is room to retain newly loaded candidates.
    func appendPlaybackCandidates(_ candidates: [VideoItem]) {
        let additions = mergeVideos(candidates).filter { candidate in
            !playbackQueue.contains { $0.id == candidate.id }
        }
        guard !additions.isEmpty else { return }

        var nextQueue = playbackQueue
        if let selectedVideo,
           let currentIndex = nextQueue.firstIndex(where: { $0.id == selectedVideo.id }),
           nextQueue.count + additions.count > YouGlassPlaybackQueuePolicy.maxEntries {
            nextQueue = Array(nextQueue[currentIndex...])
        }
        nextQueue.append(contentsOf: additions)
        nextQueue = Array(nextQueue.prefix(YouGlassPlaybackQueuePolicy.maxEntries))

        guard nextQueue.map(\.id) != playbackQueue.map(\.id) else { return }
        playbackQueue = nextQueue
        persistPlaybackQueue()
    }

    func enqueue(_ video: VideoItem) {
        guard YouGlassContentPolicy.allows(video) else { return }
        playbackQueue.removeAll { $0.id == video.id }
        playbackQueue.append(video)
        playbackQueue = Array(playbackQueue.prefix(YouGlassPlaybackQueuePolicy.maxEntries))
        persistPlaybackQueue()
    }

    func enqueueNext(_ video: VideoItem) {
        let nextQueue = YouGlassPlaybackQueuePolicy.insertingNext(
            video,
            into: playbackQueue,
            currentVideoID: selectedVideo?.id
        )
        guard nextQueue.map(\.id) != playbackQueue.map(\.id) else { return }
        playbackQueue = nextQueue
        persistPlaybackQueue()
    }

    func removeFromPlaybackQueue(_ video: VideoItem) {
        playbackQueue.removeAll { $0.id == video.id }
        if playbackQueue.isEmpty, let selectedVideo {
            playbackQueue = [selectedVideo]
        }
        persistPlaybackQueue()
    }

    func clearPlaybackQueue(keepingCurrent: Bool = true) {
        playbackQueue = keepingCurrent ? selectedVideo.map { [$0] } ?? [] : []
        persistPlaybackQueue()
    }

    func setQueueAutoplay(_ enabled: Bool) {
        queueAutoplay = enabled
        persistPlaybackQueue()
    }

    func playNextInQueue() {
        guard let nextQueuedVideo else {
            connectionMessage = "Queue finished"
            return
        }
        openFromUserInteraction(nextQueuedVideo)
    }

    func playPreviousInQueue() {
        guard let previousQueuedVideo else {
            connectionMessage = "Already at the start of the queue"
            return
        }
        openFromUserInteraction(previousQueuedVideo)
    }
}
