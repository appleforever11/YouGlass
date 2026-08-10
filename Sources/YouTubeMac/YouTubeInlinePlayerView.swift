import AppKit
import Foundation
import SwiftUI
@preconcurrency import WebKit

@MainActor
final class YouTubePlaybackController: ObservableObject {
    @Published private(set) var isMuted = false
    @Published private(set) var isCaptionsEnabled = false
    @Published private(set) var isPlaying = false
    @Published private(set) var isPictureInPictureAvailable = false
    @Published private(set) var isPictureInPictureActive = false
    @Published private(set) var isSurfaceReady = false
    @Published private(set) var status = "Loading player..."
    @Published private(set) var canRetry = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var ambientPalette = VideoAmbientPalette.neutral

    private weak var webView: WKWebView?
    private var visualPaletteTask: Task<Void, Never>?
    private var ambientSamplingTask: Task<Void, Never>?
    private var activeVideoID: String?
    private var pendingResumeVideoID: String?
    private var pendingResumePosition: Double?
    private var snapshotInFlight = false
    private var pictureInPictureFallback: (() -> Void)?
    private var pictureInPictureFallbackTask: Task<Void, Never>?
    private var loadWatchdogTask: Task<Void, Never>?
    private var loadGeneration = 0
    private var isAttached = false

    func attach(to webView: WKWebView, video: VideoItem) {
        clearPictureInPictureFallback()
        self.webView = webView
        isAttached = true
        prepareAmbientPalette(for: video)
        startAmbientSampling()
        isSurfaceReady = false
        status = "Player connected"
        startLoadWatchdog(for: video.id)
    }

    func detach(from webView: WKWebView) {
        if self.webView === webView {
            self.webView = nil
            isAttached = false
        }
        visualPaletteTask?.cancel()
        visualPaletteTask = nil
        ambientSamplingTask?.cancel()
        ambientSamplingTask = nil
        cancelLoadWatchdog()
        snapshotInFlight = false
        clearPictureInPictureFallback()
    }

    func stopPlayback() {
        clearPictureInPictureFallback()
        cancelLoadWatchdog()
        loadGeneration &+= 1
        webView?.evaluateJavaScript("window.__youglassControls?.stopPlayback()", completionHandler: nil)
        isMuted = true
        isCaptionsEnabled = false
        isPlaying = false
        isPictureInPictureAvailable = false
        isPictureInPictureActive = false
        isSurfaceReady = false
        canRetry = false
        currentTime = 0
        duration = 0
        pendingResumeVideoID = nil
        pendingResumePosition = nil
        status = "Playback stopped"
    }

    func stopAndDetach(from webView: WKWebView) {
        // Do not call into WebKit synchronously while SwiftUI/AppKit is dismantling the view.
        // macOS 26 can be committing a remote layer tree at this point; local detachment is safe,
        // while stopLoading/evaluateJavaScript are deferred by the representable.
        detach(from: webView)
    }

    func prepareAmbientPalette(for video: VideoItem) {
        guard activeVideoID != video.id else { return }
        activeVideoID = video.id
        loadGeneration &+= 1
        canRetry = false
        cancelLoadWatchdog()
        visualPaletteTask?.cancel()
        ambientPalette = .neutral
        isSurfaceReady = false
        currentTime = 0
        duration = 0
        isCaptionsEnabled = false
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

    func didFinishNavigation() {
        guard activeVideoID != nil else { return }
        canRetry = false
        status = "Preparing player..."
        startLoadWatchdog(for: activeVideoID)
    }

    func handleNavigationFailure(_ error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }
        cancelLoadWatchdog()
        isSurfaceReady = false
        canRetry = true
        status = "Playback unavailable"
    }

    func retryPlayback() {
        guard let webView, let activeVideoID else {
            status = "Player is not ready"
            canRetry = true
            return
        }

        loadGeneration &+= 1
        canRetry = false
        isPlaying = false
        isSurfaceReady = false
        currentTime = 0
        duration = 0
        status = "Retrying playback..."
        webView.reload()
        startLoadWatchdog(for: activeVideoID)
    }

    func togglePlayback() {
        run("window.__youglassControls?.togglePlayback()")
    }

    func toggleMute() {
        run("window.__youglassControls?.toggleMute()")
    }

    func toggleCaptions() {
        run("window.__youglassControls?.toggleCaptions()")
    }

    func applyAudioPolicy(autoMuteOnStart: Bool) {
        run("window.__youglassControls?.applyAudioPolicy(\(autoMuteOnStart ? "true" : "false"))")
    }

