import AppKit
import Foundation

extension YouTubeStore {
    func setShowContinueWatching(_ enabled: Bool) {
        showContinueWatching = enabled
        defaults.set(enabled, forKey: DefaultsKey.showContinueWatching)
    }

    func setThemeAccentHex(_ value: String) {
        guard let normalized = YouGlassThemeCustomization.normalizeHex(value) else {
            themeCustomization = .empty
            defaults.removeObject(forKey: DefaultsKey.themeCustomization)
            return
        }
        themeCustomization = YouGlassThemeCustomization(accentHex: normalized)
        if let data = try? JSONEncoder().encode(themeCustomization) {
            defaults.set(data, forKey: DefaultsKey.themeCustomization)
        }
    }

    func resetThemeCustomization() {
        themeCustomization = .empty
        defaults.removeObject(forKey: DefaultsKey.themeCustomization)
    }

    func cycleVisualTheme() {
        let themes = YouGlassThemeFamily.allCases
        guard let index = themes.firstIndex(of: visualTheme) else {
            setVisualTheme(themes[0])
            return
        }
        setVisualTheme(themes[(index + 1) % themes.count])
    }

    func toggleCommandPalette() {
        commandPalettePresented.toggle()
    }

    func requestSearchFocus() {
        if selectedVideo != nil {
            dismissPlayer()
        }
        selectedChannelItem = nil
        searchFocusRequestID = UUID()
    }

    func resumeLastVideo() {
        guard let video = continueWatching.first ?? recentlyWatched.first else {
            showSection("Library")
            return
        }
        openFromUserInteraction(video)
    }

    func minimizePlayer() {
        transitionInlinePlayer(compact: true)
    }

    func transitionInlinePlayer(compact: Bool) {
        guard let video = selectedVideo else { return }
        stopCurrentPlayback()
        closeDesktopPIPWindow()
        isInlinePlayerTransitioning = true
        isPlayerCompact = compact
        // As with desktop PiP, retire the source remote layer before mounting
        // its replacement. Both surfaces must not share a SwiftUI transaction.
        inlinePlayerTransitionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: PIPTransitionPolicy.sourceTeardownDelayNanoseconds)
            guard !Task.isCancelled, let self, self.selectedVideo?.id == video.id else { return }
            self.isInlinePlayerTransitioning = false
            self.inlinePlayerTransitionTask = nil
        }
    }

    func toggleMainWindowFullScreen() {
        NSApp.keyWindow?.toggleFullScreen(nil)
    }

    func shareVideo(_ video: VideoItem) {
        YouGlassNativeSharingController.shared.share(video: video)
    }

    func configureNativeMediaControls() {
        YouGlassNowPlayingController.shared.configure(
            play: { [weak self] in self?.sendPlaybackCommand(.togglePlayback) },
            pause: { [weak self] in self?.sendPlaybackCommand(.togglePlayback) },
            next: { [weak self] in self?.playNextInQueue() },
            previous: { [weak self] in self?.playPreviousInQueue() },
            skipForward: { [weak self] in self?.sendPlaybackCommand(.seek(15)) },
            skipBackward: { [weak self] in self?.sendPlaybackCommand(.seek(-15)) }
        )
    }

    func syncNowPlaying(
        video: VideoItem? = nil,
        currentTime: Double = 0,
        duration: Double = 0,
        isPlaying: Bool = false,
        playbackRate: Double = 1
    ) {
        YouGlassNowPlayingController.shared.update(
            video: video ?? selectedVideo,
            currentTime: currentTime,
            duration: duration,
            isPlaying: isPlaying,
            playbackRate: playbackRate
        )
    }
}
