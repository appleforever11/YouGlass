import SwiftUI

extension NativeYouTubePlayer {
        var body: some View {
            ZStack(alignment: .bottomLeading) {
                ZStack {
                    Color.black

                    YouTubeInlinePlayerView(
                        video: video,
                        controller: playbackController,
                        autoMuteOnStart: autoMuteOnStart
                    )
                    // WKWebView is deliberately playback-only. Keeping it out of
                    // the hit-test chain lets the native toolbar and surface tap
                    // handler receive clicks consistently instead of letting
                    // YouTube's page layer swallow them.
                    // Keep WebKit renderable while awaiting the first frame.
                    // Zero opacity can suppress remote-layer rendering during
                    // compact/PIP attachment. The opaque thumbnail below covers
                    // startup without creating a frame-readiness dependency.
                    .allowsHitTesting(false)

                }
                .overlay {
                    // The fill-scaled thumbnail must not participate in player
                    // sizing, even after it becomes transparent. Its image
                    // aspect ratio can otherwise enlarge the ZStack beyond the
                    // visible media and push transport controls below its bounds.
                    loadingThumbnail
                }
                // Keep the media layer visual-only. A separate SwiftUI interaction
                // layer below the controls owns center taps and PIP dragging, so
                // the visible transport buttons never share an AppKit hit-test
                // path with the video surface.
                .allowsHitTesting(false)
                PlayerInteractionLayer(
                    isCompact: isCompact,
                    reservedTop: isCompact ? 54 : 0,
                    reservedBottom: isCompact ? 98 : 132,
                    onTap: {
                        revealControls()
                        playbackController.togglePlayback()
                    },
                    onCompactDragChanged: isCompact ? onCompactDragChanged : nil,
                    onCompactDragEnded: isCompact ? onCompactDragEnded : nil
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(0)

                LinearGradient(
                    colors: [.black.opacity(0.28), .clear, .black.opacity(0.24)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(transportControlsVisible ? 1 : 0)
                .animation(
                    .easeOut(duration: PlayerTransportLayout.normalControlTransitionDuration),
                    value: transportControlsVisible
                )
                .allowsHitTesting(false)

                if isCompact {
                    nativeCaptionOverlay
                }

                if playbackController.canRetry {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: isCompact ? 18 : 24, weight: .semibold))
                            .foregroundStyle(.yellow)
                        Text(playbackController.status)
                            .font(.system(size: isCompact ? 11 : 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Button {
                            playbackController.retryPlayback()
                            revealControls()
                        } label: {
                            Label("Retry playback", systemImage: "arrow.clockwise")
                                .font(.system(size: isCompact ? 11 : 12, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(isCompact ? .small : .regular)
                    }
                    .padding(isCompact ? 10 : 16)
                    .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .zIndex(2)
                }

            }
            .frame(width: mediaSize?.width, height: mediaSize?.height)
            // Keep the native toolbar outside the media ZStack. This gives the
            // SwiftUI buttons the first responder path and prevents the media
            // gesture surface from swallowing clicks during WebKit resizes.
            .overlay(alignment: .bottom) {
                if isCompact {
                    compactTransportControls
                } else {
                    normalTransportControls
                }
            }
            .background(.black)
            .onHover { hovering in
                if isCompact { handlePlayerHover(hovering) }
            }
            .overlay {
                if !isCompact {
                    PlayerHoverTrackingView(onHover: handlePlayerHover)
                }
            }
            // YouTubeInlinePlayerHostView owns the WebKit layer’s rounded clip.
            // Avoid applying a second SwiftUI mask to a remote WebKit layer while
            // AppKit is receiving a layer-tree transaction.
            .overlay {
                RoundedRectangle(
                    cornerRadius: PlayerMediaMetrics.cornerRadius,
                    style: .continuous
                )
                    .stroke(.white.opacity(0.12), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .onDisappear {
                controlsHideTask?.cancel()
            }
            .onChange(of: video.id) { _, _ in
                scrubPosition = 0
                isScrubbing = false
                if isPointerHovering {
                    revealControls()
                } else {
                    setTransportControlsVisible(false)
                }
            }
            .onChange(of: playbackController.isSurfaceReady) { _, isReady in
                // WebKit can finish creating the media surface after this view
                // appears. Reveal the native transport when the first usable
                // frame is ready instead of letting the initial timer expire
                // while the player is still loading.
                if isReady, isPointerHovering {
                    revealControls()
                }
            }
            .onAppear {
                // Both player surfaces start with a brief discoverable control
                // state. Normal playback then waits for media hover, while
                // compact/PIP uses the same transient hover contract.
                if isCompact || isPointerHovering {
                    revealControls()
                } else {
                    setTransportControlsVisible(false)
                }
            }
        }

        private var loadingThumbnail: some View {
            RemoteImage(url: video.thumbnailURL)
                .id(video.id)
                .overlay(Color.black.opacity(0.18))
                .opacity(playbackController.isSurfaceReady ? 0 : 1)
                .animation(.easeOut(duration: 0.16), value: playbackController.isSurfaceReady)
                .allowsHitTesting(false)
        }

        /// Keep the native caption surface mounted independently of the
        /// transport chrome. Hover only changes its resting inset; it must not
        /// remove the current caption line when the controls fade out.
        var nativeCaptionOverlay: some View {
            NativePlayerCaptionOverlay(
                text: playbackController.captionText,
                bottomInset: captionBottomInset,
                isCompact: isCompact
            )
        }
}
