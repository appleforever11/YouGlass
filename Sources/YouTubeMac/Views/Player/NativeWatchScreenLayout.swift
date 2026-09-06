import SwiftUI

extension NativeWatchScreen {
        func responsiveWatchLayout(
            availableSize: CGSize,
            topContentInset: CGFloat
        ) -> some View {
            let isWide = availableSize.width >= 900
            let horizontalPadding: CGFloat = isWide ? 18 : 12
            let columnSpacing: CGFloat = isWide ? 18 : 0
            let sideColumnWidth: CGFloat = isWide ? 280 : 0
            let pageBottomPadding: CGFloat = isWide ? 88 : 72
            let playerWidth = max(
                1,
                availableSize.width - (horizontalPadding * 2) - columnSpacing - sideColumnWidth
            )

            let documentWidth = max(1, availableSize.width - (horizontalPadding * 2))

            return YouGlassBoundedScrollView(accessibilityIdentifier: "player-main-scroll") {
                HStack(alignment: .top, spacing: columnSpacing) {
                    VStack(alignment: .leading, spacing: 0) {
                        watchDetailsContent(playerWidth: playerWidth)
                            .padding(.bottom, 24)

                        // Keep the compact rail in the same scroll hierarchy. It is
                        // hidden in the wide layout but remains mounted, avoiding a
                        // second structural transition around the WebKit player.
                        compactRelatedRail
                            .opacity(isWide ? 0 : 1)
                            .frame(height: isWide ? 0 : 88)
                            .clipped()
                            .allowsHitTesting(!isWide)
                    }
                    .frame(width: playerWidth, alignment: .topLeading)

                    // Keep the side rail mounted while its width collapses at the
                    // narrow breakpoint. It stays intrinsic-height so the parent
                    // watch document remains the only vertical scroll owner.
                    watchSideColumn
                        .frame(width: sideColumnWidth, alignment: .topLeading)
                        .opacity(isWide ? 1 : 0)
                        .clipped()
                        .allowsHitTesting(isWide)
                }
                // Measure the document as one intrinsic-height rectangle. The
                // player, metadata, comments, and Up Next rail now share one
                // scroll viewport; none of the columns is allowed to manufacture
                // a viewport-sized height that can swallow the page's scroll range.
                .frame(width: documentWidth, alignment: .topLeading)
                .padding(.horizontal, horizontalPadding)
                // The scroll viewport extends beneath the overlaid header. Keep
                // content below the measured shelf while leaving enough overlap
                // for the centered media halo to fade upward behind its material.
                // Clipping now occurs at the window edge, not at the header seam.
                .padding(.top, max(16, topContentInset + 16))
                // Leave a small amount of document space after the comments
                // viewport so the outer page can continue moving when the
                // pointer is outside the inner comments scroller.
                .padding(.bottom, pageBottomPadding)
            }
            .frame(width: availableSize.width, height: availableSize.height, alignment: .top)
            .clipShape(Rectangle())
            .clipped()
        }

