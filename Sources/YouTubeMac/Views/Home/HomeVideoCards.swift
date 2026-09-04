import SwiftUI

struct VideoRow: View {
    @EnvironmentObject private var store: YouTubeStore
    let title: String
    let videos: [VideoItem]
    let palette: Palette
    let compact: Bool
    var showsSeeAll: Bool = true

    var body: some View {
        // Width, not a shell breakpoint, decides how many readable cards fit.
        let columns = [GridItem(.adaptive(minimum: 260), spacing: 18)]

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
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(title)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Text("\(videos.count)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(palette.secondaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(palette.pill, in: Capsule())
                        }
                        Text(sectionSubtitle)
                            .font(.caption)
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(1)
                    }
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
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

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

    private var sectionSubtitle: String {
        switch title {
        case "For You": "Fresh picks shaped by your subscriptions and local viewing"
        case "Trending": "Popular videos from the channels and topics you follow"
        case "More to watch": "Keep exploring beyond your usual favorites"
        case "Watch Later": "Saved locally and ready when you are"
        case "Liked on this Mac": "Videos you marked as favorites in YouGlass"
        case "Search results": "Find your next great watch"
        default: "Videos selected for this collection"
        }
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

                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.62), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.58), lineWidth: 1))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .opacity(isHovered ? 1 : 0)
                            .scaleEffect(isHovered ? 1 : 0.82)
                            .allowsHitTesting(false)
                            .transaction { $0.animation = nil }

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
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(store.ambientPalette.primary.color.opacity(0.26), lineWidth: 1)
                }

                Text(video.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .lineLimit(2)
                    .frame(height: 40, alignment: .topLeading)

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

                Text([video.views, video.age].filter { !$0.isEmpty }.joined(separator: " • "))
                    .font(.system(size: 12))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isHovered ? palette.selected : palette.card.opacity(0.72))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isHovered ? palette.accent.opacity(0.65) : palette.stroke.opacity(0.5), lineWidth: 1)
            }
            .scaleEffect(accessibilityReduceMotion ? 1 : (isHovered ? 1.012 : 1))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .videoCardHover(isHovered: $isHovered, videoID: video.id) {
            store.prewarmPlayback(for: video)
        }
        .shadow(color: isHovered ? .black.opacity(palette.isDark ? 0.30 : 0.10) : .clear, radius: 14, y: 7)
        .animation(accessibilityReduceMotion ? nil : .easeOut(duration: 0.08), value: isHovered)
        .accessibilityLabel("\(video.title), by \(video.channel)")
        .accessibilityHint("Open in the YouGlass player. Use the context menu to save or queue this video.")
        .contextMenu {
            Button(store.isSaved(video) ? "Remove from Watch Later" : "Save to Watch Later") {
                store.toggleSaved(video)
            }
            Button(store.selectedVideo == nil ? "Add to Queue" : "Play Next") {
                if store.selectedVideo == nil {
                    store.enqueue(video)
                } else {
                    store.enqueueNext(video)
                }
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
