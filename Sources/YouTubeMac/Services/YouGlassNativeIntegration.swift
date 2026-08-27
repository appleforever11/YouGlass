import AppKit
import Foundation
import MediaPlayer

@MainActor
final class YouGlassNowPlayingController {
    static let shared = YouGlassNowPlayingController()

    private var configured = false
    private var playHandler: (() -> Void)?
    private var pauseHandler: (() -> Void)?
    private var nextHandler: (() -> Void)?
    private var previousHandler: (() -> Void)?
    private var skipForwardHandler: (() -> Void)?
    private var skipBackwardHandler: (() -> Void)?

    func configure(
        play: @escaping () -> Void,
        pause: @escaping () -> Void,
        next: @escaping () -> Void,
        previous: @escaping () -> Void,
        skipForward: @escaping () -> Void,
        skipBackward: @escaping () -> Void
    ) {
        playHandler = play
        pauseHandler = pause
        nextHandler = next
        previousHandler = previous
        skipForwardHandler = skipForward
        skipBackwardHandler = skipBackward
        guard !configured else { return }
        configured = true

        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.playHandler?() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.pauseHandler?() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.nextHandler?() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.previousHandler?() }
            return .success
        }
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.skipForwardHandler?() }
            return .success
        }
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.skipBackwardHandler?() }
            return .success
        }
    }

    func update(
        video: VideoItem?,
        currentTime: Double = 0,
        duration: Double = 0,
        isPlaying: Bool = false,
        playbackRate: Double = 1
    ) {
        let center = MPNowPlayingInfoCenter.default()
        guard let video else {
            center.nowPlayingInfo = nil
            center.playbackState = .stopped
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: video.title,
            MPMediaItemPropertyArtist: video.channel,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: max(0, currentTime),
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? max(0.25, playbackRate) : 0
        ]
        if duration.isFinite, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        info[MPNowPlayingInfoPropertyAssetURL] = video.playbackURL
        center.nowPlayingInfo = info
        center.playbackState = isPlaying ? .playing : .paused

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.nextTrackCommand.isEnabled = nextHandler != nil
        commandCenter.previousTrackCommand.isEnabled = previousHandler != nil
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.isEnabled = true
    }
}

@MainActor
final class YouGlassDockMenuController: NSObject {
    static let shared = YouGlassDockMenuController()

    weak var store: YouTubeStore?

    func menu() -> NSMenu {
        let menu = NSMenu()
        let resume = NSMenuItem(
            title: "Resume Last Video",
            action: #selector(resumeLastVideo),
            keyEquivalent: ""
        )
        resume.target = self
        resume.isEnabled = store?.continueWatching.first != nil
        menu.addItem(resume)

        let watchLater = NSMenuItem(
            title: "Open Watch Later",
            action: #selector(openWatchLater),
            keyEquivalent: ""
        )
        watchLater.target = self
        menu.addItem(watchLater)

        menu.addItem(.separator())
        let palette = NSMenuItem(
            title: "Command Palette",
            action: #selector(openCommandPalette),
            keyEquivalent: ""
        )
        palette.target = self
        menu.addItem(palette)
        return menu
    }

    @objc private func resumeLastVideo() {
        store?.resumeLastVideo()
    }

    @objc private func openWatchLater() {
        store?.showSection("Watch Later")
    }

    @objc private func openCommandPalette() {
        store?.commandPalettePresented = true
    }
}

@MainActor
final class YouGlassNativeSharingController {
    static let shared = YouGlassNativeSharingController()

    private var activePicker: NSSharingServicePicker?

    func share(video: VideoItem) {
        guard let contentView = NSApp.keyWindow?.contentView else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(video.playbackURL.absoluteString, forType: .string)
            return
        }
        let picker = NSSharingServicePicker(items: [video.playbackURL])
        activePicker = picker
        picker.show(
            relativeTo: contentView.bounds,
            of: contentView,
            preferredEdge: .minY
        )
    }
}