        func watchDetailsContent(playerWidth: CGFloat? = nil) -> some View {
            VStack(alignment: .leading, spacing: 16) {
                NativeYouTubePlayer(
                    video: video,
                    palette: palette,
                    playbackController: playbackController,
                    autoMuteOnStart: store.autoMuteOnStart,
                    isCompact: false,
                    mediaSize: playerWidth.map { CGSize(width: $0, height: $0 / CompactPlayerMetrics.aspectRatio) },
                    onCompactDragChanged: nil,
                    onCompactDragEnded: nil,
                    onPlayerHoverChanged: nil,
                    onTransportVisibilityChanged: { visible in
                        playerTransportVisible = visible
                    }
                )
                .frame(
                    width: playerWidth,
                    height: playerWidth.map { $0 / CompactPlayerMetrics.aspectRatio }
                )
                .frame(maxWidth: playerWidth == nil ? .infinity : nil)
                // Keep the player interaction surface inside the media frame.
                // This is important because the action bar is a sibling below it;
                // an unconstrained transparent gesture surface can otherwise
                // intercept clicks intended for Like, Dislike, Share, or Save.
                .clipped()
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: PlayerMediaMetrics.cornerRadius,
                        style: .continuous
                    )
                )
                .modifier(
                    BlendedPlayerSurfaceModifier(
                        palette: palette,
                        ambientPalette: store.ambientPalette
                    )
                )
                // BlendedPlayerSurfaceModifier clips the media content while
                // preserving its ambient glow and shadow outside the rounded
                // edge. A second final clip here would cut that flow off again.
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: PlayerMediaMetrics.cornerRadius,
                        style: .continuous
                    )
                )
                // Host the expanded caption outside the NSView-backed player.
                // WebKit can keep its remote layer above SwiftUI content inside
                // the representable; this wrapper remains above that layer even
                // after the transport fades and only changes its resting inset.
                .overlay(alignment: .bottom) {
                    WatchCaptionOverlay(
                        controller: playbackController,
                        bottomInset: playerTransportVisible
                            ? PlayerTransportLayout.normalCaptionControlInset
                            : PlayerTransportLayout.normalCaptionRestingInset
                    )
                }

                YouGlassVideoTitleBlock(
                    title: video.title,
                    channel: video.channel,
                    eyebrow: nil,
                    palette: palette,
                    placement: .detail
                )
                .padding(.leading, 14)
                .padding(.trailing, 2)

                channelAndActions
                description
                commentComposer
                commentsList
            }
            // The comments section supplies its own finite viewport. Avoid a
            // fixed-size measurement wrapper here: the AppKit-backed page and
            // comments scrollers already size their hosted SwiftUI documents
            // explicitly.
        }

        var watchSideColumn: some View {
            VStack(alignment: .leading, spacing: 14) {
                if details?.liveChatID != nil || liveChatPage.isLive || liveChatPage.isAvailable {
                    LiveChatPanel(
                        video: video,
                        liveChatID: details?.liveChatID,
                        page: liveChatPage,
                        messages: chatMessages,
                        palette: palette,
                        onMessageSent: { message in
                            guard !chatMessages.contains(where: { $0.id == message.id }) else { return }
                            chatMessages = Array((chatMessages + [message]).suffix(80))
                        }
                    )
                        .frame(height: 310)
                }

                relatedRail
            }
            .frame(width: 280, alignment: .topLeading)
        }

        var compactRelatedRail: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Up Next")
                    .font(.system(size: 16, weight: .bold))

                if playerRecommendations.isEmpty {
                    Text("Recommendations will appear here when YouTube returns them.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                } else {
                    YouGlassBoundedScrollView(
                        axis: .horizontal,
                        accessibilityIdentifier: "player-related-scroll"
                    ) {
                        LazyHStack(spacing: 10) {
                            ForEach(playerRecommendations) { related in
                                Button {
                                    store.openFromUserInteraction(related)
                                } label: {
                                    RelatedVideoCard(video: related, palette: palette)
                                        .frame(width: 232)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                    .frame(height: 88)
                }
            }
        }

        var header: some View {
            HStack(spacing: 12) {
                Button(action: { store.closePlayer() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(GlassIconButtonStyle(palette: palette))

                YouGlassVideoTitleBlock(
                    title: video.title,
                    channel: video.channel,
                    eyebrow: "Now Playing",
                    palette: palette,
                    placement: .header
                )
                // Give the title every flexible point between the close button
                // and the fixed control shelf so long titles do not wrap early
                // into a narrow, left-compressed column.
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                headerControlGroup
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            // Fade the fixed header into the ambient watch surface instead of
            // ending it as a separate opaque rectangle. The mask keeps the
            // controls legible while the lower edge reveals the same backdrop
            // that continues behind the player and Up Next rail.
            .background {
                Rectangle()
                    .fill(.thinMaterial)
                    .opacity(0.84)
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: 0),
                                .init(color: .white, location: 0.76),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            }
            // The watch screen owns the shared fade behind both header and
            // page; do not add a divider or a second lower-edge rectangle here.
            .zIndex(4)
        }

        private var headerControlGroup: some View {
            HStack(spacing: 3) {
                Button {
                    store.presentDesktopPIP()
                } label: {
                    Label("PIP", systemImage: "pip.enter")
                        .labelStyle(.titleAndIcon)
                        .frame(width: 72, height: 32)
                }
                .buttonStyle(PlayerHeaderControlButtonStyle(palette: palette, minimumWidth: 72))
                .accessibilityLabel("Picture in Picture")
                .accessibilityHint("Open this video in a floating desktop window")
                .help("Picture in Picture")

                Capsule()
                    .fill(palette.stroke.opacity(0.36))
                    .frame(width: 1, height: 20)
                    .padding(.horizontal, 2)
                    .allowsHitTesting(false)

                Button {
                    queuePresented.toggle()
                } label: {
                    Image(systemName: queuePresented ? "list.bullet.rectangle.portrait.fill" : "list.bullet.rectangle.portrait")
                }
                .buttonStyle(PlayerHeaderControlButtonStyle(palette: palette))
                .accessibilityLabel(queuePresented ? "Hide playback queue" : "Show playback queue")
                .help("Playback queue")

                PlaybackSpeedMenu(
                    palette: palette,
                    playbackController: playbackController,
                    onSelect: { rate in
                        store.sendPlaybackCommand(.setPlaybackRate(rate))
                    }
                )

                Button(action: store.minimizePlayer) {
                    Image(systemName: "minus")
                }
                .buttonStyle(PlayerHeaderControlButtonStyle(palette: palette))
                .accessibilityLabel("Minimize player")
                .help("Mini-player")

                Button(action: store.toggleMainWindowFullScreen) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(PlayerHeaderControlButtonStyle(palette: palette))
                .accessibilityLabel("Toggle full screen")
                .help("Full screen")

                Button {
                    saved.toggle()
                    store.toggleSaved(video)
                } label: {
                    Image(systemName: saved ? "bookmark.fill" : "bookmark")
                }
                .buttonStyle(PlayerHeaderControlButtonStyle(palette: palette))
                .accessibilityLabel(saved ? "Remove from Watch Later" : "Save to Watch Later")
                .help(saved ? "Remove from Watch Later" : "Save to Watch Later")
            }
            .padding(4)
            .modifier(PlayerControlShelf(palette: palette))
            .fixedSize(horizontal: true, vertical: false)
        }
}
