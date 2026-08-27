import SwiftUI

extension NativeWatchScreen {
        func responsiveWatchLayout(availableSize: CGSize) -> some View {
            let isWide = availableSize.width >= 900
            let horizontalPadding: CGFloat = isWide ? 18 : 12
            let columnSpacing: CGFloat = isWide ? 18 : 0
            let sideColumnWidth: CGFloat = isWide ? 280 : 0
            let playerWidth = max(
                1,
                availableSize.width - (horizontalPadding * 2) - columnSpacing - sideColumnWidth
            )

            let documentWidth = max(1, availableSize.width - (horizontalPadding * 2))

            return ScrollView(showsIndicators: true) {
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
                    // narrow breakpoint. Its own recommendation list stays bounded
                    // so the parent watch document remains the only page scrollbar.
                    watchSideColumn
                        .frame(width: sideColumnWidth, height: availableSize.height, alignment: .top)
                        .opacity(isWide ? 1 : 0)
                        .clipped()
                        .allowsHitTesting(isWide)
                }
                // Measure the document as one rectangle. The player, metadata, and
                // Up Next rail now share one scroll viewport, so no indicator or
                // overflow strip can be inserted between the two columns.
                .frame(width: documentWidth, alignment: .topLeading)
                .frame(minHeight: availableSize.height, alignment: .topLeading)
                .padding(.horizontal, horizontalPadding)
                // This is intentionally translucent. PlayerAmbientSurface is
                // mounted behind the watch screen; an opaque content fill made
                // each theme stop abruptly at the player/page boundary.
                .background(palette.content.opacity(palette.isDark ? 0.78 : 0.84))
            }
            .frame(width: availableSize.width, height: availableSize.height, alignment: .top)
            .background(palette.window.opacity(palette.isDark ? 0.62 : 0.72))
            .clipShape(Rectangle())
            .clipped()
            .accessibilityIdentifier("player-main-scroll")
        }

        func watchDetailsContent(playerWidth: CGFloat? = nil) -> some View {
            VStack(alignment: .leading, spacing: 16) {
                NativeYouTubePlayer(
                    video: video,
                    palette: palette,
                    playbackController: playbackController,
                    autoMuteOnStart: store.autoMuteOnStart,
                    isCompact: false,
                    onCompactDragChanged: nil,
                    onCompactDragEnded: nil,
                    onPlayerHoverChanged: nil
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
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .modifier(
                    BlendedPlayerSurfaceModifier(
                        palette: palette,
                        ambientPalette: store.ambientPalette
                    )
                )
                // BlendedPlayerSurfaceModifier clips the media content while
                // preserving its ambient glow and shadow outside the rounded
                // edge. A second final clip here would cut that flow off again.
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

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
            .frame(width: 280, alignment: .top)
            .frame(maxHeight: .infinity, alignment: .top)
        }

        var compactRelatedRail: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Up Next")
                    .font(.system(size: 16, weight: .bold))

                if recommendations.isEmpty {
                    Text("Recommendations will appear here when YouTube returns them.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 10) {
                            ForEach(recommendations) { related in
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
                .frame(maxWidth: 640, alignment: .leading)
                .layoutPriority(1)

                Spacer()

                Button {
                    store.presentDesktopPIP()
                } label: {
                    Label("PIP", systemImage: "pip.enter")
                        .font(.system(size: 12, weight: .semibold))
                        .labelStyle(.titleAndIcon)
                        .frame(minWidth: 68, minHeight: 34)
                        .contentShape(Capsule())
                }
                .buttonStyle(GlassCapsuleButtonStyle(palette: palette))
                .accessibilityLabel("Picture in Picture")
                .accessibilityHint("Open this video in a floating desktop window")
                .help("Picture in Picture")

                Button {
                    queuePresented.toggle()
                } label: {
                    Image(systemName: queuePresented ? "list.bullet.rectangle.portrait.fill" : "list.bullet.rectangle.portrait")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(GlassIconButtonStyle(palette: palette))
                .accessibilityLabel(queuePresented ? "Hide playback queue" : "Show playback queue")
                .help("Playback queue")

                Menu {
                    ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                        Button(rate == 1 ? "Normal" : "\(rate)x") {
                            store.sendPlaybackCommand(.setPlaybackRate(rate))
                        }
                    }
                } label: {
                    Image(systemName: "speedometer")
                        .font(.system(size: 16, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 34, height: 34)
                .foregroundStyle(palette.text)
                .help("Playback speed")

                Button(action: store.minimizePlayer) {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(GlassIconButtonStyle(palette: palette))
                .accessibilityLabel("Minimize player")
                .help("Mini-player")

                Button(action: store.toggleMainWindowFullScreen) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 15, weight: .semibold))
                }
                .buttonStyle(GlassIconButtonStyle(palette: palette))
                .accessibilityLabel("Toggle full screen")
                .help("Full screen")

                Button {
                    saved.toggle()
                    store.toggleSaved(video)
                } label: {
                    Image(systemName: saved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(GlassIconButtonStyle(palette: palette))
                .accessibilityLabel(saved ? "Remove from Watch Later" : "Save to Watch Later")
                .help(saved ? "Remove from Watch Later" : "Save to Watch Later")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.thinMaterial)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(palette.stroke.opacity(0.65))
                    .frame(height: 1)
                    .allowsHitTesting(false)
            }
            .zIndex(4)
        }
}
