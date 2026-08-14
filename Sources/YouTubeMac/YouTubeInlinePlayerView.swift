import AppKit
import Foundation
import OSLog
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
    private var activeVideoID: String?
    private var pendingResumeVideoID: String?
    private var pendingResumePosition: Double?
    private var pictureInPictureFallback: (() -> Void)?
    private var pictureInPictureFallbackTask: Task<Void, Never>?
    private var loadWatchdogTask: Task<Void, Never>?
    private var playbackBootstrapTask: Task<Void, Never>?
    private var loadGeneration = 0
    private let logger = Logger(subsystem: "com.kevinhowe.YouGlass", category: "playback")

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
        if self.webView === webView {
            self.webView = nil
        }
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

    private func resetPublishedStateForAttachment() {
        isMuted = false
        isCaptionsEnabled = false
        isPlaying = false
        isPictureInPictureAvailable = false
        isPictureInPictureActive = false
        isSurfaceReady = false
        canRetry = false
        currentTime = 0
        duration = 0
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

        if let value = payload["muted"] as? Bool { isMuted = value }
        if let value = payload["captionsEnabled"] as? Bool { isCaptionsEnabled = value }
        if let value = payload["playing"] as? Bool { isPlaying = value }
        if let value = payload["pipAvailable"] as? Bool { isPictureInPictureAvailable = value }
        if let value = payload["pipActive"] as? Bool {
            isPictureInPictureActive = value
            if value { clearPictureInPictureFallback() }
        }
        if frameReady == true {
            cancelPlaybackBootstrap()
        }

        var statusIndicatesFailure = false
        if let value = payload["status"] as? String, !value.isEmpty {
            status = value
            let lowercased = value.lowercased()
            statusIndicatesFailure = lowercased.contains("blocked") ||
                lowercased.contains("not allowed")
            if lowercased.contains("picture in picture is unavailable") ||
                lowercased.contains("picture in picture could not start") {
                let fallback = pictureInPictureFallback
                clearPictureInPictureFallback()
                fallback?()
            }
            if lowercased.contains("error") ||
                lowercased.contains("unavailable") ||
                lowercased.contains("failed") ||
                lowercased.contains("did not load") ||
                statusIndicatesFailure {
                canRetry = true
                cancelLoadWatchdog()
                cancelPlaybackBootstrap()
            }
        }
        if let value = payload["currentTime"] as? NSNumber { currentTime = max(0, value.doubleValue) }
        if let value = payload["duration"] as? NSNumber { duration = max(0, value.doubleValue) }
        if let frameReady {
            isSurfaceReady = frameReady
            if frameReady {
                canRetry = false
                cancelLoadWatchdog()
            }
        } else {
            // A duration or an audio-only "playing" event is not enough to
            // render a usable player surface. The page bridge must explicitly
            // confirm that a decoded video frame exists.
            isSurfaceReady = false
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

    private func run(_ script: String) {
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
              if (execute() || attempts >= 20) {
                window.clearInterval(timer);
                resolve(attempts < 20);
              }
            }, 50);
          });
        })()
        """

        webView.evaluateJavaScript(command, completionHandler: nil)
    }

    private func startLoadWatchdog(for videoID: String?) {
        cancelLoadWatchdog()
        guard let videoID else { return }
        let generation = loadGeneration
        loadWatchdogTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 45_000_000_000)
            guard let self,
                  !Task.isCancelled,
                  self.loadGeneration == generation,
                  self.activeVideoID == videoID,
                  self.webView != nil,
                  !self.isSurfaceReady else { return }
            self.status = "Video frame did not load"
            self.canRetry = true
        }
    }

    private func schedulePlaybackBootstrap() {
        cancelPlaybackBootstrap()

        guard let videoID = activeVideoID, webView != nil else { return }
        let generation = loadGeneration
        playbackBootstrapTask = Task { @MainActor [weak self] in
            let delays: [UInt64] = [
                250_000_000,
                700_000_000,
                1_500_000_000,
                3_000_000_000,
                5_000_000_000,
                7_000_000_000,
                8_000_000_000,
                8_000_000_000,
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

    private func cancelPlaybackBootstrap() {
        playbackBootstrapTask?.cancel()
        playbackBootstrapTask = nil
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
@MainActor
private final class YouGlassPlaybackWebView: WKWebView {
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // WKMouseTrackingObserver asks the surrounding SwiftUI hosting view to
        // hit-test every pointer move. macOS 27 beta performs that hit test
        // outside the executor context required by SwiftUI and traps. YouGlass
        // uses native controls, so the playback surface needs no mouse tracking.
        trackingAreas.forEach(removeTrackingArea)
    }
}

@MainActor
final class YouTubeInlinePlayerHostView: NSView {
    let webView: WKWebView

    init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.cornerRadius = 24
        layer?.masksToBounds = true

        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.autoresizingMask = [.width, .height]
        addSubview(webView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        webView.frame = bounds
    }

    // The WebKit surface is playback-only. Native YouGlass controls sit above
    // it and send playback commands through the controller, so allowing the
    // WKWebView to win AppKit hit testing would make those controls appear
    // clickable while silently routing the event into YouTube's page layer.
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

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
        /* Keep YouTube's caption track inside the media surface. YouTube
           normally shifts this layer when its own chrome autohides; that
           transition makes captions fall into the native title row. */
        .ytp-caption-window-container,
        .caption-window.ytp-caption-window-bottom,
        .ytp-caption-window-bottom {
          position: absolute !important;
          top: auto !important;
          bottom: clamp(88px, 20%, 150px) !important;
          left: 50% !important;
          right: auto !important;
          width: min(88%, 980px) !important;
          max-width: 88% !important;
          min-width: 0 !important;
          transform: translateX(-50%) !important;
          text-align: center !important;
          opacity: 1 !important;
          visibility: visible !important;
          transition: none !important;
          z-index: 40 !important;
          pointer-events: none !important;
        }
        .ytp-caption-window-container .caption-window,
        .ytp-caption-window-container .caption-window.ytp-caption-window-bottom {
          position: static !important;
          top: auto !important;
          right: auto !important;
          bottom: auto !important;
          left: auto !important;
          width: 100% !important;
          max-width: 100% !important;
          margin: 0 auto !important;
          transform: none !important;
          text-align: center !important;
        }
        .ytp-caption-window-container .caption-window,
        .ytp-caption-window-container .ytp-caption-segment {
          color: #fff !important;
          text-shadow: 0 1px 3px rgba(0, 0, 0, .95) !important;
        }
        .ytp-caption-window-container .ytp-caption-segment {
          background: rgba(0, 0, 0, .72) !important;
          line-height: 1.25 !important;
          box-decoration-break: clone !important;
          -webkit-box-decoration-break: clone !important;
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

      // A watch page can reinject this script during client-side navigation.
      // Invalidate and tear down the previous bootstrap loop first so two
      // page generations cannot race to start or pause the same media element.
      window.__youglassPlaybackScriptGeneration =
        (window.__youglassPlaybackScriptGeneration || 0) + 1;
      const playbackScriptGeneration = window.__youglassPlaybackScriptGeneration;
      if (window.__youglassPlaybackTimer) {
        window.clearInterval(window.__youglassPlaybackTimer);
        window.__youglassPlaybackTimer = null;
      }
      if (window.__youglassPlaybackObserver) {
        window.__youglassPlaybackObserver.disconnect();
        window.__youglassPlaybackObserver = null;
      }
      window.__youglassAutoplayBootstrap = false;
      window.__youglassPlayRequestInFlight = false;
      window.__youglassUserAudioChoice = null;
      window.__youglassFrameReady = false;
      window.__youglassBoundMedia = null;
      window.__youglassBoundMediaSource = null;
      window.__youglassWaitingForVideoFrame = false;

      window.__youglassAutoMute = __YOUGLASS_AUTO_MUTE__;
      window.__youglassExpectedVideoID = '__YOUGLASS_VIDEO_ID__';
      window.__youglassPlaybackStopped = false;
      window.__youglassCaptionsEnabled = false;
      // This is intentionally reset when a new native player is installed.
      // Once the user presses Play or Pause, the bootstrap observer must not
      // override that explicit choice while YouTube mutates its page DOM.
      window.__youglassUserPlaybackChoice = null;

      // YouTube can move the media element while the watch page hydrates. In
      // addition to the top-level document, look through same-origin frames so
      // native controls keep working across those page transitions.
      const findMediaElement = (root = document, seen = new Set()) => {
        if (!root || seen.has(root)) return null;
        seen.add(root);
        const direct = root.querySelector?.('video');
        if (direct) return direct;
        const frames = root.querySelectorAll?.('iframe') || [];
        for (const frame of Array.from(frames)) {
          try {
            const nested = frame.contentDocument && findMediaElement(frame.contentDocument, seen);
            if (nested) return nested;
          } catch (_) {
            // Cross-origin frames are expected; direct lookup still works.
          }
        }
        return null;
      };

      const applyAudioPolicy = (force = false) => {
        const media = findMediaElement();
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

      const hasPlayableMetadata = media =>
        media.readyState >= HTMLMediaElement.HAVE_METADATA &&
        (media.duration === Infinity ||
         (Number.isFinite(media.duration) && media.duration > 0));

      const resetFrameStateIfNeeded = media => {
        if (!media) return;
        const source = media.currentSrc || media.src || '';
        if (window.__youglassBoundMedia !== media ||
            window.__youglassBoundMediaSource !== source) {
          window.__youglassBoundMedia = media;
          window.__youglassBoundMediaSource = source;
          window.__youglassFrameReady = false;
          window.__youglassWaitingForVideoFrame = false;
          delete media.dataset.youglassFrameWatch;
        }
      };

      const releaseAudioAfterFirstFrame = () => {
        if (!window.__youglassWaitingForVideoFrame ||
            window.__youglassAutoMute === true ||
            window.__youglassUserAudioChoice === 'muted') return;
        const media = window.__youglassBoundMedia || findMediaElement();
        if (!media) return;
        media.muted = false;
        if (media.volume === 0) media.volume = 1;
        window.__youglassUserAudioChoice = 'unmuted';
        window.__youglassWaitingForVideoFrame = false;
      };

      const markFrameReady = media => {
        if (!media || window.__youglassPlaybackStopped) return false;
        resetFrameStateIfNeeded(media);
        if (window.__youglassBoundMedia !== media) return false;
        if (media.readyState < HTMLMediaElement.HAVE_CURRENT_DATA) return false;
        window.__youglassFrameReady = true;
        releaseAudioAfterFirstFrame();
        return true;
      };

      const watchForFirstFrame = media => {
        if (!media || window.__youglassPlaybackStopped) return false;
        resetFrameStateIfNeeded(media);
        if (window.__youglassFrameReady) return true;
        if (media.readyState < HTMLMediaElement.HAVE_CURRENT_DATA) return false;
        // Some WebKit versions expose requestVideoFrameCallback but never
        // deliver its callback for a YouTube-managed media element.
        if (media.videoWidth > 0 && media.videoHeight > 0) {
          return markFrameReady(media);
        }
        const source = window.__youglassBoundMediaSource;
        if (typeof media.requestVideoFrameCallback === 'function') {
          if (media.dataset.youglassFrameWatch !== '1') {
            media.dataset.youglassFrameWatch = '1';
            try {
              media.requestVideoFrameCallback(() => {
                delete media.dataset.youglassFrameWatch;
                if (window.__youglassBoundMedia === media &&
                    window.__youglassBoundMediaSource === source &&
                    media.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA) {
                  markFrameReady(media);
                  emitState('Player ready');
                }
              });
            } catch (_) {
              delete media.dataset.youglassFrameWatch;
              return markFrameReady(media);
            }
          }
          return false;
        }
        return markFrameReady(media);
      };

      const playbackFailureStatus = media => {
        if (media.error) {
          // YouTube can briefly publish an error while replacing the stream
          // or before the media element has metadata. Keep that startup churn
          // recoverable so PIP can try the same video again once its source is
          // ready. An error after a real duration exists is terminal and is
          // surfaced to the native retry state.
          if (!hasPlayableMetadata(media) || !window.__youglassFrameReady) return 'Buffering video...';
          const code = media.error.code ? ` (${media.error.code})` : '';
          return `${media.error.message || 'YouTube playback error'}${code}`;
        }

        // A rejected play() promise is not always a permanent failure. Some
        // watch pages create the media element before metadata and a playable
        // source are ready. Keep those cases in the bootstrap retry path.
        if (!window.__youglassFrameReady) return 'Buffering video...';
        if (!hasPlayableMetadata(media) || media.networkState === HTMLMediaElement.NETWORK_LOADING) {
          return 'Buffering video...';
        }
        return 'Playback blocked; use Play to start';
      };

      const primePlayback = () => {
        if (window.__youglassPlaybackStopped) return false;
        const media = findMediaElement();
        if (!media) return false;
        resetFrameStateIfNeeded(media);
        watchForFirstFrame(media);
        if (window.__youglassUserPlaybackChoice === 'paused') {
          if (!media.paused) media.pause();
          emitState('Paused');
          return true;
        }
        const holdAudioUntilFrame = !window.__youglassFrameReady &&
            window.__youglassAutoMute !== true;
        if (holdAudioUntilFrame) {
            media.muted = true;
            media.volume = 0;
            window.__youglassWaitingForVideoFrame =
                window.__youglassUserAudioChoice !== 'muted';
        } else if (!window.__youglassAutoplayBootstrap &&
                   window.__youglassFrameReady) {
            applyAudioPolicy();
        }
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
        // Do not click YouTube's hidden play button before calling media.play().
        // That click can toggle the element twice on some watch pages. Also
        // keep only one promise in flight while the browser resolves autoplay.
        if (media.paused && !window.__youglassPlayRequestInFlight) {
          window.__youglassPlayRequestInFlight = true;
          let playResult;
          try {
            playResult = media.play();
          } catch (_) {
            window.__youglassPlayRequestInFlight = false;
            window.__youglassAutoplayBootstrap = false;
            delete media.dataset.youglassAutoplayAttempted;
            emitState(playbackFailureStatus(media));
            return false;
          }

          if (playResult && playResult.then) {
            playResult.then(() => {
              window.__youglassPlayRequestInFlight = false;
              window.__youglassAutoplayBootstrap = false;
              if (needsAudioBootstrap &&
                  window.__youglassAutoMute !== true &&
                  window.__youglassUserAudioChoice !== 'muted') {
                window.__youglassWaitingForVideoFrame = true;
                emitState('Buffering video...');
              } else {
                emitState();
              }
            }).catch(() => {
              window.__youglassPlayRequestInFlight = false;
              window.__youglassAutoplayBootstrap = false;
              window.__youglassWaitingForVideoFrame = false;
              delete media.dataset.youglassAutoplayAttempted;
              emitState(playbackFailureStatus(media));
            });
          } else {
            window.__youglassPlayRequestInFlight = false;
            if (needsAudioBootstrap) {
              window.__youglassWaitingForVideoFrame = true;
            }
          }
        }
        // WebKit can flip paused to false before the play() promise settles.
        // Keep the bootstrap timer alive until that promise has actually
        // resolved, otherwise a transient per-video failure becomes final.
        if (window.__youglassFrameReady && !media.paused && !window.__youglassPlayRequestInFlight) {
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
          if (match) return match[1];
          const configuredID = window.ytplayer?.config?.args?.video_id ||
            window.ytplayer?.config?.video_id ||
            document.querySelector('[data-video-id]')?.getAttribute('data-video-id');
          return configuredID || window.__youglassExpectedVideoID || null;
        } catch (_) {
          return window.__youglassExpectedVideoID || null;
        }
      };

      const emitState = status => {
        const media = findMediaElement();
        if (!media || !window.webkit?.messageHandlers?.youglassPlayback) return;
        resetFrameStateIfNeeded(media);
        const frameReady = watchForFirstFrame(media);
        const requestedStatus = status || 'Player ready';
        const resolvedStatus = !frameReady &&
          (requestedStatus === 'Player ready' || requestedStatus === 'Audio on')
          ? 'Buffering video...'
          : requestedStatus;
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
          frameReady,
          pipAvailable: supportsWebKitPiP || Boolean(document.pictureInPictureEnabled && media.requestPictureInPicture),
          pipActive: media.webkitPresentationMode === 'picture-in-picture' || document.pictureInPictureElement === media,
          status: resolvedStatus
        });
      };

      const waitFor = milliseconds => new Promise(resolve => window.setTimeout(resolve, milliseconds));

      const installMediaEvents = () => {
        if (window.__youglassPlaybackStopped) return;
        const media = findMediaElement();
        if (!media) return;
        resetFrameStateIfNeeded(media);
        if (media.dataset.youglassEvents !== '1') {
          media.dataset.youglassEvents = '1';
          const statusForEvent = name => {
            if (name === 'error') return playbackFailureStatus(media);
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
        }
        watchForFirstFrame(media);
        emitState();
      };

      window.__youglassControls = {
        stopPlayback() {
          window.__youglassPlaybackStopped = true;
          window.__youglassPlaybackScriptGeneration =
            (window.__youglassPlaybackScriptGeneration || 0) + 1;
          window.__youglassPlayRequestInFlight = false;
          window.__youglassWaitingForVideoFrame = false;
          window.__youglassFrameReady = false;
          window.__youglassBoundMedia = null;
          window.__youglassBoundMediaSource = null;
          if (window.__youglassPlaybackTimer) {
            window.clearInterval(window.__youglassPlaybackTimer);
            window.__youglassPlaybackTimer = null;
          }
          if (window.__youglassPlaybackObserver) {
            window.__youglassPlaybackObserver.disconnect();
            window.__youglassPlaybackObserver = null;
          }

          const media = findMediaElement();
          if (media) {
            try {
              if (media.webkitPresentationMode === 'picture-in-picture' && media.webkitSetPresentationMode) {
                media.webkitSetPresentationMode('inline');
              }
            } catch (_) {}
            media.pause();
            media.muted = true;
            media.volume = 0;
            delete media.dataset.youglassFrameWatch;
          }

          if (document.pictureInPictureElement && document.exitPictureInPicture) {
            document.exitPictureInPicture().catch(() => {});
          }
          window.__youglassControls = null;
        },
        togglePlayback() {
          const media = findMediaElement();
          if (!media) return emitState('Video is not ready');
          if (media.paused) {
            window.__youglassUserPlaybackChoice = 'playing';
            window.__youglassPlayRequestInFlight = false;
            const playResult = media.play();
            if (playResult && playResult.catch) {
              playResult.catch(error => {
                window.__youglassUserPlaybackChoice = null;
                window.__youglassPlayRequestInFlight = false;
                emitState(error?.message || playbackFailureStatus(media));
              });
            }
          } else {
            window.__youglassUserPlaybackChoice = 'paused';
            media.pause();
          }
          emitState();
        },
        startPlayback() {
          if (window.__youglassPlaybackStopped) return;
          if (!findMediaElement()) return emitState('Video is not ready');
          installMediaEvents();
          primePlayback();
        },
        toggleMute() {
          const media = findMediaElement();
          if (!media) return emitState('Video is not ready');
          window.__youglassAutoplayBootstrap = false;
          const shouldUnmute = media.muted || media.volume === 0;
          if (shouldUnmute && !window.__youglassFrameReady) {
            window.__youglassWaitingForVideoFrame = true;
            window.__youglassUserAudioChoice = 'unmuted';
            media.muted = true;
            media.volume = 0;
            emitState('Buffering video...');
            return;
          }
          media.muted = !shouldUnmute;
          media.volume = shouldUnmute ? 1 : media.volume;
          window.__youglassUserAudioChoice = shouldUnmute ? 'unmuted' : 'muted';
          window.__youglassWaitingForVideoFrame = false;
          emitState(shouldUnmute ? 'Audio on' : 'Muted');
        },
        toggleCaptions() {
          const media = findMediaElement();
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
          const media = findMediaElement();
          if (!media || !Number.isFinite(media.duration)) return;
          media.currentTime = Math.max(0, Math.min(media.duration, media.currentTime + Number(seconds || 0)));
          emitState();
        },
        seekTo(seconds) {
          const media = findMediaElement();
          if (!media || !Number.isFinite(media.duration)) return;
          const target = Number(seconds);
          if (!Number.isFinite(target)) return;
          media.currentTime = Math.max(0, Math.min(media.duration, target));
          emitState('Seeking');
        },
        async togglePictureInPicture() {
          const media = findMediaElement();
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
      installMediaEvents();
      primePlayback();
      let attempts = 0;
      const playbackTimer = window.setInterval(() => {
        if (window.__youglassPlaybackScriptGeneration !== playbackScriptGeneration) {
          window.clearInterval(playbackTimer);
          return;
        }
        attempts += 1;
        installMediaEvents();
        if (primePlayback() && window.__youglassFrameReady) {
          window.clearInterval(playbackTimer);
        } else if (attempts > 64) {
          window.clearInterval(playbackTimer);
          emitState('Video frame did not load');
        }
      }, 700);
      window.__youglassPlaybackTimer = playbackTimer;
      window.__youglassPlaybackObserver = new MutationObserver(() => {
        if (window.__youglassPlaybackStopped ||
            window.__youglassPlaybackScriptGeneration !== playbackScriptGeneration) return;
        installStyle();
        installMediaEvents();
        primePlayback();
      });
      window.__youglassPlaybackObserver.observe(document.documentElement, { childList: true, subtree: true });
    })();
    """

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeNSView(context: Context) -> YouTubeInlinePlayerHostView {
        let configuration = WKWebViewConfiguration()
        configuration.youGlassDisableWebMaterialsOnAffectedSystems()
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
        var playerScript = Self.playerChromeScript.replacingOccurrences(
            of: "__YOUGLASS_AUTO_MUTE__",
            with: autoMuteOnStart ? "true" : "false"
        )
        playerScript = playerScript.replacingOccurrences(
            of: "__YOUGLASS_VIDEO_ID__",
            with: video.id
        )
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: playerScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )
        // WebKit invokes WKScriptMessageHandler through Objective-C. Keep the
        // forwarding object scoped to this WebKit configuration.
        configuration.userContentController.add(
            ScriptMessageHandlerProxy(coordinator: context.coordinator),
            name: "youglassPlayback"
        )

        let webView = YouGlassPlaybackWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.wantsLayer = true
        webView.layer?.backgroundColor = NSColor.black.cgColor
        webView.underPageBackgroundColor = .black
        controller.attach(to: webView, video: video)
        context.coordinator.autoMuteOnStart = autoMuteOnStart
        context.coordinator.load(video: video, in: webView)
        return YouTubeInlinePlayerHostView(webView: webView)
    }

    func updateNSView(_ hostView: YouTubeInlinePlayerHostView, context: Context) {
        let webView = hostView.webView
        controller.prepareAmbientPalette(for: video)
        let audioPreferenceChanged = context.coordinator.autoMuteOnStart != autoMuteOnStart
        context.coordinator.autoMuteOnStart = autoMuteOnStart
        if audioPreferenceChanged {
            context.coordinator.applyAudioPolicy(in: webView)
        }
        context.coordinator.load(video: video, in: webView)
    }

    static func dismantleNSView(_ hostView: YouTubeInlinePlayerHostView, coordinator: Coordinator) {
        let webView = hostView.webView
        coordinator.controller.stopAndDetachDeferred(from: webView)
    }

    fileprivate struct PlaybackMessage: Sendable {
        let videoID: String?
        let muted: Bool?
        let captionsEnabled: Bool?
        let playing: Bool?
        let currentTime: Double?
        let duration: Double?
        let frameReady: Bool?
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
            frameReady = payload["frameReady"] as? Bool
            pipAvailable = payload["pipAvailable"] as? Bool
            pipActive = payload["pipActive"] as? Bool
            status = payload["status"] as? String

            guard videoID != nil || muted != nil || captionsEnabled != nil || playing != nil || currentTime != nil || duration != nil || frameReady != nil || pipAvailable != nil || pipActive != nil || status != nil else {
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
            if let frameReady { result["frameReady"] = frameReady }
            if let pipAvailable { result["pipAvailable"] = pipAvailable }
            if let pipActive { result["pipActive"] = pipActive }
            if let status { result["status"] = status }
            return result
        }
    }

    private final class ScriptMessageHandlerProxy: NSObject, WKScriptMessageHandler {
        // WKScriptMessageHandler is entered through an Objective-C thunk. On
        // macOS 27 beta, applying the enclosing SwiftUI type's inferred main
        // actor isolation to that thunk can pass an invalid executor reference
        // into Swift's precondition before this method even begins. Keep only
        // this bridge nonisolated; the parsed Sendable value is handed back to
        // the main actor below.
        nonisolated(unsafe) weak var coordinator: Coordinator?

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
        }

        nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            let coordinator = self.coordinator
            Task { @MainActor in
                guard message.name == "youglassPlayback",
                      let payload = PlaybackMessage(body: message.body) else { return }
                coordinator?.handlePlaybackMessage(payload)
            }
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let controller: YouTubePlaybackController
        var autoMuteOnStart = false
        private var loadedVideoID: String?

        init(controller: YouTubePlaybackController) {
            self.controller = controller
        }

        @MainActor
        fileprivate func handlePlaybackMessage(_ payload: PlaybackMessage) {
            controller.update(from: payload.dictionary)
        }

        func load(video: VideoItem, in webView: WKWebView) {
            guard video.isPlayableOnYouTube, loadedVideoID != video.id else { return }
            // Use YouTube's first-party watch surface. Direct /embed URLs are
            // rejected for a subset of videos with YouTube error 152-4 even
            // when the same signed-in account can play the video on youtube.com.
            // The injected chrome script hides the page UI while preserving
            // YouTube's account, age, live, and playback eligibility checks.
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
            if !queryItems.contains(where: { $0.name == "app" }) {
                queryItems.append(URLQueryItem(name: "app", value: "desktop"))
            }
            if !queryItems.contains(where: { $0.name == "hl" }) {
                queryItems.append(URLQueryItem(name: "hl", value: "en"))
            }
            components?.queryItems = queryItems
            guard let url = components?.url else { return }
            loadedVideoID = video.id

            webView.load(URLRequest(
                url: url,
                cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                timeoutInterval: 30
            ))
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // YouTube is a client-rendered application. Reapply the player
            // surface and muted-start logic after its initial navigation too.
            let playerScript = YouTubeInlinePlayerView.playerChromeScript.replacingOccurrences(
                of: "__YOUGLASS_AUTO_MUTE__",
                with: autoMuteOnStart ? "true" : "false"
            )
            .replacingOccurrences(
                of: "__YOUGLASS_VIDEO_ID__",
                with: loadedVideoID ?? ""
            )
            Task { @MainActor [weak controller, weak webView] in
                guard let controller, let webView,
                      controller.isAttached(to: webView) else { return }
                _ = try? await webView.evaluateJavaScript(playerScript)
                controller.didFinishNavigation(for: webView)
            }
        }

        func applyAudioPolicy(in webView: WKWebView) {
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
            Task { @MainActor [weak controller, weak webView] in
                guard let controller, let webView else { return }
                controller.handleNavigationFailure(error, for: webView)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor [weak controller, weak webView] in
                guard let controller, let webView else { return }
                controller.handleNavigationFailure(error, for: webView)
            }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            let error = NSError(
                domain: "YouGlassPlayback",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "The YouTube player process stopped."]
            )
            Task { @MainActor [weak controller, weak webView] in
                guard let controller, let webView else { return }
                controller.handleNavigationFailure(error, for: webView)
            }
            // Do not automatically reload a terminated WebKit process. A
            // reload can overlap a SwiftUI/AppKit detach or PIP handoff and
            // trigger another remote layer-tree commit. The native retry UI
            // now gives the user an explicit, isolated recovery action.
        }
    }
}
