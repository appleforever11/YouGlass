import SwiftUI

struct ContinueWatchingRow: View {
    @EnvironmentObject private var store: YouTubeStore
    let palette: Palette
    let compact: Bool

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 260), spacing: 18)]

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                YouGlassSectionHeading(title: "Continue Watching", subtitle: "Pick up where you left off", palette: palette, count: store.continueWatching.count)
                Spacer()
                if store.selectedSection != "Library" {
                    Button("View Library") { store.showSection("Library") }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                ForEach(Array(store.continueWatching.prefix(8))) { video in
                    ContinueWatchingCard(video: video, palette: palette)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Continue watching")
    }
}

struct ContinueWatchingCard: View {
    @EnvironmentObject private var store: YouTubeStore
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    let video: VideoItem
    let palette: Palette
    @State private var isHovered = false

    var body: some View {
        Button {
            store.openFromUserInteraction(video)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    YouGlassVideoPreview {
                        RemoteImage(url: video.thumbnailURL)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.32)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    Image(systemName: "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(.black.opacity(0.62), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.56), lineWidth: 1))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .opacity(isHovered ? 1 : 0)
                        .scaleEffect(isHovered ? 1 : 0.82)
                        .allowsHitTesting(false)
                        .transaction { $0.animation = nil }

                    if store.hasResumeCheckpoint(for: video.id) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.25))
                                Capsule()
                                    .fill(palette.accent)
                                    .frame(width: geometry.size.width * store.playbackProgress(for: video))
                            }
                            .frame(height: 5)
                        }
                        .frame(height: 5)
                        .padding(8)
                    }
                }

                Text(video.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .lineLimit(2)
                    .frame(height: 36, alignment: .topLeading)

                HStack(spacing: 5) {
                    Image(systemName: "arrow.uturn.forward.circle.fill")
                    Text(resumeLabel)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(isHovered ? palette.card.opacity(palette.isDark ? 0.82 : 0.72) : .clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(isHovered ? palette.stroke : .clear, lineWidth: 1)
            }
            .scaleEffect(accessibilityReduceMotion ? 1 : (isHovered ? 1.012 : 1))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .videoCardHover(isHovered: $isHovered, videoID: video.id) {
            store.prewarmPlayback(for: video)
        }
        .shadow(color: isHovered ? .black.opacity(palette.isDark ? 0.30 : 0.10) : .clear, radius: 14, y: 7)
        .animation(accessibilityReduceMotion ? nil : .easeOut(duration: 0.08), value: isHovered)
        .accessibilityLabel("Resume \(video.title) from \(resumeLabel)")
        .contextMenu {
            Button("Remove from Continue Watching") {
                store.clearPlaybackPosition(for: video)
            }
            Button(store.isSaved(video) ? "Remove from Watch Later" : "Save to Watch Later") {
                store.toggleSaved(video)
            }
        }
    }

    private var resumeLabel: String {
        let position = store.playbackPosition(for: video.id)
        guard position > 0 else { return "Resume video" }
        let minutes = Int(position) / 60
        let seconds = Int(position) % 60
        return String(format: "Resume at %d:%02d", minutes, seconds)
    }
}
