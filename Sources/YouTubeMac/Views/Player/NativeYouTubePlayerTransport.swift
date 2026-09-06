import SwiftUI

extension NativeYouTubePlayer {
        var compactTransportControls: some View {
            VStack(spacing: 6) {
                playbackScrubber

                // Preserve the proven compact/PIP geometry independently from the
                // full-player shelf below.
                GeometryReader { geometry in
                    let buttonSize = min(34, max(22, (geometry.size.width - 15) / 6))

                    HStack(spacing: 3) {
                        Spacer(minLength: 0)
                        PlayerControlButton(
                            symbol: playbackController.isPlaying ? "pause.fill" : "play.fill",
                            help: playbackController.isPlaying ? "Pause" : "Play",
                            controlSize: buttonSize,
                            action: playbackController.togglePlayback
                        )
                        PlayerControlButton(symbol: "gobackward.15", help: "Back 15 seconds", controlSize: buttonSize) {
                            playbackController.seek(by: -15)
                        }
                        PlayerControlButton(symbol: "goforward.15", help: "Forward 15 seconds", controlSize: buttonSize) {
                            playbackController.seek(by: 15)
                        }
                        PlayerControlButton(
                            symbol: playbackController.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                            help: playbackController.isMuted ? "Unmute" : "Mute",
                            controlSize: buttonSize,
                            action: playbackController.toggleMute
                        )
                        PlayerControlButton(
                            symbol: playbackController.isCaptionsEnabled ? "captions.bubble.fill" : "captions.bubble",
                            help: playbackController.isCaptionsEnabled ? "Turn off closed captions" : "Turn on closed captions",
                            controlSize: buttonSize,
                            action: playbackController.toggleCaptions
                        )
                        .accessibilityIdentifier("captions-button")
                        PlayerControlButton(
                            symbol: playbackController.isPictureInPictureActive ? "pip.exit" : "pip.enter",
                            help: playbackController.isPictureInPictureActive ? "Exit Picture in Picture" : "Picture in Picture",
                            controlSize: buttonSize,
                            action: {
                                playbackController.togglePictureInPicture {
                                    store.expandPlayer()
                                }
                            }
                        )
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 38)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
            .opacity(transportControlsVisible && !playbackController.canRetry ? 1 : 0)
            .animation(
                .easeOut(duration: PlayerTransportLayout.normalControlTransitionDuration),
                value: transportControlsVisible
            )
            .allowsHitTesting(transportControlsVisible && !playbackController.canRetry)
            .accessibilityHidden(!transportControlsVisible || playbackController.canRetry)
            .zIndex(22)
        }

        var normalTransportControls: some View {
            VStack(spacing: 8) {
                playbackScrubber

                ZStack {
                    // Center the primary playback cluster against the media
                    // frame itself. Status text and PIP are secondary chrome;
                    // including them in this HStack made the visible Play
                    // button sit noticeably left of the video's center.
                    HStack(spacing: PlayerTransportLayout.normalSpacing) {
                        PlayerControlButton(
                            symbol: playbackController.isPlaying ? "pause.fill" : "play.fill",
                            help: playbackController.isPlaying ? "Pause" : "Play",
                            controlSize: PlayerTransportLayout.normalButtonSize,
                            action: playbackController.togglePlayback
                        )
                        PlayerControlButton(symbol: "gobackward.15", help: "Back 15 seconds") {
                            playbackController.seek(by: -15)
                        }
                        PlayerControlButton(symbol: "goforward.15", help: "Forward 15 seconds") {
                            playbackController.seek(by: 15)
                        }
                        PlayerControlButton(
                            symbol: playbackController.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                            help: playbackController.isMuted ? "Unmute" : "Mute",
                            action: playbackController.toggleMute
                        )
                        PlayerControlButton(
                            symbol: playbackController.isCaptionsEnabled ? "captions.bubble.fill" : "captions.bubble",
                            help: playbackController.isCaptionsEnabled ? "Turn off closed captions" : "Turn on closed captions",
                            action: playbackController.toggleCaptions
                        )
                        .accessibilityIdentifier("captions-button")
                    }

                    HStack(spacing: PlayerTransportLayout.normalSpacing) {
                        Text(playbackController.isMuted ? "Click to unmute" : playbackController.status)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .frame(width: PlayerTransportLayout.normalStatusWidth, alignment: .leading)

                        PlayerControlButton(
                            symbol: "pip.enter",
                            help: "Picture in Picture",
                            action: { store.presentDesktopPIP() }
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 18)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
            }
            .frame(maxWidth: 820)
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, PlayerTransportLayout.normalBottomPadding)
            .frame(maxWidth: .infinity, alignment: .center)
            .background {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .opacity(transportControlsVisible && !playbackController.canRetry ? 1 : 0)
            .animation(
                .easeOut(duration: PlayerTransportLayout.normalControlTransitionDuration),
                value: transportControlsVisible
            )
            .allowsHitTesting(transportControlsVisible && !playbackController.canRetry)
            .accessibilityHidden(!transportControlsVisible || playbackController.canRetry)
            .zIndex(10)
        }

        var playbackScrubber: some View {
            PlaybackScrubber(
                value: scrubberBinding,
                duration: durationForScrubber,
                elapsedLabel: formatPlaybackTime(displayedScrubTime),
                durationLabel: formatPlaybackTime(playbackController.duration),
                onEditingChanged: handleScrubbing
            )
        }

        var durationForScrubber: Double {
            max(1, max(playbackController.duration, playbackController.currentTime))
        }

        var displayedScrubTime: Double {
            let value = isScrubbing ? scrubPosition : playbackController.currentTime
            return min(max(0, value), durationForScrubber)
        }

        var transportControlsVisible: Bool {
            controlsVisible
        }

        var captionBottomInset: CGFloat {
            if isCompact {
                return transportControlsVisible
                    ? PlayerTransportLayout.compactCaptionControlInset
                    : PlayerTransportLayout.compactCaptionRestingInset
            }
            return transportControlsVisible
                ? PlayerTransportLayout.normalCaptionControlInset
                : PlayerTransportLayout.normalCaptionRestingInset
        }

        var scrubberBinding: Binding<Double> {
            Binding(
                get: { displayedScrubTime },
                set: {
                    scrubPosition = min(max(0, $0), durationForScrubber)
                    isScrubbing = true
                }
            )
        }

        func handleScrubbing(_ editing: Bool) {
            if editing {
                scrubPosition = displayedScrubTime
                isScrubbing = true
            } else {
                let target = min(max(0, scrubPosition), durationForScrubber)
                isScrubbing = false
                playbackController.seek(to: target)
            }
        }

        func formatPlaybackTime(_ seconds: Double) -> String {
            guard seconds.isFinite, seconds > 0 else { return "0:00" }
            let totalSeconds = max(0, Int(seconds.rounded(.down)))
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let remainder = totalSeconds % 60
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, remainder)
            }
            return String(format: "%d:%02d", minutes, remainder)
        }

        func handlePlayerHover(_ hovering: Bool) {
            guard isPointerHovering != hovering else { return }
            isPointerHovering = hovering
            onPlayerHoverChanged?(hovering)

            if hovering {
                revealControls()
            } else {
                let exitGracePeriod = isCompact
                    ? PlayerTransportLayout.compactControlExitGracePeriod
                    : PlayerTransportLayout.normalControlExitGracePeriod
                scheduleControlsHide(after: exitGracePeriod)
            }
        }

        func revealControls() {
            controlsHideTask?.cancel()
            setTransportControlsVisible(true)
            guard !isPointerHovering else { return }
            scheduleControlsHide(after: 2.2)
        }

        func setTransportControlsVisible(_ visible: Bool) {
            guard controlsVisible != visible else { return }
            controlsVisible = visible
            onTransportVisibilityChanged?(visible)
        }

        func scheduleControlsHide(after seconds: Double) {
            controlsHideTask?.cancel()
            controlsHideTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                guard !Task.isCancelled else { return }
                guard !isPointerHovering else {
                    controlsHideTask = nil
                    return
                }
                setTransportControlsVisible(false)
                controlsHideTask = nil
            }
        }
}
