import SwiftUI
import AppKit
import Foundation

enum CompactPlayerMetrics {
    static let maxWidth: CGFloat = 380
    static let minimumWidth: CGFloat = 160
    static let aspectRatio: CGFloat = 16 / 9
    static let widthFraction: CGFloat = 0.38
    static let edgeInset: CGFloat = 16
}

struct YouTubePlayerOverlay: View {
    @EnvironmentObject private var store: YouTubeStore
    @State private var cornerMenuPresented = false
    let video: VideoItem
    let palette: Palette
    let isCompact: Bool
    let onCompactDragChanged: ((CGSize) -> Void)?
    let onCompactDragEnded: ((CGSize) -> Void)?

    var body: some View {
        ZStack {
            PlayerAmbientSurface(
                palette: palette,
                ambientPalette: store.ambientPalette,
                intensity: isCompact ? 0.82 : 1.15
            )

            NativeWatchScreen(
                video: video,
                palette: palette,
                isCompact: isCompact,
                onCompactDragChanged: onCompactDragChanged,
                onCompactDragEnded: onCompactDragEnded
            )
                .environmentObject(store)
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: isCompact ? 18 : 0, style: .continuous))
            .overlay {
                if isCompact {
                    ZStack(alignment: .topLeading) {
                        HStack(spacing: 8) {
                            Button {
                                withAnimation(.easeOut(duration: 0.16)) {
                                    cornerMenuPresented.toggle()
                                }
                            } label: {
                                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .frame(width: 32, height: 32, alignment: .center)
                            }
                            .buttonStyle(GlassIconButtonStyle(palette: palette))
                            .contentShape(Circle())
                            .help("Move Picture in Picture")

                            Button(action: store.expandPlayer) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .frame(width: 32, height: 32, alignment: .center)
                            }
                            .buttonStyle(GlassIconButtonStyle(palette: palette))
                            .help("Expand player")

                            Button(action: store.dismissPlayer) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .frame(width: 32, height: 32, alignment: .center)
                            }
                            .buttonStyle(GlassIconButtonStyle(palette: palette))
                            .help("Stop playback")
                        }

                        if cornerMenuPresented {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Move player")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(palette.text)

                                ForEach(CompactPlayerCorner.allCases) { corner in
                                    Button {
                                        store.setCompactPlayerCorner(corner)
                                        withAnimation(.easeOut(duration: 0.16)) {
                                            cornerMenuPresented = false
                                        }
                                    } label: {
                                        Label(
                                            corner.title,
                                            systemImage: corner == store.compactPlayerCorner
                                                ? "checkmark"
                                                : "rectangle"
                                        )
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(palette.text)
                                }
                            }
                            .padding(10)
                            .frame(width: 150)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(palette.stroke, lineWidth: 1)
                            }
                            .padding(.top, 44)
                            .zIndex(2)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .overlay {
                if isCompact {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.stroke, lineWidth: 1)
                }
            }
    }
}

