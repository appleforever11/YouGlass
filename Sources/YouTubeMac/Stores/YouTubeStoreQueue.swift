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
        let source = playbackQueue.isEmpty
            ? feed.forYou + feed.trending + feed.more + feed.queue + recentlyWatched + savedVideos
            : playbackQueue + feed.forYou + feed.trending + feed.more + feed.queue
        let nextQueue = YouGlassPlaybackQueuePolicy.prepare(
            for: video,
            existingQueue: playbackQueue,
            source: source
        )
        guard nextQueue.map(\.id) != playbackQueue.map(\.id) else { return }
        playbackQueue = nextQueue
        persistPlaybackQueue()
    }

    func enqueue(_ video: VideoItem) {
        guard YouGlassContentPolicy.allows(video) else { return }
        playbackQueue.removeAll { $0.id == video.id }
        playbackQueue.append(video)
        playbackQueue = Array(playbackQueue.prefix(24))
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