    func seek(by seconds: Double) {
        run("window.__youglassControls?.seekBy(\(seconds))")
    }

    func seek(to seconds: Double) {
        let target = max(0, min(duration > 0 ? duration : seconds, seconds))
        currentTime = target
        run("window.__youglassControls?.seekTo(\(target))")
    }

    func togglePictureInPicture() {
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
        guard let activeVideoID,
              let payloadVideoID = payload["videoID"] as? String,
              payloadVideoID == activeVideoID else {
            return
        }

        if let value = payload["muted"] as? Bool { isMuted = value }
        if let value = payload["captionsEnabled"] as? Bool { isCaptionsEnabled = value }
        if let value = payload["playing"] as? Bool { isPlaying = value }
        if let value = payload["pipAvailable"] as? Bool { isPictureInPictureAvailable = value }
        if let value = payload["pipActive"] as? Bool {
            isPictureInPictureActive = value
            if value { clearPictureInPictureFallback() }
        }
        if let value = payload["status"] as? String, !value.isEmpty {
            status = value
            let lowercased = value.lowercased()
            if lowercased.contains("picture in picture is unavailable") ||
                lowercased.contains("picture in picture could not start") {
                let fallback = pictureInPictureFallback
                clearPictureInPictureFallback()
                fallback?()
            }
            if lowercased.contains("error") ||
                lowercased.contains("unavailable") ||
                lowercased.contains("failed") ||
                lowercased.contains("did not load") {
                canRetry = true
                cancelLoadWatchdog()
            }
        }
        if let value = payload["currentTime"] as? NSNumber { currentTime = max(0, value.doubleValue) }
        if let value = payload["duration"] as? NSNumber { duration = max(0, value.doubleValue) }
        if isPlaying || duration > 0 {
            isSurfaceReady = true
            canRetry = false
            cancelLoadWatchdog()
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

    private func startAmbientSampling() {
        ambientSamplingTask?.cancel()
        ambientSamplingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.sampleLiveFrame()
                try? await Task.sleep(nanoseconds: 3_500_000_000)
            }
        }
    }

    private func sampleLiveFrame() {
        guard isAttached, isPlaying, !snapshotInFlight, let webView else { return }
        snapshotInFlight = true
        let snapshotWebView = webView

        let configuration = WKSnapshotConfiguration()
        configuration.rect = snapshotWebView.bounds
        snapshotWebView.takeSnapshot(with: configuration) { [weak self, weak snapshotWebView] image, _ in
            let nextPalette = image.flatMap { VideoAmbientPalette.from(image: $0) }
            Task { @MainActor [weak self] in
                guard let self,
                      self.isAttached,
                      let snapshotWebView,
                      self.webView === snapshotWebView else { return }
                self.snapshotInFlight = false
                if let nextPalette {
                    self.ambientPalette = nextPalette
                }
            }
        }
    }

    private func run(_ script: String) {
        guard let webView else {
            status = "Player is not ready"
            return
        }
        webView.evaluateJavaScript(script) { [weak self] _, error in
            guard error != nil else { return }
            Task { @MainActor in
                self?.status = "Playback error"
                self?.canRetry = true
                self?.cancelLoadWatchdog()
            }
        }
    }

    private func startLoadWatchdog(for videoID: String?) {
        cancelLoadWatchdog()
        guard let videoID else { return }
        let generation = loadGeneration
        loadWatchdogTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard let self,
                  !Task.isCancelled,
                  self.loadGeneration == generation,
                  self.activeVideoID == videoID,
                  self.webView != nil,
                  !self.isPlaying,
                  self.duration <= 0 else { return }
            self.status = "Playback did not load"
            self.canRetry = true
        }
    }

    private func cancelLoadWatchdog() {
        loadWatchdogTask?.cancel()
        loadWatchdogTask = nil
    }

    private func applyPendingResumeIfReady() {
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

    private func clearPictureInPictureFallback() {
        pictureInPictureFallbackTask?.cancel()
        pictureInPictureFallbackTask = nil
        pictureInPictureFallback = nil
    }
}

private struct AmbientSample {
    let color: VideoAmbientColor
    let saturation: Double
    let luminance: Double
    let weight: Double
    let horizontalPosition: Double
}