private struct NativeWatchScreen: View {
    @EnvironmentObject private var store: YouTubeStore
    @State private var commentPage = CommentPage(comments: [], totalCount: 0, isAvailable: false, message: nil)
    @State private var commentsLoading = true
    @State private var recommendations: [VideoItem] = []
    @State private var details: VideoDetails?
    @State private var chatMessages: [LiveChatMessage] = []
    @State private var liveChatPage = LiveChatPage.unavailable
    @State private var liked = false
    @State private var disliked = false
    @State private var saved = false
    @State private var subscribed = false
    @State private var subscriptionStatusResolved = false
    @State private var actionBusy = false
    @State private var commentsLoadingMore = false
    @State private var commentLoadRetryToken: String?
    @State private var commentText = ""
    @State private var commentStatus: String?
    @State private var commentSubmitting = false
    @State private var authorizingComments = false
    @State private var commentAuthorizationRequired = false
    @State private var commentChannelID: String?
    @State private var playbackStopHandlerToken: UUID?
    @StateObject private var playbackController = YouTubePlaybackController()
    @FocusState private var commentFieldFocused: Bool
    let video: VideoItem
    let palette: Palette
    let isCompact: Bool
    let onCompactDragChanged: ((CGSize) -> Void)?
    let onCompactDragEnded: ((CGSize) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            if !isCompact {
                header
            }

            if isCompact {
                // The desktop PIP host is a fixed-size window. Keep the
                // player out of the full watch screen's ScrollView so its
                // bottom transport row receives the complete content height
                // instead of being clipped by the scroll content viewport.
                NativeYouTubePlayer(
                    video: video,
                    palette: palette,
                    playbackController: playbackController,
                    autoMuteOnStart: store.autoMuteOnStart,
                    isCompact: true,
                    onCompactDragChanged: onCompactDragChanged,
                    onCompactDragEnded: onCompactDragEnded
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .accessibilityIdentifier("player-main-scroll")
            } else {
                // Measuring two complete watch-screen hierarchies with
                // ViewThatFits makes SwiftUI rebuild scroll responders while
                // the pointer is moving. Choose one stable hierarchy from the
                // available width instead.
                GeometryReader { geometry in
                    if geometry.size.width >= 900 {
                        watchWideLayout
                    } else {
                        watchNarrowLayout
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            recommendations = await loadedRecommendations
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
            if details?.isLive == true {
                await pollLiveChat(liveChatID: details?.liveChatID)
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
            playbackController.restorePlaybackPosition(
                store.playbackPosition(for: video.id),
                for: video.id
            )
            store.setAmbientPalette(playbackController.ambientPalette)
        }
        .onChange(of: playbackController.ambientPalette) { _, nextPalette in
            store.setAmbientPalette(nextPalette)
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
            store.resetAmbientPalette()
        }
    }

    private var watchWideLayout: some View {
        HStack(alignment: .top, spacing: 18) {
            ScrollView(showsIndicators: true) {
                watchDetailsContent
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .accessibilityIdentifier("player-main-scroll")

            watchSideColumn
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }

    private var watchNarrowLayout: some View {
        ScrollView(showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                watchDetailsContent
                compactRelatedRail
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }
        .accessibilityIdentifier("player-main-scroll")
    }

    private var watchDetailsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            NativeYouTubePlayer(
                video: video,
                palette: palette,
                playbackController: playbackController,
                autoMuteOnStart: store.autoMuteOnStart,
                isCompact: false,
                onCompactDragChanged: nil,
                onCompactDragEnded: nil
            )
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 9, contentMode: .fit)

            Text(video.title)
                .font(.system(size: 24, weight: .bold))
                .lineLimit(2)

            channelAndActions
            description
            commentComposer
            commentsList
        }
    }

    private var watchSideColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            if details?.liveChatID != nil || liveChatPage.isLive || liveChatPage.isAvailable {
                LiveChatPanel(page: liveChatPage, messages: chatMessages, palette: palette)
                    .frame(height: 310)
            }

            relatedRail
        }
        .frame(width: 280, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var compactRelatedRail: some View {
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
                                store.open(related)
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

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: { store.closePlayer() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(GlassIconButtonStyle(palette: palette))

            VStack(alignment: .leading, spacing: 2) {
                Text("Now Playing")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                Text(video.channel)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }

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

            Button(action: { saved.toggle() }) {
                Image(systemName: saved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(GlassIconButtonStyle(palette: palette))
        }
        .padding(14)
        .zIndex(4)
    }

    private var channelAndActions: some View {
        HStack(spacing: 12) {
            AsyncAvatar(url: details?.channelAvatarURL)
                .frame(width: 42, height: 42)
                .overlay {
                    Text(String(video.channel.prefix(2)))
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(video.channel)
                        .font(.system(size: 15, weight: .bold))
                    if video.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.blue)
                    }
                }
                Text(metadataLine)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
            }

            Button(action: {
                guard !subscribed,
                      let channelID = details?.channelID ?? commentChannelID ?? video.channelID,
                      !actionBusy else { return }
                actionBusy = true
                Task {
                    let succeeded = await store.subscribe(to: channelID)
                    await MainActor.run {
                        if succeeded { subscribed = true }
                        actionBusy = false
                    }
                }
            }) {
                Text(subscriptionStatusResolved ? (subscribed ? "Subscribed" : "Subscribe") : "Checking...")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .frame(height: 36)
                    .background(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(actionBusy || !subscriptionStatusResolved || subscribed)

            Spacer()

            WatchActionButton(symbol: liked ? "hand.thumbsup.fill" : "hand.thumbsup", title: likeTitle, palette: palette) {
                guard !actionBusy else { return }
                actionBusy = true
                let nextRating = liked ? "none" : "like"
                Task {
                    let succeeded = await store.rate(video: video, as: nextRating)
                    await MainActor.run {
                        if succeeded {
                            liked = nextRating == "like"
                            if liked { disliked = false }
                            store.recordLocalRating(for: video, liked: liked)
                        }
                        actionBusy = false
                    }
                }
            }
            WatchActionButton(symbol: disliked ? "hand.thumbsdown.fill" : "hand.thumbsdown", title: "Dislike", palette: palette) {
                guard !actionBusy else { return }
                actionBusy = true
                let nextRating = disliked ? "none" : "dislike"
                Task {
                    let succeeded = await store.rate(video: video, as: nextRating)
                    await MainActor.run {
                        if succeeded {
                            disliked = nextRating == "dislike"
                            if disliked { liked = false }
                            if disliked { store.recordLocalRating(for: video, liked: false) }
                        }
                        actionBusy = false
                    }
                }
            }
            WatchActionButton(symbol: "square.and.arrow.up", title: "Share", palette: palette) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(video.playbackURL.absoluteString, forType: .string)
            }
            WatchActionButton(symbol: saved ? "bookmark.fill" : "bookmark", title: saved ? "Saved" : "Save", palette: palette) {
                saved.toggle()
                store.toggleSaved(video)
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(palette.stroke, lineWidth: 1))
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metadataLine)
                .font(.system(size: 13, weight: .bold))
            Text(details?.description.isEmpty == false ? details?.description ?? "" : "Watching in the native Apple-inspired player. Public metadata, comments, ratings, and live chat load from the YouTube Data API when available.")
                .font(.system(size: 13))
                .foregroundStyle(palette.secondaryText)
                .lineSpacing(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.stroke, lineWidth: 1))
    }

    private var commentComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                AsyncAvatar(url: store.profileImageURL)
                    .frame(width: 30, height: 30)

                ZStack(alignment: .topLeading) {
                    if commentText.isEmpty {
                        Text("Add a comment...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.secondaryText)
                            .padding(.top, 7)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $commentText)
                        .font(.system(size: 13))
                        .foregroundStyle(palette.text)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 34, maxHeight: 96)
                        .focused($commentFieldFocused)
                }

                if commentSubmitting {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top, 7)
                } else if !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: submitComment) {
                        Image(systemName: "paperplane.fill")
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(GlassIconButtonStyle(palette: palette))
                    .help("Post comment")
                    .padding(.top, 3)
                }
            }

            if let commentStatus {
                Text(commentStatus)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(commentAuthorizationRequired ? palette.secondaryText : palette.text)
            }

            if commentAuthorizationRequired {
                Button(action: authorizeComments) {
                    Label("Authorize Google to comment", systemImage: "person.badge.key.fill")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .disabled(authorizingComments)
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.stroke, lineWidth: 1))
    }

    private var commentsList: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                Text(commentsLoading ? "Loading Comments..." : "\(commentPage.totalCount) Comments")
                    .font(.system(size: 18, weight: .bold))
                if !commentsLoading,
                   commentPage.comments.count < commentPage.totalCount {
                    Text("\(commentPage.comments.count) loaded")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                }
                Image(systemName: "line.3.horizontal.decrease")
                    .foregroundStyle(palette.secondaryText)
                Spacer()
                if !commentsLoading, commentPage.nextPageToken != nil {
                    Button {
                        Task { await loadMoreComments(force: true) }
                    } label: {
                        Label("Load more", systemImage: "arrow.down.circle")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .disabled(commentsLoadingMore)
                }
            }

            if commentsLoading {
                Text("Loading public comments from the official YouTube Data API...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
            } else if commentPage.isAvailable {
                ScrollViewReader { reader in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 13) {
                            if commentPage.comments.isEmpty {
                                Text("No comments are visible on this page yet.")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(palette.secondaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 18)
                            }

                            ForEach(commentPage.comments) { comment in
                                CommentRow(comment: comment, palette: palette)
                                .onAppear {
                                    guard comment.id == commentPage.comments.last?.id else { return }
                                    Task { await loadMoreComments() }
                                }
                            }

                            if commentsLoadingMore {
                                HStack {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Loading more comments...")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(palette.secondaryText)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            } else if commentPage.nextPageToken != nil {
                                Button {
                                    Task { await loadMoreComments(force: true) }
                                } label: {
                                    Label("Load more comments", systemImage: "arrow.down.circle")
                                        .font(.system(size: 11, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.white)
                                .padding(.vertical, 4)
                            } else {
                                Color.clear
                                    .frame(height: 1)
                                    .id("comments-end")
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    }
                    .frame(minHeight: 280, idealHeight: 360, maxHeight: 420)
                    .accessibilityIdentifier("comments-scroll-view")
                    .onChange(of: commentPage.comments.count) { _, _ in
                        if commentPage.comments.count == 1 {
                            reader.scrollTo(commentPage.comments.first?.id, anchor: .top)
                        }
                    }
                }
                .background(.black.opacity(palette.isDark ? 0.08 : 0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(commentPage.message ?? "Comments are unavailable for this video.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.secondaryText)

                    HStack(spacing: 8) {
                        Button {
                            Task { await reloadComments() }
                        } label: {
                            Label("Retry", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)

                        if !store.hasDataAPIKey && !store.hasOAuthClientID {
                            Button {
                                store.settingsPresented = true
                            } label: {
                                Label("Connect YouTube API", systemImage: "key")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private var relatedRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Up Next")
                .font(.system(size: 17, weight: .bold))
                .padding(.top, 2)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(recommendations.isEmpty ? store.relatedVideos(for: video) : recommendations) { item in
                        Button(action: { store.open(item) }) {
                            RelatedVideoCard(video: item, palette: palette)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .accessibilityIdentifier("related-scroll")
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var metadataLine: String {
        var values = [video.views, video.age]
        if details?.isLive == true || liveChatPage.isLive {
            values.insert("LIVE", at: 0)
        }
        if let details {
            if details.isLive, let viewers = details.concurrentViewers {
                values.append("\(viewers) watching")
            }
            if !details.likeCount.isEmpty {
                values.append("\(details.likeCount) likes")
            }
        }
        return values.filter { !$0.isEmpty }.joined(separator: "  •  ")
    }

    private var likeTitle: String {
        if liked { return "Liked" }
        guard let likeCount = details?.likeCount, !likeCount.isEmpty else { return "Like" }
        return "Like  \(likeCount)"
    }

    private func loadMoreComments(force: Bool = false) async {
        guard !commentsLoadingMore,
              let pageToken = commentPage.nextPageToken,
              !pageToken.isEmpty else { return }
        if !force, commentLoadRetryToken == pageToken { return }

        commentsLoadingMore = true
        defer { commentsLoadingMore = false }
        commentLoadRetryToken = nil
        var nextPage = CommentPage(comments: [], totalCount: 0, isAvailable: false, message: "Loading more comments...", nextPageToken: pageToken)
        for attempt in 0..<4 {
            nextPage = await store.loadCommentPage(for: video, pageToken: pageToken)
            let isStillLoading = nextPage.comments.isEmpty && (nextPage.message?.localizedCaseInsensitiveContains("loading") == true)
            guard isStillLoading, attempt < 3 else { break }
            try? await Task.sleep(nanoseconds: 600_000_000)
        }
        let existingIDs = Set(commentPage.comments.map(\.id))
        let appended = nextPage.comments.filter { !existingIDs.contains($0.id) }
        let totalCount = max(commentPage.totalCount, nextPage.totalCount)
        let channelID = nextPage.channelID ?? commentPage.channelID

        if appended.isEmpty {
            commentPage = CommentPage(
                comments: commentPage.comments,
                totalCount: totalCount,
                isAvailable: commentPage.isAvailable,
                message: nextPage.message ?? "Scroll for more comments or select Load more to retry.",
                nextPageToken: nextPage.nextPageToken,
                channelID: channelID
            )
            commentLoadRetryToken = pageToken
        } else {
            let nextToken = nextPage.nextPageToken == pageToken ? nil : nextPage.nextPageToken
            commentPage = CommentPage(
                comments: commentPage.comments + appended,
                totalCount: totalCount,
                isAvailable: true,
                message: nil,
                nextPageToken: nextToken,
                channelID: channelID
            )
        }
    }

    private func reloadComments() async {
        commentsLoading = true
        commentLoadRetryToken = nil
        commentPage = await store.loadCommentPage(for: video)
        commentChannelID = commentPage.channelID
        commentsLoading = false
    }

    private func submitComment() {
        let cleanText = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty, !commentSubmitting else { return }

        commentSubmitting = true
        commentStatus = nil
        Task { @MainActor in
            if details?.channelID == nil, commentChannelID == nil {
                details = await store.loadVideoDetails(for: video)
                commentChannelID = details?.channelID
            }

            if let posted = await store.addComment(to: video, channelID: details?.channelID ?? commentChannelID, text: cleanText) {
                let existing = commentPage.comments.filter { $0.id != posted.id }
                commentPage = CommentPage(
                    comments: [posted] + existing,
                    totalCount: max(commentPage.totalCount + 1, 1),
                    isAvailable: true,
                    message: nil,
                    nextPageToken: commentPage.nextPageToken,
                    channelID: details?.channelID ?? commentChannelID
                )
                commentText = ""
                commentStatus = "Comment posted"
                commentAuthorizationRequired = false
                commentFieldFocused = false
            } else {
                commentAuthorizationRequired = store.commentAuthorizationRequired
                commentStatus = store.commentAuthorizationRequired
                    ? "Authorize Google comment access, then submit again."
                    : store.connectionMessage
            }
            commentSubmitting = false
        }
    }

    private func authorizeComments() {
        guard !authorizingComments else { return }
        authorizingComments = true
        commentStatus = "Opening Google authorization..."
        Task { @MainActor in
            let authorized = await store.authorizeYouTubeComments()
            authorizingComments = false
            commentAuthorizationRequired = !authorized && store.commentAuthorizationRequired
            commentStatus = authorized
                ? "Google comment access is ready. Submit your comment again."
                : store.connectionMessage
            if authorized {
                commentFieldFocused = true
            }
        }
    }

    private func pollLiveChat(liveChatID: String?) async {
        var pageToken: String?
        var resolvedLiveChatID = liveChatID
        var consecutiveFailures = 0
        var pollCount = 0
        while !Task.isCancelled {
            pollCount += 1
            let page = await store.loadLiveChat(for: video, liveChatID: resolvedLiveChatID, pageToken: pageToken)
            liveChatPage = page

            if page.isAvailable {
                consecutiveFailures = 0
            } else {
                consecutiveFailures += 1
            }

            let existingIDs = Set(chatMessages.map(\.id))
            chatMessages.append(contentsOf: page.messages.filter { !existingIDs.contains($0.id) })
            chatMessages = Array(chatMessages.suffix(80))
            pageToken = page.nextPageToken

            // Viewer counts and live status are useful, but refreshing the full
            // video resource on every chat tick burns API quota and can make a
            // busy stream feel less responsive. Refresh the metadata at a
            // slower cadence while chat continues at YouTube's requested rate.
            if pollCount == 1 || pollCount.isMultiple(of: 6),
               let refreshed = await store.loadVideoDetails(for: video) {
                details = refreshed
                resolvedLiveChatID = refreshed.liveChatID ?? resolvedLiveChatID
            }
            guard page.isLive || page.isAvailable else { return }

            let retryDelay = page.isAvailable
                ? page.pollingInterval
                : min(30_000_000_000, UInt64(2 + min(consecutiveFailures, 8)) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: retryDelay)
        }
    }
}

private struct NativeYouTubePlayer: View {
    @EnvironmentObject private var store: YouTubeStore
    let video: VideoItem
    let palette: Palette
    @ObservedObject var playbackController: YouTubePlaybackController
    let autoMuteOnStart: Bool
    let isCompact: Bool
    let onCompactDragChanged: ((CGSize) -> Void)?
    let onCompactDragEnded: ((CGSize) -> Void)?
    @State private var controlsVisible = false
    @State private var controlsHideTask: Task<Void, Never>?
    @State private var scrubPosition = 0.0
    @State private var isScrubbing = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            YouTubeInlinePlayerView(
                video: video,
                controller: playbackController,
                autoMuteOnStart: autoMuteOnStart
            )
            // WKWebView is deliberately playback-only. Keeping it out of the
            // hit-test chain lets the native toolbar and surface tap handler
            // receive clicks consistently instead of letting YouTube's page
            // layer swallow them.
            .allowsHitTesting(false)

            // Keep pointer movement and the click-to-pause surface in AppKit.
            // A transparent SwiftUI Rectangle with both onHover and
            // DragGesture sits directly over a WKWebView and can trigger the
            // macOS SwiftUI responder hit-test crash seen on MacBook Neo.
            PlayerInteractionSurface(
                isCompact: isCompact,
                onTap: {
                    revealControls()
                    playbackController.togglePlayback()
                },
                onHoverChanged: { isHovering in
                    if isHovering {
                        revealControls()
                    } else {
                        scheduleControlsHide(after: 0.35)
                    }
                },
                onCompactDragChanged: onCompactDragChanged,
                onCompactDragEnded: onCompactDragEnded
            )
            .accessibilityHidden(true)

            LinearGradient(
                colors: [.black.opacity(0.28), .clear, .black.opacity(0.24)],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(controlsVisible ? 1 : 0)
            .allowsHitTesting(false)

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

            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 6) {
                    PlaybackScrubber(
                        value: scrubberBinding,
                        duration: durationForScrubber,
                        elapsedLabel: formatPlaybackTime(displayedScrubTime),
                        durationLabel: formatPlaybackTime(playbackController.duration),
                        onEditingChanged: handleScrubbing
                    )

                    HStack(spacing: isCompact ? 6 : 8) {
                        PlayerControlButton(
                            symbol: playbackController.isPlaying ? "pause.fill" : "play.fill",
                            help: playbackController.isPlaying ? "Pause" : "Play",
                            controlSize: isCompact ? 32 : 38,
                            action: playbackController.togglePlayback
                        )
                        PlayerControlButton(symbol: "gobackward.15", help: "Back 15 seconds", controlSize: isCompact ? 32 : 38) {
                            playbackController.seek(by: -15)
                        }
                        PlayerControlButton(symbol: "goforward.15", help: "Forward 15 seconds", controlSize: isCompact ? 32 : 38) {
                            playbackController.seek(by: 15)
                        }
                        PlayerControlButton(
                            symbol: playbackController.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                            help: playbackController.isMuted ? "Unmute" : "Mute",
                            controlSize: isCompact ? 32 : 38,
                            action: playbackController.toggleMute
                        )
                        PlayerControlButton(
                            symbol: playbackController.isCaptionsEnabled
                                ? "captions.bubble.fill"
                                : "captions.bubble",
                            help: playbackController.isCaptionsEnabled
                                ? "Turn off closed captions"
                                : "Turn on closed captions",
                            controlSize: isCompact ? 32 : 38,
                            action: playbackController.toggleCaptions
                        )
                        .accessibilityIdentifier("captions-button")

                        if !isCompact {
                            Text(playbackController.isMuted ? "Click to unmute" : playbackController.status)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.88))
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                                .frame(width: 180, alignment: .leading)
                        }

                        PlayerControlButton(
                            symbol: playbackController.isPictureInPictureActive ? "pip.exit" : "pip.enter",
                            help: playbackController.isPictureInPictureActive
                                ? "Exit Picture in Picture"
                                : "Picture in Picture",
                            isEnabled: true,
                            controlSize: isCompact ? 32 : 38,
                            action: {
                                if isCompact {
                                    playbackController.togglePictureInPicture {
                                        // WebKit can reject a system PiP request
                                        // for a YouTube media element. Keep the
                                        // YouGlass floating player available as
                                        // the deterministic fallback.
                                        store.expandPlayer()
                                    }
                                } else {
                                    store.presentDesktopPIP()
                                }
                            }
                        )
                    }
                    // Keep transport controls centered as one stable group.
                    // The previous spacer pushed PIP to the trailing edge and
                    // made the toolbar appear to move when the video resized.
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 42)
                }
                .frame(maxWidth: isCompact ? 320 : 640)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, isCompact ? 10 : 16)
                .padding(.bottom, isCompact ? 8 : 12)
            }
            .opacity(controlsVisible && !playbackController.canRetry ? 1 : 0)
            .allowsHitTesting(controlsVisible && !playbackController.canRetry)
            .zIndex(1)
        }
        .background(.black)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.12), lineWidth: 1))
        .onDisappear {
            controlsHideTask?.cancel()
        }
        .onChange(of: video.id) { _, _ in
            scrubPosition = 0
            isScrubbing = false
        }
        .onAppear {
            // Give the native controls a short discoverable window when a
            // video opens. They then follow the normal hover timeout.
            revealControls()
        }
        .animation(.easeOut(duration: 0.18), value: controlsVisible)
    }

    private var durationForScrubber: Double {
        max(1, max(playbackController.duration, playbackController.currentTime))
    }

    private var displayedScrubTime: Double {
        let value = isScrubbing ? scrubPosition : playbackController.currentTime
        return min(max(0, value), durationForScrubber)
    }

    private var scrubberBinding: Binding<Double> {
        Binding(
            get: { displayedScrubTime },
            set: {
                scrubPosition = min(max(0, $0), durationForScrubber)
                isScrubbing = true
            }
        )
    }

    private func handleScrubbing(_ editing: Bool) {
        if editing {
            scrubPosition = displayedScrubTime
            isScrubbing = true
        } else {
            let target = min(max(0, scrubPosition), durationForScrubber)
            isScrubbing = false
            playbackController.seek(to: target)
        }
    }

    private func formatPlaybackTime(_ seconds: Double) -> String {
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

    private func revealControls() {
        controlsHideTask?.cancel()
        controlsVisible = true
        scheduleControlsHide(after: 2.2)
    }

    private func scheduleControlsHide(after seconds: Double) {
        controlsHideTask?.cancel()
        controlsHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            controlsVisible = false
            controlsHideTask = nil
        }
    }
}

private struct PlayerInteractionSurface: NSViewRepresentable {
    let isCompact: Bool
    let onTap: () -> Void
    let onHoverChanged: (Bool) -> Void
    let onCompactDragChanged: ((CGSize) -> Void)?
    let onCompactDragEnded: ((CGSize) -> Void)?

    func makeNSView(context: Context) -> PlayerInteractionNSView {
        let view = PlayerInteractionNSView()
        view.update(
            isCompact: isCompact,
            onTap: onTap,
            onHoverChanged: onHoverChanged,
            onCompactDragChanged: onCompactDragChanged,
            onCompactDragEnded: onCompactDragEnded
        )
        return view
    }

    func updateNSView(_ view: PlayerInteractionNSView, context: Context) {
        view.update(
            isCompact: isCompact,
            onTap: onTap,
            onHoverChanged: onHoverChanged,
            onCompactDragChanged: onCompactDragChanged,
            onCompactDragEnded: onCompactDragEnded
        )
    }

    static func dismantleNSView(_ view: PlayerInteractionNSView, coordinator: ()) {
        view.teardown()
    }
}

/// A fixed AppKit event surface keeps hover, click, and compact-player drag
/// handling out of SwiftUI's dynamic responder graph. This is intentionally
/// a transparent view; the WebKit view below it remains playback-only.
private final class PlayerInteractionNSView: NSView {
    private var isCompact = false
    private var onTap: (() -> Void)?
    private var onHoverChanged: ((Bool) -> Void)?
    private var onCompactDragChanged: ((CGSize) -> Void)?
    private var onCompactDragEnded: ((CGSize) -> Void)?
    private var trackingArea: NSTrackingArea?
    private var mouseDownPoint: NSPoint?
    private var didDrag = false
    private var pointerIsInside = false

    override var isOpaque: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func update(
        isCompact: Bool,
        onTap: @escaping () -> Void,
        onHoverChanged: @escaping (Bool) -> Void,
        onCompactDragChanged: ((CGSize) -> Void)?,
        onCompactDragEnded: ((CGSize) -> Void)?
    ) {
        self.isCompact = isCompact
        self.onTap = onTap
        self.onHoverChanged = onHoverChanged
        self.onCompactDragChanged = onCompactDragChanged
        self.onCompactDragEnded = onCompactDragEnded
    }

    func teardown() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        trackingArea = nil
        onTap = nil
        onHoverChanged = nil
        onCompactDragChanged = nil
        onCompactDragEnded = nil
        mouseDownPoint = nil
        didDrag = false
        pointerIsInside = false
    }

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        guard !pointerIsInside else { return }
        pointerIsInside = true
        notifyHover(true)
    }

    override func mouseExited(with event: NSEvent) {
        guard pointerIsInside else { return }
        pointerIsInside = false
        notifyHover(false)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard isCompact, let mouseDownPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        let translation = CGSize(
            width: point.x - mouseDownPoint.x,
            height: -(point.y - mouseDownPoint.y)
        )
        let distance = hypot(translation.width, translation.height)
        guard didDrag || distance >= 6 else { return }
        didDrag = true
        onCompactDragChanged?(translation)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownPoint = nil
            didDrag = false
        }

        guard isCompact, didDrag, let mouseDownPoint else {
            onTap?()
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        onCompactDragEnded?(CGSize(
            width: point.x - mouseDownPoint.x,
            height: -(point.y - mouseDownPoint.y)
        ))
    }

    private func notifyHover(_ isHovering: Bool) {
        // Never mutate SwiftUI state inline while AppKit is dispatching a
        // pointer event; doing so can re-enter hit testing during a resize.
        DispatchQueue.main.async { [weak self] in
            self?.onHoverChanged?(isHovering)
        }
    }
}

private struct PlayerAmbientSurface: View {
    let palette: Palette
    let ambientPalette: VideoAmbientPalette
    let intensity: Double
    @State private var isBreathing = false

    var body: some View {
        ZStack {
            palette.isDark ? Color.black : palette.window

            PlayerAmbientTint(
                palette: palette,
                ambientPalette: ambientPalette,
                intensity: intensity
            )
            .scaleEffect(isBreathing ? 1.045 : 0.965)
            .offset(
                x: isBreathing ? 18 : -18,
                y: isBreathing ? -12 : 12
            )
            .opacity(isBreathing ? 1 : 0.78)
        }
        .animation(
            .easeInOut(duration: 7.2).repeatForever(autoreverses: true),
            value: isBreathing
        )
        .animation(.easeInOut(duration: 2.4), value: ambientPalette)
        .onAppear {
            isBreathing = true
        }
        .allowsHitTesting(false)
    }
}

private struct PlayerAmbientTint: View {
    let palette: Palette
    let ambientPalette: VideoAmbientPalette
    let intensity: Double

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let height = max(geometry.size.height, 1)
            let radius = max(width, height) * 0.86
            let energy = min(max(ambientPalette.energy, 0.18), 1.0)
            let glow = 0.92 + energy * 0.24

            ZStack {
                RadialGradient(
                    colors: [
                        ambientPalette.primary.color.opacity((palette.isDark ? 0.18 : 0.12) * intensity * glow),
                        ambientPalette.primary.color.opacity((palette.isDark ? 0.038 : 0.028) * intensity * glow),
                        .clear
                    ],
                    center: UnitPoint(x: 0.10, y: 0.16),
                    startRadius: 0,
                    endRadius: radius
                )

                RadialGradient(
                    colors: [
                        ambientPalette.secondary.color.opacity((palette.isDark ? 0.145 : 0.095) * intensity * glow),
                        ambientPalette.secondary.color.opacity((palette.isDark ? 0.030 : 0.022) * intensity * glow),
                        .clear
                    ],
                    center: UnitPoint(x: 0.90, y: 0.82),
                    startRadius: 0,
                    endRadius: radius * 0.90
                )

                RadialGradient(
                    colors: [
                        ambientPalette.accent.color.opacity((palette.isDark ? 0.105 : 0.070) * intensity * glow),
                        .clear
                    ],
                    center: UnitPoint(x: 0.54, y: 0.46),
                    startRadius: 0,
                    endRadius: radius * 0.72
                )

                AngularGradient(
                    colors: [
                        ambientPalette.primary.color.opacity(0.024 * intensity * glow),
                        ambientPalette.accent.color.opacity(0.036 * intensity * glow),
                        ambientPalette.secondary.color.opacity(0.030 * intensity * glow),
                        ambientPalette.primary.color.opacity(0.024 * intensity * glow)
                    ],
                    center: .center
                )
            }
        }
    }
}

