import SwiftUI

struct PlaylistLibraryView: View {
    @EnvironmentObject private var store: YouTubeStore
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Playlists")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button {
                    store.showSection("Playlists")
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(store.playlistLoading)
            }

            if store.playlistLoading {
                ProgressView("Loading playlists from YouTube...")
                    .frame(maxWidth: .infinity, minHeight: 240, alignment: .center)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 170, maximum: 320), spacing: 18)],
                    alignment: .leading,
                    spacing: 18
                ) {
                    ForEach(store.playlists) { playlist in
                        Button {
                            store.openPlaylist(playlist)
                        } label: {
                            PlaylistCard(playlist: playlist, palette: palette)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PlaylistDetailView: View {
    @EnvironmentObject private var store: YouTubeStore
    let playlist: YouTubePlaylist
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GeometryReader { geometry in
                let imageWidth = min(180, max(96, geometry.size.width * 0.28))
                let titleSize = geometry.size.width < 600 ? CGFloat(17) : CGFloat(22)

                HStack(alignment: .top, spacing: 16) {
                    playlistSummaryHeader(imageWidth: imageWidth, titleSize: titleSize)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 132)
            .padding(14)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(palette.stroke, lineWidth: 1))

            if store.playlistLoading {
                ProgressView("Loading playlist videos...")
                    .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
            } else if let playlistError = store.playlistError {
                VStack(alignment: .leading, spacing: 10) {
                    Text(playlistError)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                    Button {
                        store.openPlaylist(playlist)
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
            } else if store.playlistItems.isEmpty {
                Text("This playlist has no playable videos.")
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 170, maximum: 320), spacing: 18)],
                    alignment: .leading,
                    spacing: 18
                ) {
                    ForEach(store.playlistItems) { video in
                        VideoCard(video: video, palette: palette)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func playlistSummaryHeader(imageWidth: CGFloat, titleSize: CGFloat) -> some View {
        Button(action: store.closePlaylist) {
            Image(systemName: "chevron.left")
                .frame(width: 28, height: 28)
        }
        .buttonStyle(GlassIconButtonStyle(palette: palette))
        .help("Back to playlists")

        RemoteImage(url: playlist.thumbnailURL)
            .frame(width: imageWidth, height: imageWidth * 9 / 16)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        VStack(alignment: .leading, spacing: 7) {
            Text(playlist.title)
                .font(.system(size: titleSize, weight: .bold))
                .lineLimit(2)
            Text(playlist.description.isEmpty ? "YouTube playlist" : playlist.description)
                .font(.system(size: 13))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(3)
            Text(playlist.itemCount > 0 ? "\(playlist.itemCount) videos" : "Videos from YouTube")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.secondaryText)
        }
        Spacer(minLength: 0)
    }
}

struct PlaylistCard: View {
    let playlist: YouTubePlaylist
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            YouGlassVideoPreview {
                ZStack(alignment: .bottomTrailing) {
                    RemoteImage(url: playlist.thumbnailURL)
                        .clipped()

                    Label("Open", systemImage: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .frame(height: 26)
                        .background(.black.opacity(0.76))
                        .clipShape(Capsule())
                        .padding(8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(playlist.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.text)
                .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: 36, alignment: .topLeading)
            Text(playlist.itemCount > 0 ? "\(playlist.itemCount) videos" : "Playlist")
                .font(.system(size: 12))
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
