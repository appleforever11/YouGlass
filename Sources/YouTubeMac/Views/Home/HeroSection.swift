import SwiftUI

/// A single featured stage; the recommendation grid owns the surrounding catalog.
struct HeroSection: View {
    @EnvironmentObject private var store: YouTubeStore
    let palette: Palette
    let compact: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
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
                                    .init(color: .black.opacity(0.08), location: 0),
                                    .init(color: .black.opacity(0.48), location: 0.40),
                                    .init(color: .black.opacity(0.96), location: 1)
                                ],
                                startPoint: .topTrailing, endPoint: .bottomLeading
                            )
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play featured video: \(store.feed.hero.title)")
                .onHover { if $0 { store.prewarmPlayback(for: store.feed.hero) } }

                VStack(alignment: .leading, spacing: 12) {
                    Label("THE SPOTLIGHT", systemImage: "play.rectangle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.6)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.16), in: Capsule())
                    Text(store.feed.hero.title)
                        .font(.system(size: compact ? 29 : 44, weight: .bold))
                        .tracking(-1.0)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                        .allowsHitTesting(false)
                    Text([store.feed.hero.channel, store.feed.hero.age, store.feed.hero.duration]
                        .filter { !$0.isEmpty }.joined(separator: "  ·  "))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                        .allowsHitTesting(false)
                    HStack(spacing: 10) {
                        Button {
                            store.openFromUserInteraction(store.feed.hero)
                        } label: {
                            Label("Watch now", systemImage: "play.fill")
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 18)
                                .frame(height: 42)
                                .foregroundStyle(.black)
                                .background(.white, in: Capsule())
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
                    .padding(.top, 4)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: compact ? .infinity : min(geometry.size.width * 0.72, 820), alignment: .leading)
                .padding(compact ? 24 : 40)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(palette.stroke, lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: compact ? 380 : 460)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Featured video")
    }

    private func heroAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.18), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
    }
}
