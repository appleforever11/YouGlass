import AppKit
@preconcurrency import WebKit

/// Hosts YouTube's supported watch client inside the native player surface.
@MainActor
final class YouGlassPlaybackWebView: WKWebView {
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

        // WKWebView owns a remote layer tree. A SwiftUI clip higher in the
        // hierarchy does not always constrain that tree while an enclosing
        // ScrollView is moving, so keep the AppKit host itself clipped too.
        clipsToBounds = true
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.cornerRadius = PlayerMediaMetrics.cornerRadius
        layer?.masksToBounds = true

        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.autoresizingMask = [.width, .height]
        webView.clipsToBounds = true
        webView.wantsLayer = true
        webView.layer?.masksToBounds = true
        webView.layer?.cornerRadius = PlayerMediaMetrics.cornerRadius
        addSubview(webView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        guard webView.frame != bounds else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        webView.frame = bounds
        webView.layer?.frame = webView.bounds
        CATransaction.commit()
    }

    // The WebKit surface is playback-only. Native YouGlass controls sit above
    // it and send playback commands through the controller, so allowing the
    // WKWebView to win AppKit hit testing would make those controls appear
    // clickable while silently routing the event into YouTube's page layer.
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
