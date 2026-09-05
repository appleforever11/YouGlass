import SwiftUI

/// Owns the session without forwarding every transport tick to the watch page.
@MainActor
final class WatchPlaybackOwner: ObservableObject {
    let controller = YouTubePlaybackController()
}

struct WatchPlaybackObservation: View {
    @ObservedObject var controller: YouTubePlaybackController
    let onAmbient: (VideoAmbientPalette) -> Void
    let onTransport: () -> Void
    let onFinish: () -> Void

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onChange(of: controller.ambientPalette) { _, value in onAmbient(value) }
            .onChange(of: controller.currentTime) { _, _ in onTransport() }
            .onChange(of: controller.duration) { _, _ in onTransport() }
            .onChange(of: controller.isPlaying) { _, _ in onTransport() }
            .onChange(of: controller.playbackRate) { _, _ in onTransport() }
            .onChange(of: controller.didFinish) { _, finished in
                if finished { onFinish() }
            }
    }
}

struct WatchCaptionOverlay: View {
    @ObservedObject var controller: YouTubePlaybackController
    let bottomInset: CGFloat

    var body: some View {
        NativePlayerCaptionOverlay(
            text: controller.captionText,
            bottomInset: bottomInset,
            isCompact: false
        )
    }
}
