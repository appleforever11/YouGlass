import AppKit
import Foundation
import SwiftUI
@preconcurrency import WebKit

extension YouTubePlaybackController {
        func togglePlayback() {
            logger.notice("toggle playback requested")
            cancelPlaybackBootstrap()
            run("window.__youglassControls?.togglePlayback()")
        }

        func toggleMute() {
            logger.notice("toggle mute requested")
            run("window.__youglassControls?.toggleMute()")
        }

        func toggleCaptions() {
            logger.notice("toggle captions requested")
            run("window.__youglassControls?.toggleCaptions()")
        }

        func applyAudioPolicy(autoMuteOnStart: Bool) {
            run("window.__youglassControls?.applyAudioPolicy(\(autoMuteOnStart ? "true" : "false"))")
        }

        func seek(by seconds: Double) {
            logger.notice("seek requested seconds=\(seconds, privacy: .public)")
            run("window.__youglassControls?.seekBy(\(seconds))")
        }

        func seek(to seconds: Double) {
            let target = max(0, min(duration > 0 ? duration : seconds, seconds))
            currentTime = target
            run("window.__youglassControls?.seekTo(\(target))")
        }

        func setPlaybackRate(_ rate: Double) {
            let boundedRate = min(max(rate, 0.25), 2.0)
            playbackRate = boundedRate
            run("window.__youglassControls?.setPlaybackRate(\(boundedRate))")
        }

        func togglePictureInPicture() {
            logger.notice("toggle picture in picture requested")
            run("window.__youglassControls?.togglePictureInPicture()")
        }

        /// Requests system PiP first, then moves the player into YouGlass's
        /// in-app mini-player if WebKit rejects or fails to start the request.
        func togglePictureInPicture(fallback: @escaping () -> Void) {
            guard !isPictureInPictureActive else {
                clearPictureInPictureFallback()
                togglePictureInPicture()
                return
            }

            guard webView != nil else {
                fallback()
                return
            }

            clearPictureInPictureFallback()
            pictureInPictureFallback = fallback
            run("window.__youglassControls?.togglePictureInPicture()")

            pictureInPictureFallbackTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard let self, !Task.isCancelled, !self.isPictureInPictureActive else { return }
                let fallback = self.pictureInPictureFallback
                self.clearPictureInPictureFallback()
                fallback?()
            }
        }

        func update(from payload: [String: Any]) {
            // WebKit can finish dispatching a callback from the previous watch
            // page after a new video has already been selected. Those late
            // callbacks used to mark the new surface ready while it still showed
            // the previous video's frame. Require the page identity before
            // allowing media state to affect SwiftUI.
            guard let activeVideoID else {
                return
            }

            // Embed pages can emit their first media event before YouTube has
            // finished publishing the URL/config object that contains the video
            // id. Do not discard otherwise valid duration/playback state in that
            // short window. Still reject a concrete id from an old page.
            if let payloadVideoID = payload["videoID"] as? String,
               !payloadVideoID.isEmpty,
               payloadVideoID != activeVideoID {
                return
            }

            let frameReady = payload["frameReady"] as? Bool

            if let value = payload["muted"] as? Bool, isMuted != value { isMuted = value }
            if let value = payload["captionsEnabled"] as? Bool {
                if isCaptionsEnabled != value { isCaptionsEnabled = value }
            }
            let captionStatus = (payload["status"] as? String)?.lowercased() ?? ""
            let explicitlyClearsCaption = captionStatus.contains("captions off") ||
                captionStatus.contains("no captions available")
            if let value = payload["captionText"] as? String,
               !value.isEmpty || (payload["captionsEnabled"] as? Bool) != false || explicitlyClearsCaption {
                // A caption-state poll can briefly report disabled while the
                // active YouTube track is still rendering. Do not erase the
                // last visible line from that transient empty payload; an
                // enabled empty update and explicit off/no-track status still
                // clear it normally.
                if captionText != value { captionText = value }
            }
            if let value = payload["playing"] as? Bool, isPlaying != value { isPlaying = value }
            if let value = payload["ended"] as? Bool {
                if didFinish != value { didFinish = value }
            }
            if let value = payload["pipAvailable"] as? Bool, isPictureInPictureAvailable != value { isPictureInPictureAvailable = value }
            if let value = payload["pipActive"] as? Bool {
                if isPictureInPictureActive != value { isPictureInPictureActive = value }
                if value { clearPictureInPictureFallback() }
            }
            if frameReady == true {
                cancelPlaybackBootstrap()
            }

            var statusIndicatesFailure = false
            if let value = payload["status"] as? String, !value.isEmpty {
                if status != value { status = value }
                let lowercased = value.lowercased()
                let isCaptionStatus = lowercased.contains("caption")
                if lowercased.contains("captions off") || lowercased.contains("no captions available") {
                    captionText = ""
                }
                statusIndicatesFailure = lowercased.contains("blocked") ||
                    lowercased.contains("not allowed")
                if lowercased.contains("picture in picture is unavailable") ||
                    lowercased.contains("picture in picture could not start") {
                    let fallback = pictureInPictureFallback
                    clearPictureInPictureFallback()
                    fallback?()
                }
                if !isCaptionStatus && (
                    lowercased.contains("error") ||
                    lowercased.contains("unavailable") ||
                    lowercased.contains("failed") ||
                    lowercased.contains("did not load") ||
                    statusIndicatesFailure
                ) {
                    canRetry = true
                    cancelLoadWatchdog()
                    cancelPlaybackBootstrap()
                }
            }
            if let value = payload["currentTime"] as? NSNumber, value.doubleValue.isFinite,
               currentTime != max(0, value.doubleValue) { currentTime = max(0, value.doubleValue) }
            if let value = payload["duration"] as? NSNumber, value.doubleValue.isFinite,
               duration != max(0, value.doubleValue) { duration = max(0, value.doubleValue) }
            if let value = payload["playbackRate"] as? NSNumber,
               value.doubleValue.isFinite,
               value.doubleValue > 0 {
                if playbackRate != value.doubleValue { playbackRate = value.doubleValue }
            }
            // Partial bridge messages, such as caption-text updates, do not
            // describe frame readiness. Preserve the last known media state
            // instead of swapping the live WebKit surface for its thumbnail.
            if let frameReady {
                if isSurfaceReady != frameReady { isSurfaceReady = frameReady }
                if frameReady {
                    if canRetry { canRetry = false }
                    cancelLoadWatchdog()
                }
            }
            applyPendingResumeIfReady()
        }

        /// Queues a saved position until the YouTube media element reports a real
        /// duration. The WebView can be created after SwiftUI's onAppear callback,
        /// so applying the seek immediately would otherwise be lost on navigation.
        func restorePlaybackPosition(_ seconds: Double, for videoID: String) {
            guard seconds.isFinite, seconds > 0 else {
                pendingResumeVideoID = nil
                pendingResumePosition = nil
                return
            }

            pendingResumeVideoID = videoID
            pendingResumePosition = seconds
            applyPendingResumeIfReady()
        }
}
