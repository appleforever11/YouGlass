import SwiftUI

struct VideoRow: View {
    @EnvironmentObject private var store: YouTubeStore
    let title: String
    let videos: [VideoItem]
    let palette: Palette
    let compact: Bool
    var showsSeeAll: Bool = true

    var body: some View {
        // Four columns match the desktop composition. At compact widths,
        // two larger cards remain readable instead of allowing an adaptive
        // grid to create tiny cards and unused phantom columns.
        let columns = Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: 18),
            count: compact ? 2 : 4
        )

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 9) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [palette.pink, palette.purple],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4, height: 18)
                    Text(title)
                        .font(.system(size: 19, weight: .bold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .layoutPriority(1)

                Spacer(minLength: 12)

                if showsSeeAll {
                    Button(action: { store.showSection(title) }) {
                        HStack(spacing: 8) {
                            Text("See All")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .frame(minWidth: 104)
                        .frame(height: 36)
                        .background(palette.accent.opacity(palette.isDark ? 0.12 : 0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(palette.stroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .layoutPriority(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(
                columns: columns,
                alignment: .leading,
                spacing: 20
            ) {
                ForEach(videos) { video in
                    VideoCard(video: video, palette: palette)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct VideoCard: View {
    @EnvironmentObject private var store: YouTubeStore
    let video: VideoItem
    let palette: Palette
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        Button(action: { store.openFromUserInteraction(video) }) {
            VStack(alignment: .leading, spacing: 9) {
                YouGlassVideoPreview {
                    ZStack(alignment: .bottomTrailing) {
                        RemoteImage(url: video.thumbnailURL)
                            .clipped()

                        LinearGradient(
                            colors: [.clear, .black.opacity(0.28)],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        if !video.duration.isEmpty {
                            Text(video.duration)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 3)
                                .background(.black.opacity(0.82))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .padding(7)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .videoThumbnailParallax()
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(store.ambientPalette.primary.color.opacity(0.26), lineWidth: 1)
                }

                Text(video.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .lineLimit(2)
                    .frame(height: 36, alignment: .topLeading)

                HStack(spacing: 4) {
                    Text(video.channel)
                    if video.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.blue)
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)

                Text("\(video.views) • \(video.age)")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering { store.prewarmPlayback(for: video) }
        }
        .scaleEffect(accessibilityReduceMotion ? 1 : (isHovered ? 1.012 : 1))
        .animation(accessibilityReduceMotion ? nil : .easeOut(duration: 0.16), value: isHovered)
        .accessibilityLabel("\(video.title), by \(video.channel)")
        .contextMenu {
            Button(store.isSaved(video) ? "Remove from Watch Later" : "Save to Watch Later") {
                store.toggleSaved(video)
            }
            Button("Play Next") {
                store.enqueue(video)
            }
            if store.customCollections.isEmpty {
                Button("Create a collection in Library") {
                    store.showSection("Library")
                }
            } else {
                Menu("Add to Collection") {
                    ForEach(store.customCollections) { collection in
                        Button {
                            store.add(video, toCollectionID: collection.id)
                        } label: {
                            Label(
                                collection.name,
                                systemImage: store.collectionContains(video, collectionID: collection.id)
                                    ? "checkmark"
                                    : "folder"
                            )
                        }
                    }
                }
            }
        }
    }
}

struct CompactVideoCard: View {
    @EnvironmentObject private var store: YouTubeStore
    let video: VideoItem
    let palette: Palette

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(url: video.thumbnailURL)
                .frame(width: 92, height: 52)
                .videoThumbnailParallax(translation: 3.5, rotation: 2.2)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                Text(video.channel)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
                Text(video.duration)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(7)
        .frame(height: 76)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .youGlassSurface(palette: palette, cornerRadius: 10)
        .onHover { hovering in
            if hovering { store.prewarmPlayback(for: video) }
        }
        .accessibilityLabel("\(video.title), by \(video.channel)")
    }
}
