import SwiftUI

extension NativeWatchScreen {
        var body: some View {
            Group {
                if isCompact {
                    // The desktop PIP host already enforces a 16:9 window. Let
                    // the player consume the complete proposed content rect
                    // instead of asking a nested GeometryReader to infer its
                    // height inside a VStack. The latter can receive an
                    // unbounded/zero height during the hosting view's first
                    // layout pass, which hides both the video and transport row.
                    NativeYouTubePlayer(
                        video: video,
                        palette: palette,
                        playbackController: playbackController,
                        autoMuteOnStart: store.autoMuteOnStart,
                        isCompact: true,
                        mediaSize: compactMediaSize,
                        onCompactDragChanged: onCompactDragChanged,
                        onCompactDragEnded: onCompactDragEnded,
                        onPlayerHoverChanged: onPlayerHoverChanged,
                        onTransportVisibilityChanged: nil
                    )
                    .aspectRatio(CompactPlayerMetrics.aspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .layoutPriority(1)
                    .accessibilityIdentifier("player-main-scroll")
                } else {
                    // Keep one watch-screen hierarchy mounted while the window
                    // resizes. An AppKit size reader avoids the macOS 26
                    // GeometryReader copy crash that occurs when this page is
                    // presented with its AppKit-backed scroll view.
                    ZStack(alignment: .topLeading) {
                        // Keep the page viewport behind the translucent title
                        // shelf. The document reserves the measured shelf height,
                        // while the media halo can continue upward through that
                        // reserved area instead of being clipped into a straight
                        // line at the shelf's lower edge.
                        responsiveWatchLayout(
                            availableSize: watchAvailableSize,
                            topContentInset: watchHeaderHeight
                        )

                        YouGlassSizeReader { size in
                            guard size != watchAvailableSize else { return }
                            watchAvailableSize = size
                        }
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)

                        header
                            .frame(maxWidth: .infinity, alignment: .top)
                            .overlay {
                                YouGlassSizeReader { size in
                                    let measuredHeight = ceil(size.height)
                                    guard measuredHeight > 1,
                                          abs(measuredHeight - watchHeaderHeight) > 0.5 else {
                                        return
                                    }
                                    watchHeaderHeight = measuredHeight
                                }
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                            }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // The player overlay owns the shared ambient backdrop. This single
            // low-contrast fade sits behind the header and page together, so
            // their boundary reads as one surface instead of a hard horizontal
            // strip where two independently painted rectangles meet.
            .background {
                LinearGradient(
                    stops: [
                        .init(color: palette.content.opacity(palette.isDark ? 0.70 : 0.52), location: 0),
                        .init(color: palette.content.opacity(palette.isDark ? 0.52 : 0.36), location: 0.20),
                        .init(color: palette.content.opacity(palette.isDark ? 0.24 : 0.16), location: 0.44),
                        .init(color: .clear, location: 0.72)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .clipShape(Rectangle())
            .overlay(alignment: .topTrailing) {
                if !isCompact, queuePresented {
                    PlayerQueuePanel(store: store, palette: palette)
                        .padding(.top, watchHeaderHeight + 8)
                        .padding(.trailing, 14)
                        .zIndex(40)
                }
            }
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(.space) {
                guard !commentFieldFocused else { return .ignored }
                playbackController.togglePlayback()
                return .handled
            }
            .onKeyPress(.leftArrow) {
                guard !commentFieldFocused else { return .ignored }
                playbackController.seek(by: -5)
                return .handled
            }
            .onKeyPress(.rightArrow) {
                guard !commentFieldFocused else { return .ignored }
                playbackController.seek(by: 5)
                return .handled
            }
            .onKeyPress(characters: CharacterSet(charactersIn: "jJkKlLmMcC")) { press in
                guard !commentFieldFocused else { return .ignored }
                switch press.characters.lowercased() {
                case "j": playbackController.seek(by: -10)
                case "k": playbackController.togglePlayback()
                case "l": playbackController.seek(by: 10)
                case "m": playbackController.toggleMute()
                case "c": playbackController.toggleCaptions()
                default: return .ignored
                }
                return .handled
            }
            .task(id: video.id) {
                chatMessages = []
                liveChatPage = .unavailable
                commentsLoading = true
                commentsLoadingMore = false
                commentLoadRetryToken = nil
                commentChannelID = nil
                commentText = ""
                commentStatus = nil
                commentSubmitting = false
                subscribed = false
                subscriptionStatusResolved = false
                authorizingComments = false
                commentAuthorizationRequired = store.commentAuthorizationRequired
                didAutoAdvance = false
                saved = store.isSaved(video)
                liked = store.isLocallyLiked(video)

                // Resolve account state before slower comments/details requests. A
                // stalled public-data request must never leave this control at
                // "Checking..." when the signed-in subscription list is ready.
                subscribed = await store.resolveSubscriptionStatus(
                    channelID: video.channelID,
                    channelName: video.channel
                )
                subscriptionStatusResolved = true

                async let loadedComments = store.loadCommentPage(for: video)
                async let loadedRecommendations = store.loadRecommendations(for: video)
                async let loadedDetails = store.loadVideoDetails(for: video)
                commentPage = await loadedComments
                commentChannelID = commentPage.channelID
                commentsLoading = false
                let nextRecommendations = await loadedRecommendations
                guard !Task.isCancelled, store.selectedVideo?.id == video.id else { return }
                recommendations = nextRecommendations
                store.appendPlaybackCandidates(nextRecommendations)
                advanceAfterPlaybackFinishesIfPossible()
                details = await loadedDetails
                let channelID = details?.channelID ?? commentChannelID ?? video.channelID
                if channelID != video.channelID {
                    subscribed = await store.resolveSubscriptionStatus(
                        channelID: channelID,
                        channelName: video.channel
                    )
                }
                if let rating = details?.rating {
                    liked = rating == "like"
                    disliked = rating == "dislike"
                }
                if details?.isLive == true || details?.liveChatID != nil {
                    await pollLiveChat(liveChatID: details?.liveChatID)
                }
            }
            .task(id: "playback-checkpoint-\(video.id)-\(isCompact)") {
                // Keep a small rolling checkpoint so dismissing the player, moving
                // it to desktop PIP, or a process interruption can resume close to
                // the last visible position without touching the media element.
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    guard !Task.isCancelled else { return }
                    store.savePlaybackPosition(
                        for: video,
                        at: playbackController.currentTime,
                        duration: playbackController.duration
                    )
                }
            }
            .onAppear {
                let controller = playbackController
                let currentStore = store
                playbackStopHandlerToken = store.registerPlaybackStopHandler { [weak controller, weak currentStore] in
                    guard let controller else { return }
                    currentStore?.savePlaybackPosition(
                        for: video,
                        at: controller.currentTime,
                        duration: controller.duration
                    )
                    controller.stopPlayback()
                }
                playbackCommandHandlerToken = store.registerPlaybackCommandHandler { [weak controller] command in
                    guard let controller else { return }
                    switch command {
                    case .togglePlayback: controller.togglePlayback()
                    case .seek(let seconds): controller.seek(by: seconds)
                    case .toggleMute: controller.toggleMute()
                    case .toggleCaptions: controller.toggleCaptions()
                    case .setPlaybackRate(let rate): controller.setPlaybackRate(rate)
                    case .retry: controller.retryPlayback()
                    }
                }
                store.configureNativeMediaControls()
                syncNativeNowPlaying()
                playbackController.restorePlaybackPosition(
                    store.playbackPosition(for: video.id),
                    for: video.id
                )
                store.setAmbientPalette(playbackController.ambientPalette)
            }
            .background {
                WatchPlaybackObservation(
                    controller: playbackController,
                    onAmbient: { store.setAmbientPalette($0) },
                    onTransport: syncNativeNowPlaying,
                    onFinish: advanceAfterPlaybackFinishesIfPossible
                )
            }
            .onChange(of: store.subscriptions) { _, _ in
                guard subscriptionStatusResolved else { return }
                subscribed = store.isSubscribed(
                    channelID: details?.channelID ?? commentChannelID ?? video.channelID,
                    channelName: video.channel
                )
            }
            .onDisappear {
                // Save before the controller is torn down. The store's stop
                // handler normally runs first during dismiss/expand, but this
                // also covers SwiftUI-driven view replacement and app teardown.
                store.savePlaybackPosition(
                    for: video,
                    at: playbackController.currentTime,
                    duration: playbackController.duration
                )
                if let playbackStopHandlerToken {
                    store.unregisterPlaybackStopHandler(playbackStopHandlerToken)
                }
                playbackStopHandlerToken = nil
                if let playbackCommandHandlerToken {
                    store.unregisterPlaybackCommandHandler(playbackCommandHandlerToken)
                }
                playbackCommandHandlerToken = nil
                store.resetAmbientPalette()
            }
    }

    func advanceAfterPlaybackFinishesIfPossible() {
        guard playbackController.didFinish, !didAutoAdvance else { return }
        guard store.queueAutoplay else {
            playbackController.didFinish = false
            syncNativeNowPlaying()
            return
        }
        guard store.nextQueuedVideo != nil else {
            // Recommendation loading may still be in flight. Keep the ended
            // state latched so the append callback above can advance as soon
            // as a valid next item is available.
            syncNativeNowPlaying()
            return
        }
        didAutoAdvance = true
        playbackController.didFinish = false
        store.playNextInQueue()
    }
}
