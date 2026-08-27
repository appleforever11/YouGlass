import SwiftUI

struct HeroSection: View {
    @EnvironmentObject private var store: YouTubeStore
    let palette: Palette
    let compact: Bool

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
                            Image(systemName: palette.isDark ? "star.fill" : "apple.logo")
                                .font(.system(size: 10, weight: .medium))
                            Text("Featured")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(palette.tertiaryText)

                        Text(store.feed.hero.title)
                            .font(.system(size: narrow ? 20 : 26, weight: .bold))
                            .lineLimit(2)
                            .padding(.top, narrow ? 10 : 16)

                        Text("From your YouTube homepage and subscribed channels.")
                            .font(.system(size: narrow ? 12 : 14))
                            .foregroundStyle(palette.secondaryText)
                            .lineSpacing(4)
                            .padding(.top, narrow ? 8 : 14)

                        Button(action: { store.openFromUserInteraction(store.feed.hero) }) {
                            HStack(spacing: 9) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 21))
                                Text("Play Video")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(palette.playText)
                            .padding(.horizontal, 20)
                            .frame(height: 44)
                            .background(palette.playButton)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, narrow ? 20 : 28)

                        Spacer()
                    }
                    .padding(.leading, narrow ? 16 : 26)
                    .padding(.top, narrow ? 22 : 30)
                    .frame(width: copyWidth)

                    ZStack(alignment: .bottomLeading) {
                        RemoteImage(url: store.feed.hero.thumbnailURL)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()

                        LinearGradient(
                            colors: [.clear, .black.opacity(0.26)],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        HStack(spacing: 8) {
                            ForEach(0..<4, id: \.self) { index in
                                Circle()
                                    .fill(index == 0 ? .white : .white.opacity(0.35))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(16)
                    }
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
