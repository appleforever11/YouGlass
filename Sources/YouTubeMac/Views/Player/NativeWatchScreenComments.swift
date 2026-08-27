import SwiftUI

extension NativeWatchScreen {
        var commentsList: some View {
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
                    VStack(alignment: .leading, spacing: 13) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("comments-content")
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
                                SettingsLink {
                                    Label("Connect YouTube API", systemImage: "key")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .controlSize(.small)
                    }
                }
            }
            // Keep the comments block in the outer page's intrinsic document
            // height. This prevents an unbounded page proposal from making the
            // section visually present but layout-zero.
            .frame(minHeight: 180, alignment: .top)
            .fixedSize(horizontal: false, vertical: true)
        }

        var relatedRail: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Up Next")
                    .font(.system(size: 17, weight: .bold))
                    .padding(.top, 2)

                if playerRecommendations.isEmpty {
                    Text("Recommendations will appear here when YouTube returns them.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(playerRecommendations) { item in
                            Button(action: { store.openFromUserInteraction(item) }) {
                                RelatedVideoCard(video: item, palette: palette)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("related-content")
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            // The recommendation rail is part of the same outer page document,
            // not a second vertical scroll surface.
            .fixedSize(horizontal: false, vertical: true)
        }

        var playerRecommendations: [VideoItem] {
            let candidates = store.mergeVideos(recommendations + store.relatedVideos(for: video))
            return Array(candidates.filter { $0.id != video.id }.prefix(10))
        }

        var metadataLine: String {
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

        var likeTitle: String {
            if liked { return "Liked" }
            guard let likeCount = details?.likeCount, !likeCount.isEmpty else { return "Like" }
            return "Like  \(likeCount)"
        }

        func loadMoreComments(force: Bool = false) async {
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

        func reloadComments() async {
            commentsLoading = true
            commentLoadRetryToken = nil
            commentPage = await store.loadCommentPage(for: video)
            commentChannelID = commentPage.channelID
            commentsLoading = false
        }

        func submitComment() {
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

        func authorizeComments() {
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

        func pollLiveChat(liveChatID: String?) async {
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
