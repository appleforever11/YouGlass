import SwiftUI

struct WatchActionButton: View {
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
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct CommentRow: View {
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

struct RelatedVideoCard: View {
    @EnvironmentObject private var store: YouTubeStore
    let video: VideoItem
    let palette: Palette

    var body: some View {
        HStack(spacing: 10) {
            RemoteImage(url: video.thumbnailURL)
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
        .onHover { hovering in
            if hovering { store.prewarmPlayback(for: video) }
        }
    }
}

struct LiveChatPanel: View {
    @EnvironmentObject private var store: YouTubeStore
    let video: VideoItem
    let liveChatID: String?
    let page: LiveChatPage
    let messages: [LiveChatMessage]
    let palette: Palette
    let onMessageSent: (LiveChatMessage) -> Void
    @State private var draft = ""
    @State private var isSending = false
    @State private var sendStatus: String?

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
                YouGlassBoundedScrollView(accessibilityIdentifier: "live-chat-scroll") {
                    VStack(alignment: .leading, spacing: 10) {
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
                .frame(maxWidth: .infinity, minHeight: 1, maxHeight: .infinity, alignment: .top)
            }

            if let liveChatID, !liveChatID.isEmpty {
                HStack(spacing: 7) {
                    TextField("Send a message", text: $draft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .onSubmit(sendMessage)
                        .disabled(isSending)

                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.borderless)
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .help("Send live chat message")
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(.black.opacity(palette.isDark ? 0.14 : 0.05), in: Capsule())
            } else {
                Text("Live chat is view-only until YouTube exposes a writable chat session.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(palette.tertiaryText)
            }

            if let sendStatus {
                Text(sendStatus)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.stroke, lineWidth: 1))
    }

    private func sendMessage() {
        let cleanText = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty, !isSending else { return }
        isSending = true
        sendStatus = nil
        Task { @MainActor in
            if let message = await store.sendLiveChatMessage(for: video, liveChatID: liveChatID, text: cleanText) {
                draft = ""
                onMessageSent(message)
            } else {
                sendStatus = store.connectionMessage
            }
            isSending = false
        }
    }
}
