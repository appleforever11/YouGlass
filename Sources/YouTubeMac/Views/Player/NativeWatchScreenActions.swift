import SwiftUI

extension NativeWatchScreen {
        var channelAndActions: some View {
            VStack(alignment: .leading, spacing: 10) {
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
                                .lineLimit(1)
                                .truncationMode(.tail)
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
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        guard !subscribed,
                              let channelID = details?.channelID ?? commentChannelID ?? video.channelID,
                              !actionBusy else { return }
                        actionBusy = true
                        Task {
                            let succeeded = await store.subscribe(
                                to: channelID,
                                channelName: video.channel,
                                avatarURL: details?.channelAvatarURL
                            )
                            await MainActor.run {
                                if succeeded { subscribed = true }
                                actionBusy = false
                            }
                        }
                    } label: {
                        Text(subscriptionStatusResolved ? (subscribed ? "Subscribed" : "Subscribe") : "Checking...")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 18)
                            .frame(height: 36)
                            .background(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: true, vertical: false)
                    .disabled(actionBusy || !subscriptionStatusResolved || subscribed)
                    .help(subscribed ? "Subscribed" : "Subscribe to \(video.channel)")
                }

                // Use a direct button lane here. A nested horizontal ScrollView
                // inside the vertically scrolling watch page can win the AppKit
                // mouse hit test even when the pointer is over a button, making
                // the actions look enabled but feel dead.
                HStack(spacing: 8) {
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
                .padding(.horizontal, 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(true)
                .layoutPriority(1)
            }
            .padding(12)
            .youGlassSurface(palette: palette, cornerRadius: 16)
            .zIndex(30)
        }

        var description: some View {
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
            .youGlassSurface(palette: palette, cornerRadius: 14)
        }

        var commentComposer: some View {
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
            .youGlassSurface(palette: palette, cornerRadius: 14, interactive: true)
        }
}
