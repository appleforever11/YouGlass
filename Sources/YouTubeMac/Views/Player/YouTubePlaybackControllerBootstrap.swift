import AppKit
import Foundation
import SwiftUI
@preconcurrency import WebKit

extension YouTubePlaybackController {
        func run(_ script: String) {
            guard let webView else {
                logger.error("control command dropped because WebKit is detached")
                status = "Player is not ready"
                return
            }

            // SwiftUI can reveal the native toolbar one frame before the
            // document-end script has installed __youglassControls. Optional
            // chaining alone makes that click disappear without an error. Wait
            // briefly for the bridge. The native event bridge remains the
            // authoritative state path; avoiding a Swift completion block here
            // also prevents a macOS 27 WebKit callback trap during teardown.
            let command = """
            (() => {
              const execute = () => {
                if (!window.__youglassControls) return false;
                \(script)
                return true;
              };
              if (execute()) return true;
              return new Promise(resolve => {
                let attempts = 0;
                const timer = window.setInterval(() => {
                  attempts += 1;
                  if (execute() || attempts >= 24) {
                    window.clearInterval(timer);
                    resolve(attempts < 24);
                  }
                }, 30);
              });
            })()
            """

            webView.evaluateJavaScript(command, completionHandler: nil)
        }

        func startLoadWatchdog(for videoID: String?) {
            cancelLoadWatchdog()
            guard let videoID else { return }
            let generation = loadGeneration
            loadWatchdogTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard let self,
                      !Task.isCancelled,
                      self.loadGeneration == generation,
                      self.activeVideoID == videoID,
                      self.webView != nil,
                      !self.isSurfaceReady else { return }
                self.status = "Video frame did not load"
                self.canRetry = true
                YouGlassDiagnostics.record(
                    .warning,
                    category: "playback",
                    message: "Player surface watchdog timed out",
                    metadata: ["videoID": videoID]
                )
            }
        }

        func schedulePlaybackBootstrap() {
            cancelPlaybackBootstrap()

            guard let videoID = activeVideoID, webView != nil else { return }
            let generation = loadGeneration
            // Start as soon as the native surface exists. The retry schedule below
            // handles the short interval before YouTube creates its media element.
            // This removes the avoidable quarter-second delay on the first click
            // without bypassing the muted autoplay policy.
            run("window.__youglassControls?.startPlayback()")
            playbackBootstrapTask = Task { @MainActor [weak self] in
                let delays: [UInt64] = [
                    80_000_000,
                    220_000_000,
                    500_000_000,
                    900_000_000,
                    1_600_000_000,
                    2_800_000_000,
                    4_500_000_000,
                    6_500_000_000,
                    8_000_000_000
                ]

                for delay in delays {
                    try? await Task.sleep(nanoseconds: delay)
                    guard !Task.isCancelled, let self else { return }
                    guard self.loadGeneration == generation,
                          self.activeVideoID == videoID,
                          self.webView != nil,
                          !self.isSurfaceReady,
                          !self.canRetry else { return }

                    self.run("window.__youglassControls?.startPlayback()")
                }

                if !Task.isCancelled {
                    self?.playbackBootstrapTask = nil
                }
            }
        }

        func cancelPlaybackBootstrap() {
            playbackBootstrapTask?.cancel()
            playbackBootstrapTask = nil
        }

        func cancelLoadWatchdog() {
            loadWatchdogTask?.cancel()
            loadWatchdogTask = nil
        }

        func applyPendingResumeIfReady() {
            guard let pendingResumeVideoID,
                  pendingResumeVideoID == activeVideoID,
                  let pendingResumePosition,
                  pendingResumePosition.isFinite,
                  duration > 0,
                  webView != nil else { return }

            let target = max(0, min(duration, pendingResumePosition))
            self.pendingResumeVideoID = nil
            self.pendingResumePosition = nil
            currentTime = target
            status = "Resuming playback"
            run("window.__youglassControls?.seekTo(\(target))")
        }

        func clearPictureInPictureFallback() {
            pictureInPictureFallbackTask?.cancel()
            pictureInPictureFallbackTask = nil
            pictureInPictureFallback = nil
        }
}
