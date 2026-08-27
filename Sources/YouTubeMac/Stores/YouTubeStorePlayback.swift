import AppKit
import Foundation
import SwiftUI

extension YouTubeStore {
        func playbackPosition(for videoID: String) -> Double {
            let position = playbackPositions[videoID] ?? 0
            return position.isFinite ? max(0, position) : 0
        }

        func playbackDuration(for videoID: String) -> Double {
            let duration = playbackDurations[videoID] ?? 0
            return duration.isFinite ? max(0, duration) : 0
        }

        func playbackProgress(for video: VideoItem) -> Double {
            let duration = playbackDuration(for: video.id)
            guard duration > 0 else { return 0 }
            return min(max(playbackPosition(for: video.id) / duration, 0), 1)
        }

        var continueWatching: [VideoItem] {
            recentlyWatched.filter { video in
                let position = playbackPosition(for: video.id)
                let duration = playbackDuration(for: video.id)
                guard position > 1 else { return false }
                guard duration > 0 else { return true }
                return position / duration < PlaybackCheckpointPolicy.completionFraction
            }
        }

        func savePlaybackPosition(for video: VideoItem, at seconds: Double, duration: Double) {
            guard seconds.isFinite, seconds > 1 else { return }

            let safePosition = max(0, seconds)
            let hasFiniteDuration = duration.isFinite && duration > 0
            let isNearCompletion = hasFiniteDuration && (
                safePosition >= max(0, duration - PlaybackCheckpointPolicy.completionGraceSeconds) ||
                safePosition / duration >= PlaybackCheckpointPolicy.completionFraction
            )

            if isNearCompletion {
                playbackPositions.removeValue(forKey: video.id)
                playbackDurations.removeValue(forKey: video.id)
                playbackPositionUpdatedAt.removeValue(forKey: video.id)
            } else {
                playbackPositions[video.id] = hasFiniteDuration
                    ? min(safePosition, duration)
                    : safePosition
                if hasFiniteDuration {
                    playbackDurations[video.id] = duration
                }
                playbackPositionUpdatedAt[video.id] = Date()
            }

            // Keep the resume cache bounded so a long-lived account does not turn
            // playback checkpoints into unbounded UserDefaults data.
            if playbackPositions.count > PlaybackCheckpointPolicy.maxEntries {
                let excessCount = playbackPositions.count - PlaybackCheckpointPolicy.maxEntries
                let excessIDs = playbackPositions.keys.sorted { lhs, rhs in
                    let lhsDate = playbackPositionUpdatedAt[lhs] ?? .distantPast
                    let rhsDate = playbackPositionUpdatedAt[rhs] ?? .distantPast
                    if lhsDate == rhsDate { return lhs < rhs }
                    return lhsDate < rhsDate
                }.prefix(excessCount)
                excessIDs.forEach {
                    playbackPositions.removeValue(forKey: $0)
                    playbackDurations.removeValue(forKey: $0)
                    playbackPositionUpdatedAt.removeValue(forKey: $0)
                }
            }
            persistPlaybackPositions()
        }

        func clearPlaybackPosition(for video: VideoItem) {
            playbackPositions.removeValue(forKey: video.id)
            playbackDurations.removeValue(forKey: video.id)
            playbackPositionUpdatedAt.removeValue(forKey: video.id)
            persistPlaybackPositions()
        }

        func isSaved(_ video: VideoItem) -> Bool {
            savedVideos.contains { $0.id == video.id }
        }

        func toggleSaved(_ video: VideoItem) {
            if isSaved(video) {
                savedVideos.removeAll { $0.id == video.id }
            } else {
                savedVideos.insert(video, at: 0)
            }
            savedVideos = Array(savedVideos.prefix(100))
            persistVideos(savedVideos, key: DefaultsKey.savedVideos)
        }

        func isLocallyLiked(_ video: VideoItem) -> Bool {
            locallyLikedVideos.contains { $0.id == video.id }
        }

        func isSubscribed(channelID: String?, channelName: String) -> Bool {
            subscriptions.contains { subscription in
                subscription.matches(channelID: channelID, channelName: channelName)
            }
        }

        func resolveSubscriptionStatus(channelID: String?, channelName: String) async -> Bool {
            guard isSignedIn else { return false }
            await loadSubscriptions(force: false)
            return isSubscribed(channelID: channelID, channelName: channelName)
        }

        func recordLocalRating(for video: VideoItem, liked: Bool) {
            locallyLikedVideos.removeAll { $0.id == video.id }
            if liked { locallyLikedVideos.insert(video, at: 0) }
            locallyLikedVideos = Array(locallyLikedVideos.prefix(100))
            persistVideos(locallyLikedVideos, key: DefaultsKey.locallyLikedVideos)
        }
}
