import AppKit
import Foundation
import SwiftUI
@preconcurrency import WebKit

extension YouTubePlaybackController {
        func attach(to webView: WKWebView, video: VideoItem) {
            clearPictureInPictureFallback()
            self.webView = webView
            resetPublishedStateForAttachment()
            prepareAmbientPalette(for: video)
            YouGlassDiagnostics.breadcrumb(
                "playback",
                "Attached WebKit player surface",
                metadata: ["videoID": video.id]
            )
            status = "Player connected"
            startLoadWatchdog(for: video.id)
            schedulePlaybackBootstrap()
        }

        func detach(from webView: WKWebView) {
            // Deferred teardown of an older surface must not cancel the newly
            // attached compact or expanded surface's startup and watchdog.
            guard self.webView === webView else { return }
            self.webView = nil
            visualPaletteTask?.cancel()
            visualPaletteTask = nil
            cancelLoadWatchdog()
            cancelPlaybackBootstrap()
            clearPictureInPictureFallback()
        }

        func isAttached(to webView: WKWebView) -> Bool {
            self.webView === webView
        }

        func stopPlayback() {
            clearPictureInPictureFallback()
            cancelLoadWatchdog()
            cancelPlaybackBootstrap()
            loadGeneration &+= 1
            webView?.evaluateJavaScript("window.__youglassControls?.stopPlayback()", completionHandler: nil)
            isMuted = true
            isCaptionsEnabled = false
            captionText = ""
            isPlaying = false
            didFinish = false
            isPictureInPictureAvailable = false
            isPictureInPictureActive = false
            isSurfaceReady = false
            canRetry = false
            currentTime = 0
            duration = 0
            playbackRate = 1
            pendingResumeVideoID = nil
            pendingResumePosition = nil
            status = "Playback stopped"
        }

        func stopAndDetachDeferred(from webView: WKWebView) {
            // Pause without removing the media source. Removing src + calling
            // load() while WebKit is committing a layer tree is the crash-prone
            // part of the old teardown path.
            webView.evaluateJavaScript("window.__youglassControls?.stopPlayback()", completionHandler: nil)

            if self.webView === webView {
                clearPictureInPictureFallback()
                cancelLoadWatchdog()
                cancelPlaybackBootstrap()
                loadGeneration &+= 1
                self.webView = nil
                // Do not publish SwiftUI state from NSViewRepresentable teardown.
                // On macOS 26.6, dismantleNSView can run while NSHostingView is
                // destroying its AttributeGraph. Publishing here re-enters the
                // graph and aborts with a Swift exclusivity failure. The next
                // attachment resets the presentation state instead.
                activeVideoID = nil
                visualPaletteTask?.cancel()
                visualPaletteTask = nil
                pendingResumeVideoID = nil
                pendingResumePosition = nil
            }

            // Give the current SwiftUI transaction and WebKit remote layer commit
            // two main-loop turns before detaching delegates and script handlers.
            DispatchQueue.main.async { [weak self, weak webView] in
                DispatchQueue.main.async { [weak self, weak webView] in
                    guard let webView else { return }
                    webView.stopLoading()
                    webView.configuration.userContentController.removeScriptMessageHandler(forName: "youglassPlayback")
                    webView.navigationDelegate = nil
                    webView.uiDelegate = nil
                    self?.detach(from: webView)
                }
            }
        }

        func resetPublishedStateForAttachment() {
            isMuted = false
            isCaptionsEnabled = false
            captionText = ""
            isPlaying = false
            didFinish = false
            isPictureInPictureAvailable = false
            isPictureInPictureActive = false
            isSurfaceReady = false
            canRetry = false
            currentTime = 0
            duration = 0
            playbackRate = 1
            status = "Loading player..."
        }

        func prepareAmbientPalette(for video: VideoItem) {
            guard activeVideoID != video.id else { return }
            activeVideoID = video.id
            loadGeneration &+= 1
            canRetry = false
            cancelLoadWatchdog()
            cancelPlaybackBootstrap()
            visualPaletteTask?.cancel()
            ambientPalette = .neutral
            isSurfaceReady = false
            currentTime = 0
            duration = 0
            playbackRate = 1
            didFinish = false
            isCaptionsEnabled = false
            captionText = ""
            isPlaying = false
            status = "Loading player..."

            if pendingResumeVideoID != video.id {
                pendingResumeVideoID = nil
                pendingResumePosition = nil
            }

            guard let imageURL = video.imageURL else { return }
            visualPaletteTask = Task { @MainActor [weak self] in
                guard let data = try? await URLSession.shared.data(from: imageURL).0,
                      !Task.isCancelled,
                      let nextPalette = VideoAmbientPalette.from(imageData: data) else { return }
                guard let self, self.activeVideoID == video.id, !Task.isCancelled else { return }
                self.ambientPalette = nextPalette
            }
        }

        func didFinishNavigation(for webView: WKWebView) {
            guard self.webView === webView, activeVideoID != nil else { return }
            canRetry = false
            status = "Preparing player..."
            YouGlassDiagnostics.breadcrumb(
                "playback",
                "WebKit player navigation finished",
                metadata: ["videoID": activeVideoID ?? "unknown"]
            )
            startLoadWatchdog(for: activeVideoID)
            schedulePlaybackBootstrap()
        }

        func handleNavigationFailure(_ error: Error, for webView: WKWebView? = nil) {
            if let webView, self.webView !== webView {
                return
            }
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }
            cancelLoadWatchdog()
            cancelPlaybackBootstrap()
            isSurfaceReady = false
            canRetry = true
            status = "Playback unavailable"
            YouGlassDiagnostics.record(
                .warning,
                category: "playback",
                message: "WebKit player navigation failed",
                metadata: [
                    "videoID": activeVideoID ?? "unknown",
                    "domain": nsError.domain,
                    "code": String(nsError.code),
                    "error": nsError.localizedDescription
                ]
            )
        }

        func retryPlayback() {
            guard let webView, let activeVideoID else {
                status = "Player is not ready"
                canRetry = true
                return
            }

            loadGeneration &+= 1
            canRetry = false
            cancelPlaybackBootstrap()
            isPlaying = false
            isSurfaceReady = false
            currentTime = 0
            duration = 0
            status = "Retrying playback..."
            YouGlassDiagnostics.breadcrumb(
                "playback",
                "User requested playback retry",
                metadata: ["videoID": activeVideoID]
            )
            webView.reloadFromOrigin()
            startLoadWatchdog(for: activeVideoID)
            schedulePlaybackBootstrap()
        }
}