fileprivate extension VideoAmbientPalette {
    static func from(imageData: Data) -> VideoAmbientPalette? {
        guard let image = NSImage(data: imageData) else { return nil }
        return from(image: image)
    }

    static func from(image: NSImage) -> VideoAmbientPalette? {
        var proposedRect = NSRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(
            forProposedRect: &proposedRect,
            context: nil,
            hints: nil
        ) else { return nil }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        guard width > 0, height > 0 else { return nil }

        var samples: [AmbientSample] = []
        let columns = 12
        let rows = 8

        for row in 0..<rows {
            let y = min(height - 1, max(0, Int((Double(row) + 0.5) / Double(rows) * Double(height))))
            for column in 0..<columns {
                let x = min(width - 1, max(0, Int((Double(column) + 0.5) / Double(columns) * Double(width))))
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }

                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                var alpha: CGFloat = 0
                color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

                let components = [Double(red), Double(green), Double(blue)]
                let brightest = components.max() ?? 0
                let darkest = components.min() ?? 0
                guard brightest > 0.035, alpha > 0.01 else { continue }

                let saturation = brightest == 0 ? 0 : (brightest - darkest) / brightest
                let luminance = 0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue)
                let weight = (0.35 + saturation * 1.8) * (0.55 + min(luminance, 0.9))
                samples.append(
                    AmbientSample(
                        color: VideoAmbientColor(red: Double(red), green: Double(green), blue: Double(blue)),
                        saturation: saturation,
                        luminance: luminance,
                        weight: weight,
                        horizontalPosition: Double(column) / Double(max(columns - 1, 1))
                    )
                )
            }
        }

        guard !samples.isEmpty else { return nil }

        let primary = boosted(average(samples), saturation: 1.08)
        let rightSamples = samples.filter { $0.horizontalPosition > 0.42 }
        let secondary = boosted(average(rightSamples.isEmpty ? samples : rightSamples), saturation: 1.14)
        let accentSamples = Array(samples.sorted { $0.saturation > $1.saturation }.prefix(max(4, samples.count / 5)))
        let accent = boosted(average(accentSamples), saturation: 1.28)
        let averageSaturation = samples.reduce(0.0) { $0 + $1.saturation } / Double(samples.count)
        let averageContrast = samples.reduce(0.0) { $0 + abs($1.luminance - 0.5) } / Double(samples.count)

        return VideoAmbientPalette(
            primary: primary,
            secondary: secondary,
            accent: accent,
            energy: min(1, max(0, averageSaturation * 0.72 + averageContrast * 0.48))
        )
    }

    private static func average(_ samples: [AmbientSample]) -> VideoAmbientColor {
        guard !samples.isEmpty else { return neutral.primary }
        let totalWeight = max(samples.reduce(0.0) { $0 + $1.weight }, 0.001)
        return VideoAmbientColor(
            red: samples.reduce(0.0) { $0 + $1.color.red * $1.weight } / totalWeight,
            green: samples.reduce(0.0) { $0 + $1.color.green * $1.weight } / totalWeight,
            blue: samples.reduce(0.0) { $0 + $1.color.blue * $1.weight } / totalWeight
        )
    }

    private static func boosted(_ color: VideoAmbientColor, saturation: Double) -> VideoAmbientColor {
        let luminance = color.red * 0.2126 + color.green * 0.7152 + color.blue * 0.0722
        return VideoAmbientColor(
            red: min(1, max(0, luminance + (color.red - luminance) * saturation)),
            green: min(1, max(0, luminance + (color.green - luminance) * saturation)),
            blue: min(1, max(0, luminance + (color.blue - luminance) * saturation))
        )
    }
}

/// Hosts YouTube's supported watch client inside the native player surface.
struct YouTubeInlinePlayerView: NSViewRepresentable {
    let video: VideoItem
    let controller: YouTubePlaybackController
    let autoMuteOnStart: Bool

    // Keep WebKit's first paint dark while YouTube builds its client-rendered
    // player. The native thumbnail remains visible until a real media frame
    // is reported, so the watch layout never flashes a white page.
    private static let initialSurfaceScript = """
    (() => {
      const styleID = 'youglass-initial-surface-style';
      const styleText = `
        html, body {
          background: #000 !important;
          margin: 0 !important;
        }
      `;
      const install = () => {
        const root = document.documentElement;
        if (!root) return;
        root.style.backgroundColor = '#000';
        let style = document.getElementById(styleID);
        if (!style) {
          style = document.createElement('style');
          style.id = styleID;
          (document.head || root).appendChild(style);
        }
        if (style.textContent !== styleText) style.textContent = styleText;
      };
      install();
      document.addEventListener('DOMContentLoaded', install, { once: true });
    })();
    """