private struct PlaybackScrubber: View {
    @Binding var value: Double
    let duration: Double
    let elapsedLabel: String
    let durationLabel: String
    let onEditingChanged: (Bool) -> Void
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geometry in
                let width = max(geometry.size.width, 1)
                let progress = min(max(value / max(duration, 1), 0), 1)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.24))
                        .frame(height: 7)

                    Capsule()
                        .fill(.white)
                        .frame(width: max(18, width * progress), height: 7)

                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                        .offset(x: max(0, min(width - 20, width * progress - 10)))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            if !isDragging {
                                isDragging = true
                                onEditingChanged(true)
                            }
                            value = value(at: gesture.location.x, width: width)
                        }
                        .onEnded { gesture in
                            value = value(at: gesture.location.x, width: width)
                            isDragging = false
                            onEditingChanged(false)
                        }
                )
            }
            .frame(height: 30)

            HStack {
                Text(elapsedLabel)
                Spacer()
                Text(durationLabel)
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.75))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Video progress")
        .accessibilityValue("\(elapsedLabel) of \(durationLabel)")
        .accessibilityAdjustableAction { direction in
            let step = max(5, duration / 100)
            onEditingChanged(true)
            switch direction {
            case .increment:
                value = min(duration, value + step)
            case .decrement:
                value = max(0, value - step)
            @unknown default:
                break
            }
            onEditingChanged(false)
        }
    }

    private func value(at x: CGFloat, width: CGFloat) -> Double {
        let progress = min(max(x / max(width, 1), 0), 1)
        return progress * max(duration, 1)
    }
}

