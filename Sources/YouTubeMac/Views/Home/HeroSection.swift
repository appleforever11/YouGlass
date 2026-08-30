import SwiftUI

struct HeroSection: View {
    @EnvironmentObject private var store: YouTubeStore
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    let palette: Palette
    let compact: Bool
    @State private var imageHovered = false

    var body: some View {
        let hasQueue = !compact && !store.feed.queue.isEmpty
        let queueCount = min(4, store.feed.queue.count)
        let queueHeight = CGFloat(queueCount * 76) + CGFloat(max(queueCount - 1, 0) * 10)
        let heroHeight = compact ? 240 : max(290, queueHeight + 8)

        GeometryReader { geometry in
            // The queue needs roughly 240 points beside the hero card. Start
            // the compact presentation before that combination can overflow
            // a mid-size MacBook window.
            let narrow = compact
            let ambient = store.ambientPalette
            let queueWidth: CGFloat = hasQueue ? 242 : 0
            let queueGap: CGFloat = hasQueue ? 16 : 0
            // Reserve the queue column before laying out the hero. A flexible
            // hero followed by a fixed rail can otherwise measure as the full
            // width and push the rail beyond the visible window.
            let heroWidth = max(1, geometry.size.width - queueWidth - queueGap)
            let copyWidth = narrow
                ? min(240, max(190, heroWidth * 0.44))
                : min(300, max(250, heroWidth * 0.34))

            HStack(spacing: queueGap) {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10, weight: .medium))
                            Text("Featured for you")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(palette.tertiaryText)

                        Text(store.feed.hero.title)
                            .font(.system(size: narrow ? 20 : 26, weight: .bold))
                            .lineLimit(2)
                            .padding(.top, narrow ? 10 : 16)

                        HStack(spacing: 6) {
                            Text(store.feed.hero.channel)
                                .fontWeight(.semibold)
                            if !store.feed.hero.age.isEmpty {
                                Text("•")
                                Text(store.feed.hero.age)
                            }
                            if !store.feed.hero.duration.isEmpty {
                                Text("•")
                                Text(store.feed.hero.duration)
                            }
                        }
                        .font(.system(size: narrow ? 11 : 12))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                        .padding(.top, narrow ? 8 : 12)

                        Text("Selected from your personalized YouTube feed.")
                            .font(.system(size: narrow ? 11 : 12))
                            .foregroundStyle(palette.tertiaryText)
                            .lineLimit(2)
                            .padding(.top, 6)

                        HStack(spacing: 9) {
                            Button(action: { store.openFromUserInteraction(store.feed.hero) }) {
                                HStack(spacing: 9) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 14, weight: .bold))
                                    Text("Play")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundStyle(palette.playText)
                                .padding(.horizontal, 20)
                                .frame(height: 42)
                                .background(palette.playButton)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Button {
                                store.enqueue(store.feed.hero)
                            } label: {
                                Image(systemName: "text.badge.plus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(width: 36, height: 36)
                            }
                            .buttonStyle(GlassIconButtonStyle(palette: palette))
                            .help("Add to playback queue")
                            .accessibilityLabel("Add featured video to playback queue")

                            Button {
                                store.toggleSaved(store.feed.hero)
                            } label: {
                                Image(systemName: store.isSaved(store.feed.hero) ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(width: 36, height: 36)
                            }
                            .buttonStyle(GlassIconButtonStyle(palette: palette))
                            .help(store.isSaved(store.feed.hero) ? "Remove from Watch Later" : "Save to Watch Later")
                            .accessibilityLabel(store.isSaved(store.feed.hero) ? "Remove featured video from Watch Later" : "Save featured video to Watch Later")
                        }
                        .padding(.top, narrow ? 20 : 28)

                        Spacer()
                    }
                    .padding(.leading, narrow ? 16 : 26)
                    .padding(.top, narrow ? 22 : 30)
                    .frame(width: copyWidth)

                    Button {
                        store.openFromUserInteraction(store.feed.hero)
                    } label: {
                        ZStack {
                            RemoteImage(url: store.feed.hero.thumbnailURL)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()

                            LinearGradient(
                                colors: [.clear, .black.opacity(imageHovered ? 0.18 : 0.30)],
                                startPoint: .top,
                                endPoint: .bottom
                            )

                            if imageHovered {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 58, height: 58)
                                    .background(.black.opacity(0.58), in: Circle())
                                    .overlay(Circle().stroke(.white.opacity(0.62), lineWidth: 1))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(accessibilityReduceMotion ? 1 : (imageHovered ? 1.008 : 1))
                    .animation(accessibilityReduceMotion ? nil : .easeOut(duration: 0.16), value: imageHovered)
                    .onHover { hovering in
                        imageHovered = hovering
                        if hovering { store.prewarmPlayback(for: store.feed.hero) }
                    }
                    .accessibilityLabel("Play featured video: \(store.feed.hero.title)")
                }
                .frame(width: heroWidth, height: heroHeight)
                .background {
                    LinearGradient(
                        colors: [
                            ambient.primary.color.opacity(palette.isDark ? 0.12 : 0.08),
                            palette.card,
                            ambient.accent.color.opacity(palette.isDark ? 0.10 : 0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    ambient.primary.color.opacity(0.44),
                                    palette.stroke,
                                    ambient.secondary.color.opacity(0.32)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }

            if hasQueue {
                VStack(spacing: 10) {
                    ForEach(store.feed.queue.prefix(4)) { video in
                        Button(action: { store.openFromUserInteraction(video) }) {
                            CompactVideoCard(video: video, palette: palette)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 242)
            }
        }
            .frame(width: geometry.size.width, height: heroHeight, alignment: .leading)
        }
        .frame(height: heroHeight)
    }
}