    private static let playerChromeScript = """
    (() => {
      const styleID = 'youglass-player-style';
      const styleText = `
        html, body {
          background: #000 !important;
          margin: 0 !important;
          width: 100% !important;
          height: 100% !important;
          overflow: hidden !important;
        }
        ytd-masthead,
        #masthead-container,
        #guide,
        ytd-mini-guide-renderer,
        #secondary,
        #below,
        #comments,
        #chat,
        #related,
        ytd-watch-next-secondary-results-renderer,
        ytd-watch-metadata,
        #owner,
        #actions,
        #description,
        .ytp-chrome-top,
        .ytp-chrome-bottom,
        .ytp-gradient-top,
        .ytp-gradient-bottom,
        .ytp-title,
        .ytp-watermark,
        .ytp-paid-content-overlay,
        .ytp-pause-overlay,
        .ytp-cards-teaser,
        .ytp-ce-element,
        .ytp-endscreen-content,
        .ytp-show-cards-title,
        .ytp-tooltip,
        .ytp-popup,
        .ytp-contextmenu,
        .ytp-cued-thumbnail-overlay,
        .ytp-spinner,
        .ytp-bezel,
        .ytp-bezel-text-wrapper,
        .ytp-doubletap-ui,
        .ytp-doubletap-ui-legacy,
        .ytp-suggested-action,
        .ytp-featured-product {
          display: none !important;
        }
        ytd-app,
        #page-manager,
        ytd-watch-flexy,
        #content,
        #columns,
        #primary,
        #primary-inner,
        ytd-player,
        #full-bleed-container,
        #player-container-outer,
        #player-container,
        #player-container-inner,
        #player,
        #movie_player,
        #player-full-bleed-container {
          width: 100% !important;
          height: 100% !important;
          max-width: none !important;
          max-height: none !important;
          min-width: 0 !important;
          min-height: 0 !important;
          aspect-ratio: auto !important;
          margin: 0 !important;
        }
        #columns,
        #primary,
        #primary-inner,
        ytd-player,
        #full-bleed-container,
        #player-container-outer,
        #player-container,
        #player-container-inner,
        #player,
        #movie_player,
        #player-full-bleed-container {
          display: block !important;
          padding: 0 !important;
        }
        #player-container-outer,
        #full-bleed-container,
        #player-container,
        #player-container-inner,
        #player,
        #movie_player,
        #player-full-bleed-container,
        .html5-video-container,
        .html5-main-video {
          height: 100% !important;
          min-height: 0 !important;
          max-height: none !important;
          aspect-ratio: auto !important;
          background: #000 !important;
        }
        #full-bleed-container,
        #player-container-outer,
        #player-container,
        #player-container-inner,
        #player,
        #movie_player,
        #player-full-bleed-container {
          position: relative !important;
          inset: auto !important;
        }
        #movie_player,
        .html5-video-player {
          position: relative !important;
          overflow: hidden !important;
        }
        #movie_player .html5-video-container,
        .html5-video-player .html5-video-container {
          position: absolute !important;
          inset: 0 !important;
          top: 0 !important;
          left: 0 !important;
          width: 100% !important;
          height: 100% !important;
          min-height: 0 !important;
          max-height: none !important;
          aspect-ratio: auto !important;
          display: flex !important;
          align-items: center !important;
          justify-content: center !important;
          overflow: hidden !important;
        }
        #movie_player video,
        .html5-main-video,
        video.video-stream.html5-main-video {
          position: absolute !important;
          inset: 0 !important;
          top: 0 !important;
          left: 0 !important;
          right: 0 !important;
          bottom: 0 !important;
          margin: auto !important;
          width: 100% !important;
          height: 100% !important;
          min-height: 0 !important;
          max-height: none !important;
          display: block !important;
          object-fit: contain !important;
          object-position: center center !important;
          transform: none !important;
        }
      `;

      const installStyle = () => {
        if (!document.head) return;
        let style = document.getElementById(styleID);
        if (!style) {
          style = document.createElement('style');
          style.id = styleID;
          document.head.appendChild(style);
        }
        if (style.textContent !== styleText) style.textContent = styleText;
      };

      window.__youglassAutoMute = __YOUGLASS_AUTO_MUTE__;
      window.__youglassPlaybackStopped = false;
      window.__youglassCaptionsEnabled = false;

      const applyAudioPolicy = (force = false) => {
        const media = document.querySelector('video');
        if (!media) return false;
        if (window.__youglassAutoMute === true && (force || window.__youglassUserAudioChoice !== 'unmuted')) {
          media.muted = true;
          media.volume = 0;
          if (force) window.__youglassUserAudioChoice = 'muted';
        } else if (window.__youglassAutoMute !== true && (force || window.__youglassUserAudioChoice !== 'muted')) {
          media.muted = false;
          if (media.volume === 0) media.volume = 1;
          if (force) window.__youglassUserAudioChoice = 'unmuted';
        }
        return true;
      };

      const primePlayback = () => {
        if (window.__youglassPlaybackStopped) return false;
        const media = document.querySelector('video');
        if (!media) return false;
        if (!window.__youglassAutoplayBootstrap) applyAudioPolicy();
        const needsAudioBootstrap = window.__youglassAutoMute !== true &&
          window.__youglassUserAudioChoice !== 'muted' &&
          media.paused &&
          !media.dataset.youglassAutoplayAttempted;
        if (needsAudioBootstrap) {
          window.__youglassAutoplayBootstrap = true;
          media.muted = true;
          media.volume = 0;
          media.dataset.youglassAutoplayAttempted = '1';
        }
        if (media.paused) {
          const playButton = document.querySelector('.ytp-play-button');
          if (playButton && typeof playButton.click === 'function') playButton.click();
        }
        const playResult = media.play();
        if (playResult && playResult.then) {
          playResult.then(() => {
            if (needsAudioBootstrap && window.__youglassAutoMute !== true && window.__youglassUserAudioChoice !== 'muted') {
              media.muted = false;
              if (media.volume === 0) media.volume = 1;
              window.__youglassUserAudioChoice = 'unmuted';
              window.__youglassAutoplayBootstrap = false;
              emitState('Audio on');
            } else {
              window.__youglassAutoplayBootstrap = false;
              emitState();
            }
          }).catch(() => {
            window.__youglassAutoplayBootstrap = false;
            delete media.dataset.youglassAutoplayAttempted;
            emitState('Playback blocked; use Play to start');
          });
        }
        if (!media.paused) {
          media.dataset.youglassPrimed = '1';
          return true;
        }
        return false;
      };

      const captionsButtonIsActive = button => Boolean(
        button && (
          button.getAttribute('aria-pressed') === 'true' ||
          button.classList.contains('ytp-button-active')
        )
      );

      const readCaptionsState = () => {
        const button = document.querySelector('.ytp-subtitles-button');
        if (button) window.__youglassCaptionsEnabled = captionsButtonIsActive(button);
        return Boolean(window.__youglassCaptionsEnabled);
      };

      const currentVideoID = () => {
        try {
          const url = new URL(window.location.href);
          const watchID = url.searchParams.get('v');
          if (watchID) return watchID;
          const match = url.pathname.match(/\\/(?:embed\\/|shorts\\/)?([A-Za-z0-9_-]{11})(?:$|\\/)/);
          return match ? match[1] : null;
        } catch (_) {
          return null;
        }
      };

      const emitState = status => {
        const media = document.querySelector('video');
        if (!media || !window.webkit?.messageHandlers?.youglassPlayback) return;
        const supportsWebKitPiP = Boolean(
          media.webkitSupportsPresentationMode &&
          media.webkitSetPresentationMode &&
          media.webkitSupportsPresentationMode('picture-in-picture')
        );
        window.webkit.messageHandlers.youglassPlayback.postMessage({
          videoID: currentVideoID(),
          muted: Boolean(media.muted || media.volume === 0),
          captionsEnabled: readCaptionsState(),
          playing: !media.paused && !media.ended,
          currentTime: Number.isFinite(media.currentTime) ? media.currentTime : 0,
          duration: Number.isFinite(media.duration) ? media.duration : 0,
          pipAvailable: supportsWebKitPiP || Boolean(document.pictureInPictureEnabled && media.requestPictureInPicture),
          pipActive: media.webkitPresentationMode === 'picture-in-picture' || document.pictureInPictureElement === media,
          status: status || 'Player ready'
        });
      };

      const waitFor = milliseconds => new Promise(resolve => window.setTimeout(resolve, milliseconds));

      const installMediaEvents = () => {
        if (window.__youglassPlaybackStopped) return;
        const media = document.querySelector('video');
        if (!media || media.dataset.youglassEvents === '1') return;
        media.dataset.youglassEvents = '1';
        const statusForEvent = name => {
          if (name === 'error') return media.error?.message || 'YouTube playback error';
          if (name === 'waiting' || name === 'stalled') return 'Buffering video...';
          if (name === 'canplay' || name === 'playing') return 'Player ready';
          return undefined;
        };
        [
          'play', 'playing', 'pause', 'volumechange', 'loadedmetadata',
          'durationchange', 'timeupdate', 'progress', 'seeking', 'seeked',
          'canplay', 'waiting', 'stalled', 'error', 'abort',
          'enterpictureinpicture', 'leavepictureinpicture',
          'webkitpresentationmodechanged'
        ].forEach(name => media.addEventListener(name, () => emitState(statusForEvent(name))));
        emitState();
      };

      window.__youglassControls = {
        stopPlayback() {
          window.__youglassPlaybackStopped = true;
          if (window.__youglassPlaybackTimer) {
            window.clearInterval(window.__youglassPlaybackTimer);
            window.__youglassPlaybackTimer = null;
          }
          if (window.__youglassPlaybackObserver) {
            window.__youglassPlaybackObserver.disconnect();
            window.__youglassPlaybackObserver = null;
          }

          const media = document.querySelector('video');
          if (media) {
            try {
              if (media.webkitPresentationMode === 'picture-in-picture' && media.webkitSetPresentationMode) {
                media.webkitSetPresentationMode('inline');
              }
            } catch (_) {}
            media.pause();
            media.muted = true;
            media.volume = 0;
            media.removeAttribute('src');
            media.load();
          }

          if (document.pictureInPictureElement && document.exitPictureInPicture) {
            document.exitPictureInPicture().catch(() => {});
          }
          window.__youglassControls = null;
        },
        togglePlayback() {
          const media = document.querySelector('video');
          if (!media) return emitState('Video is not ready');
          if (media.paused) media.play().catch(error => emitState(error.message));
          else media.pause();
          emitState();
        },
        toggleMute() {
          const media = document.querySelector('video');
          if (!media) return emitState('Video is not ready');
          window.__youglassAutoplayBootstrap = false;
          const shouldUnmute = media.muted || media.volume === 0;
          media.muted = !shouldUnmute;
          media.volume = shouldUnmute ? 1 : media.volume;
          window.__youglassUserAudioChoice = shouldUnmute ? 'unmuted' : 'muted';
          emitState(shouldUnmute ? 'Audio on' : 'Muted');
        },
        toggleCaptions() {
          const media = document.querySelector('video');
          if (!media) return emitState('Video is not ready');

          // The native button drives YouTube's own caption track selection,
          // while remaining hidden with the rest of YouTube's chrome. This
          // keeps caption availability and language behavior account/video
          // aware without adding a second caption renderer over the video.
          const button = document.querySelector('.ytp-subtitles-button');
          if (!button || button.getAttribute('aria-disabled') === 'true') {
            window.__youglassCaptionsEnabled = false;
            return emitState('Captions unavailable for this video');
          }

          button.click();
          window.setTimeout(() => {
            const enabled = readCaptionsState();
            emitState(enabled ? 'Captions on' : 'Captions off');
          }, 180);
        },
        applyAudioPolicy(autoMuteOnStart) {
          window.__youglassAutoplayBootstrap = false;
          window.__youglassAutoMute = autoMuteOnStart === true;
          applyAudioPolicy(true);
          emitState(window.__youglassAutoMute ? 'Muted by setting' : 'Audio on by setting');
        },
        seekBy(seconds) {
          const media = document.querySelector('video');
          if (!media || !Number.isFinite(media.duration)) return;
          media.currentTime = Math.max(0, Math.min(media.duration, media.currentTime + Number(seconds || 0)));
          emitState();
        },
        seekTo(seconds) {
          const media = document.querySelector('video');
          if (!media || !Number.isFinite(media.duration)) return;
          const target = Number(seconds);
          if (!Number.isFinite(target)) return;
          media.currentTime = Math.max(0, Math.min(media.duration, target));
          emitState('Seeking');
        },
        async togglePictureInPicture() {
          const media = document.querySelector('video');
          if (!media) {
            return emitState('Picture in Picture is unavailable for this video');
          }

          // Close whichever PiP mode is currently active before attempting
          // another mode. WebKit exposes these as two different APIs.
          try {
            if (
              media.webkitPresentationMode === 'picture-in-picture' &&
              media.webkitSetPresentationMode
            ) {
              media.webkitSetPresentationMode('inline');
              await waitFor(160);
              return emitState('Player ready');
            }
            if (document.pictureInPictureElement === media && document.exitPictureInPicture) {
              await document.exitPictureInPicture();
              await waitFor(80);
              return emitState('Player ready');
            }

            // Prefer the standard API. On macOS, the WebKit presentation-mode
            // API can report support without creating a visible PiP window.
            if (document.pictureInPictureEnabled && media.requestPictureInPicture) {
              try {
                await media.requestPictureInPicture();
                await waitFor(120);
                if (document.pictureInPictureElement === media) {
                  return emitState('Picture in Picture');
                }
              } catch (_) {}
            }

            if (
              media.webkitSupportsPresentationMode &&
              media.webkitSetPresentationMode &&
              media.webkitSupportsPresentationMode('picture-in-picture')
            ) {
              media.webkitSetPresentationMode('picture-in-picture');
              await waitFor(180);
              if (media.webkitPresentationMode === 'picture-in-picture') {
                return emitState('Picture in Picture');
              }
            }
            emitState('Picture in Picture is unavailable for this video');
          } catch (error) {
            emitState(error?.message || 'Picture in Picture could not start');
          }
        }
      };

      // Keep click-to-play/pause inside the native surface without making the
      // WKWebView override AppKit's hit-test chain. Programmatic YouTube clicks
      // are ignored so the autoplay bootstrap cannot toggle playback twice.
      if (!window.__youglassSurfaceTapInstalled) {
        document.addEventListener('click', event => {
          if (!event.isTrusted || window.__youglassPlaybackStopped) return;
          event.preventDefault();
          event.stopImmediatePropagation();
          window.__youglassControls?.togglePlayback();
        }, true);
        window.__youglassSurfaceTapInstalled = true;
      }

      installStyle();
      primePlayback();
      installMediaEvents();
      let attempts = 0;
      const playbackTimer = window.setInterval(() => {
        attempts += 1;
        if (primePlayback()) {
          window.clearInterval(playbackTimer);
        } else if (attempts > 20) {
          window.clearInterval(playbackTimer);
          emitState('Playback did not start');
        }
        installMediaEvents();
      }, 700);
      window.__youglassPlaybackTimer = playbackTimer;
      window.__youglassPlaybackObserver = new MutationObserver(() => {
        if (window.__youglassPlaybackStopped) return;
        installStyle();
        primePlayback();
        installMediaEvents();
      });
      window.__youglassPlaybackObserver.observe(document.documentElement, { childList: true, subtree: true });
    })();
    """

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: Self.initialSurfaceScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        let playerScript = Self.playerChromeScript.replacingOccurrences(
            of: "__YOUGLASS_AUTO_MUTE__",
            with: autoMuteOnStart ? "true" : "false"
        )
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: playerScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )
        // WebKit invokes WKScriptMessageHandler through Objective-C. Keep that
        // callback on a plain NSObject and hop to MainActor explicitly before
        // updating the SwiftUI playback controller.
        configuration.userContentController.add(
            ScriptMessageHandlerProxy(coordinator: context.coordinator),
            name: "youglassPlayback"
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.wantsLayer = true
        webView.layer?.backgroundColor = NSColor.black.cgColor
        webView.underPageBackgroundColor = .black
        controller.attach(to: webView, video: video)
        context.coordinator.autoMuteOnStart = autoMuteOnStart
        context.coordinator.load(video: video, in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        controller.prepareAmbientPalette(for: video)
        let audioPreferenceChanged = context.coordinator.autoMuteOnStart != autoMuteOnStart
        context.coordinator.autoMuteOnStart = autoMuteOnStart
        if audioPreferenceChanged {
            context.coordinator.applyAudioPolicy(in: webView)
        }
        context.coordinator.load(video: video, in: webView)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.deactivate()
        coordinator.controller.stopAndDetach(from: webView)

        // Let the current SwiftUI/AppKit transaction finish before touching the WebKit view.
        // This avoids a macOS 26 crash in WebKit's RemoteLayerTreePropertyApplier when a view is
        // removed while a layer-tree commit is in flight.
        DispatchQueue.main.async {
            webView.stopLoading()
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "youglassPlayback")
            webView.navigationDelegate = nil
            webView.uiDelegate = nil
        }
    }

    fileprivate struct PlaybackMessage: Sendable {
        let videoID: String?
        let muted: Bool?
        let captionsEnabled: Bool?
        let playing: Bool?
        let currentTime: Double?
        let duration: Double?
        let pipAvailable: Bool?
        let pipActive: Bool?
        let status: String?

        init?(body: Any) {
            guard let payload = body as? [String: Any] else { return nil }

            videoID = payload["videoID"] as? String
            muted = payload["muted"] as? Bool
            captionsEnabled = payload["captionsEnabled"] as? Bool
            playing = payload["playing"] as? Bool
            currentTime = (payload["currentTime"] as? NSNumber)?.doubleValue
            duration = (payload["duration"] as? NSNumber)?.doubleValue
            pipAvailable = payload["pipAvailable"] as? Bool
            pipActive = payload["pipActive"] as? Bool
            status = payload["status"] as? String

            guard videoID != nil || muted != nil || captionsEnabled != nil || playing != nil || currentTime != nil || duration != nil || pipAvailable != nil || pipActive != nil || status != nil else {
                return nil
            }
        }

        var dictionary: [String: Any] {
            var result: [String: Any] = [:]
            if let videoID { result["videoID"] = videoID }
            if let muted { result["muted"] = muted }
            if let captionsEnabled { result["captionsEnabled"] = captionsEnabled }
            if let playing { result["playing"] = playing }
            if let currentTime { result["currentTime"] = currentTime }
            if let duration { result["duration"] = duration }
            if let pipAvailable { result["pipAvailable"] = pipAvailable }
            if let pipActive { result["pipActive"] = pipActive }
            if let status { result["status"] = status }
            return result
        }
    }

    private final class ScriptMessageHandlerProxy: NSObject, WKScriptMessageHandler {
        weak var coordinator: Coordinator?

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "youglassPlayback", let payload = PlaybackMessage(body: message.body) else { return }
            let coordinator = self.coordinator
            Task { @MainActor in
                coordinator?.handlePlaybackMessage(payload)
            }
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let controller: YouTubePlaybackController
        var autoMuteOnStart = false
        private var loadedVideoID: String?
        private var isActive = true

        init(controller: YouTubePlaybackController) {
            self.controller = controller
        }

        func deactivate() {
            isActive = false
            loadedVideoID = nil
        }

        @MainActor
        fileprivate func handlePlaybackMessage(_ payload: PlaybackMessage) {
            guard isActive else { return }
            controller.update(from: payload.dictionary)
        }

        func load(video: VideoItem, in webView: WKWebView) {
            guard isActive, video.isPlayableOnYouTube, loadedVideoID != video.id else { return }
            var components = URLComponents(url: video.playbackURL, resolvingAgainstBaseURL: false)
            var queryItems = components?.queryItems ?? []
            if !queryItems.contains(where: { $0.name == "autoplay" }) {
                queryItems.append(URLQueryItem(name: "autoplay", value: "1"))
            }
            queryItems.removeAll { $0.name == "mute" }
            if autoMuteOnStart {
                queryItems.append(URLQueryItem(name: "mute", value: "1"))
            }
            if !queryItems.contains(where: { $0.name == "playsinline" }) {
                queryItems.append(URLQueryItem(name: "playsinline", value: "1"))
            }
            components?.queryItems = queryItems
            guard let url = components?.url else { return }
            loadedVideoID = video.id

            var request = URLRequest(
                url: url,
                cachePolicy: .useProtocolCachePolicy,
                timeoutInterval: 30
            )
            request.setValue("https://www.youtube.com/", forHTTPHeaderField: "Referer")
            webView.load(request)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard isActive else { return }
            // YouTube is a client-rendered application. Reapply the player
            // surface and muted-start logic after its initial navigation too.
            let playerScript = YouTubeInlinePlayerView.playerChromeScript.replacingOccurrences(
                of: "__YOUGLASS_AUTO_MUTE__",
                with: autoMuteOnStart ? "true" : "false"
            )
            webView.evaluateJavaScript(playerScript, completionHandler: nil)
            Task { @MainActor [weak controller] in
                controller?.didFinishNavigation()
            }
        }

        func applyAudioPolicy(in webView: WKWebView) {
            guard isActive else { return }
            webView.evaluateJavaScript(
                "window.__youglassControls?.applyAudioPolicy(\(autoMuteOnStart ? "true" : "false"))",
                completionHandler: nil
            )
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
        ) {
            // Keep navigation in the existing player surface; never create a browser window.
            if navigationAction.targetFrame == nil {
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            nil
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard isActive else { return }
            loadedVideoID = nil
            Task { @MainActor [weak controller] in
                controller?.handleNavigationFailure(error)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            guard isActive else { return }
            loadedVideoID = nil
            Task { @MainActor [weak controller] in
                controller?.handleNavigationFailure(error)
            }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            guard isActive else { return }
            loadedVideoID = nil
            let error = NSError(
                domain: "YouGlassPlayback",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "The YouTube player process stopped."]
            )
            Task { @MainActor [weak controller] in
                controller?.handleNavigationFailure(error)
            }
            webView.reload()
        }
    }
}
