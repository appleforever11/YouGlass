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
                    .opacity(playbackController.isSurfaceReady ? 1 : 0)
                    .animation(.easeOut(duration: 0.16), value: playbackController.isSurfaceReady)
                    .allowsHitTesting(false)

                    // YouTube's web player can take a few frames to create its
                    // media element. Keep the already-known thumbnail on screen
                    // until that player reports a real duration or playing state.
                    // This removes the white WebKit flash and makes the first
                    // presentation feel like one stable native surface.
                    RemoteImage(url: video.thumbnailURL)
                        .id(video.id)
                        .overlay(Color.black.opacity(0.18))
                        .opacity(playbackController.isSurfaceReady ? 0 : 1)
                        .animation(.easeOut(duration: 0.16), value: playbackController.isSurfaceReady)
                        .allowsHitTesting(false)
                }
                // Keep the media layer visual-only. A separate SwiftUI interaction
                // layer below the controls owns center taps and PIP dragging, so
                // the visible transport buttons never share an AppKit hit-test
                // path with the video surface.
                .allowsHitTesting(false)
                PlayerInteractionLayer(
                    isCompact: isCompact,
                    reservedTop: isCompact ? 104 : 0,
                    reservedBottom: isCompact ? 142 : 132,
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
                .allowsHitTesting(false)

                if playbackController.isCaptionsEnabled,
                   !playbackController.captionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(playbackController.captionText)
                        .font(.system(size: isCompact ? 16 : 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .lineSpacing(2)
                        .padding(.horizontal, isCompact ? 10 : 16)
                        .padding(.vertical, isCompact ? 5 : 7)
                        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: .black.opacity(0.86), radius: 4, y: 2)
                        .frame(maxWidth: isCompact ? 520 : 980)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, isCompact ? 18 : 72)
                        .padding(.bottom, captionBottomInset)
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("player-caption-text")
                        .zIndex(3)
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
            .onHover(perform: handlePlayerHover)
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
                    controlsVisible = false
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
                // The normal player starts clean and reveals its transport only
                // after the pointer enters the media surface. Compact/PIP keeps
                // its always-available bottom transport independently.
                if !isCompact {
                    controlsVisible = false
                }
            }
            .animation(.easeOut(duration: 0.18), value: transportControlsVisible)
        }
}