private struct PlayerControlButton: View {
    let symbol: String
    let help: String
    var isEnabled = true
    var controlSize: CGFloat = 38
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: controlSize < 36 ? 13 : 15, weight: .bold))
                .frame(width: controlSize, height: controlSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.42))
        .youGlassControlSurface()
        .overlay {
            Circle()
                .stroke(.white.opacity(0.34), lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(.white.opacity(0.20))
                .frame(width: 16, height: 4)
                .blur(radius: 2)
                .offset(x: 8, y: 7)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.24), radius: 8, y: 3)
        .contentShape(Circle())
        .disabled(!isEnabled)
        .help(help)
    }
}

private extension View {
    @ViewBuilder
    func youGlassControlSurface() -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(.regular.interactive(), in: Circle())
        } else {
            background {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle()
                            .fill(.white.opacity(0.10))
                    }
            }
        }
    }
}

private struct WatchActionButton: View {
    let symbol: String
    let title: String
    let palette: Palette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                Text(title)
            }
            .font(.system(size: 12, weight: .bold))
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(palette.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct CommentRow: View {
    let comment: VideoComment
    let palette: Palette

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncAvatar(url: comment.avatarURL)
                .frame(width: 30, height: 30)
                .overlay {
                    if comment.avatarURL == nil {
                        Text(String(comment.author.prefix(1)))
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(comment.author)
                        .font(.system(size: 12, weight: .bold))
                    Text(comment.age)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                }
                Text(comment.text)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    Label(comment.likes, systemImage: "hand.thumbsup")
                    Image(systemName: "hand.thumbsdown")
                    Text("Reply")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.secondaryText)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct RelatedVideoCard: View {
    let video: VideoItem
    let palette: Palette

    var body: some View {
        HStack(spacing: 10) {
            RemoteImage(url: video.imageURL)
                .frame(width: 116, height: 66)
                .videoThumbnailParallax(translation: 3.5, rotation: 2.2)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(2)
                Text(video.channel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
                Text(video.age)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.stroke, lineWidth: 1))
    }
}

private struct LiveChatPanel: View {
    let page: LiveChatPage
    let messages: [LiveChatMessage]
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Circle()
                    .fill(.red)
                    .frame(width: 7, height: 7)
                Text("Live chat")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Text("LIVE")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.red)
            }

            if messages.isEmpty {
                Text(page.message ?? "Waiting for live messages...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(messages) { message in
                            HStack(alignment: .top, spacing: 8) {
                                AsyncAvatar(url: message.avatarURL)
                                    .frame(width: 22, height: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 5) {
                                        Text(message.author)
                                            .font(.system(size: 10, weight: .bold))
                                        Text(message.publishedAt)
                                            .font(.system(size: 9))
                                            .foregroundStyle(palette.tertiaryText)
                                    }
                                    Text(message.text)
                                        .font(.system(size: 11))
                                        .foregroundStyle(palette.text)
                                        .lineLimit(3)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.stroke, lineWidth: 1))
    }
}

struct GlassIconButtonStyle: ButtonStyle {
    let palette: Palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(palette.text)
            .background(.thinMaterial)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(palette.isDark ? 0.16 : 0.44), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

struct GlassCapsuleButtonStyle: ButtonStyle {
    let palette: Palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(palette.text)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(.thinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(palette.isDark ? 0.16 : 0.44), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
