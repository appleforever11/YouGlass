import AVFoundation
@preconcurrency import AVKit
import SwiftUI

/// Owns the system Picture in Picture session for a real native media source.
///
/// YouTube watch URLs are HTML pages, not AVPlayer media URLs. The coordinator
/// therefore stays unavailable until the app attaches an AVPlayerLayer that is
/// ready for display. This keeps PiP native and prevents an HTML/WebKit player
/// from being mistaken for a playable media source.
@MainActor
final class YouGlassPictureInPictureController: NSObject, ObservableObject, AVPictureInPictureControllerDelegate {
    @Published private(set) var isSupported = AVPictureInPictureController.isPictureInPictureSupported()
    @Published private(set) var isReady = false
    @Published private(set) var isActive = false
    @Published private(set) var status = "Picture in Picture becomes available when native playback is connected."

    private var pictureInPictureController: AVPictureInPictureController?
    private var playerLayer: AVPlayerLayer?

    func reset(isLive: Bool) {
        pictureInPictureController?.stopPictureInPicture()
        pictureInPictureController = nil
        playerLayer = nil
        isReady = false
        isActive = false

        if !isSupported {
            status = "Picture in Picture is not supported on this Mac."
        } else if isLive {
            status = "Live Picture in Picture becomes available when native live playback is connected."
        } else {
            status = "Picture in Picture becomes available when native video playback is connected."
        }
    }

    /// Attach a native AVPlayer source when one is available.
    func attach(player: AVPlayer, isLive: Bool) {
        attach(playerLayer: AVPlayerLayer(player: player), isLive: isLive)
    }

    /// Attach the layer used by AVKit to render PiP.
    func attach(playerLayer: AVPlayerLayer, isLive: Bool) {
        reset(isLive: isLive)
        guard isSupported else { return }

        guard let controller = AVPictureInPictureController(playerLayer: playerLayer) else {
            status = "Picture in Picture could not attach to this media source."
            return
        }

        self.playerLayer = playerLayer
        pictureInPictureController = controller
        controller.delegate = self
        refreshAvailability()
    }

    func start() {
        guard let controller = pictureInPictureController else {
            status = "Picture in Picture needs a native media source."
            return
        }

        guard controller.isPictureInPicturePossible else {
            isReady = false
            status = "Picture in Picture is not ready for this media source yet."
            return
        }

        controller.startPictureInPicture()
    }

    func stop() {
        pictureInPictureController?.stopPictureInPicture()
    }

    private func refreshAvailability() {
        guard let controller = pictureInPictureController else {
            isReady = false
            return
        }

        isReady = controller.isPictureInPicturePossible
        if isReady {
            status = "Picture in Picture is ready."
        }
    }

    nonisolated func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            self?.status = "Starting Picture in Picture..."
        }
    }

    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            self?.isActive = true
            self?.isReady = true
            self?.status = "Picture in Picture is active."
        }
    }

    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            self?.isActive = false
            self?.status = "Picture in Picture could not start: \(message)"
        }
    }

    nonisolated func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            self?.status = "Returning playback to YouGlass..."
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            self?.isActive = false
            self?.refreshAvailability()
        }
    }

    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(true)
    }
}
