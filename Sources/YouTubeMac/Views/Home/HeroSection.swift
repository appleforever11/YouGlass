import SwiftUI

/// A single featured stage; the recommendation grid owns the surrounding catalog.
struct HeroSection: View {
    @EnvironmentObject private var store: YouTubeStore
    let palette: Palette
    let compact: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: compact ? .bottomLeading : .leading) {
                Button {
                    store.openFromUserInteraction(store.feed.hero)
                } label: {
                    RemoteImage(url: store.feed.hero.thumbnailURL, maximumPixelSize: 1_600)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        // Clipping pixels does not bound a scaled image's pointer region.
                        .contentShape(Rectangle())
                        .overlay {
                            LinearGradient(
                                stops: [
                                    .init(color: palette.window.opacity(0.98), location: 0),
                                    .init(color: palette.window.opacity(0.86), location: compact ? 0.30 : 0.38),
                                    .init(color: palette.window.opacity(0.12), location: 0.78),
                                    .init(color: .clear, location: 1)
                                ],
                                startPoint: compact ? .bottom : .leading,
                                endPoint: compact ? .top : .trailing
                            )
                        }
                }
                .buttonStyle(.plain)
                .videoThumbnailHaptics()
                .accessibilityLabel("Play featured video: \(store.feed.hero.title)")
                .onHover { if $0 { store.prewarmPlayback(for: store.feed.hero) } }

                VStack(alignment: .leading, spacing: 12) {
                    Label("FIRST IN YOUR FEED", systemImage: "play.rectangle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.6)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .youGlassSurface(palette: palette, cornerRadius: 16)
                    Text(store.feed.hero.title)
                        .font(.system(size: compact ? 26 : 34, weight: .bold))
                        .tracking(-1.0)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .allowsHitTesting(false)
                    Text([store.feed.hero.channel, store.feed.hero.age, store.feed.hero.duration]
                        .filter { !$0.isEmpty }.joined(separator: "  ·  "))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                        .allowsHitTesting(false)
                    YouGlassSurfaceGroup {
                    HStack(spacing: 10) {
                        Button {
                            store.openFromUserInteraction(store.feed.hero)
                        } label: {
                            Label("Watch now", systemImage: "play.fill")
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 18)
                                .frame(height: 42)
                                .foregroundStyle(palette.window)
                                .background(palette.text, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        heroAction("Add to queue", icon: "text.badge.plus") {
                            store.enqueue(store.feed.hero)
                        }
                        heroAction(
                            store.isSaved(store.feed.hero) ? "Remove from Watch Later" : "Save to Watch Later",
                            icon: store.isSaved(store.feed.hero) ? "bookmark.fill" : "bookmark"
                        ) { store.toggleSaved(store.feed.hero) }
                    }
                    }
                    .padding(.top, 4)
                }
                .foregroundStyle(palette.text)
                .frame(maxWidth: compact ? .infinity : min(geometry.size.width * 0.55, 620), alignment: .leading)
                .padding(compact ? 24 : 32)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(palette.stroke, lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: compact ? 320 : 340)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Featured video")
    }

    private func heroAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 42, height: 42)
                .youGlassSurface(palette: palette, cornerRadius: 21, interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
    }
}
