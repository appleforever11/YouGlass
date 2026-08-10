import SwiftUI

struct YouTubeChannelView: View {
    @EnvironmentObject private var store: YouTubeStore
    let palette: Palette

    @State private var selectedTab: ChannelTab = .home

    var body: some View {
        VStack(spacing: 0) {
            channelToolbar

            if store.channelLoading {
                channelLoadingView
            } else if let message = store.channelError {
                channelErrorView(message: message)
            } else if let page = store.channelPage {
                channelPageView(page)
            } else {
                channelLoadingView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.content)
        .task(id: store.selectedChannelItem?.id) {
            selectedTab = .home
        }
    }

    private var channelToolbar: some View {
        HStack(spacing: 12) {
            Button(action: { store.closeChannel() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(GlassIconButtonStyle(palette: palette))
            .help("Back to Home")

            VStack(alignment: .leading, spacing: 2) {
                Text("Channel")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                Text(store.channelPage?.channel.name ?? store.selectedChannelItem?.name ?? "YouTube")
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
            }

            Spacer()

            Text("Native channel view")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.tertiaryText)
        }
        .padding(.horizontal, 24)
        .frame(height: 68)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.hairline)
                .frame(height: 1)
        }
    }

    private var channelLoadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.regular)
            Text("Loading channel...")
                .font(.system(size: 15, weight: .semibold))
            Text("YouGlass is loading the channel header and public videos through the YouTube Data API.")
                .font(.system(size: 12))
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func channelErrorView(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(palette.secondaryText)
            Text("Channel data unavailable")
                .font(.system(size: 18, weight: .bold))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
            Button("Try Again") {
                if let item = store.selectedChannelItem {
                    store.openChannel(item)
                }
            }
            .buttonStyle(GlassCapsuleButtonStyle(palette: palette))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func channelPageView(_ page: YouTubeChannelPage) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                channelHeader(page.channel)
                channelTabs
                channelContent(page)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func channelHeader(_ channel: YouTubeChannel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                RemoteImage(url: channel.bannerURL)
                    .frame(height: 156)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay {
                        LinearGradient(
                            colors: [.clear, palette.content.opacity(0.92)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack(alignment: .bottom, spacing: 16) {
                    AsyncAvatar(url: channel.avatarURL)
                        .frame(width: 92, height: 92)
                        .overlay(Circle().stroke(palette.content, lineWidth: 4))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(channel.name)
                            .font(.system(size: 24, weight: .bold))
                            .lineLimit(1)
                        Text("\(channel.handle)  •  \(channel.subscriberCount)  •  \(channel.videoCount)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(1)
                    }
                    .padding(.bottom, 8)

                    Spacer(minLength: 0)

                    Text("Subscribed")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(palette.text)
                        .padding(.horizontal, 16)
                        .frame(height: 34)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(palette.stroke, lineWidth: 1))
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 20)
            }

            if !channel.description.isEmpty {
                Text(channel.description)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(3)
                    .padding(.top, 12)
            }
        }
    }

    private var channelTabs: some View {
        HStack(spacing: 6) {
            ForEach(ChannelTab.allCases) { tab in
                Button(action: { selectedTab = tab }) {
                    Text(tab.title)
                        .font(.system(size: 13, weight: selectedTab == tab ? .bold : .medium))
                        .foregroundStyle(selectedTab == tab ? palette.text : palette.secondaryText)
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background(selectedTab == tab ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.clear))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(selectedTab == tab ? palette.stroke : .clear, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.hairline)
                .frame(height: 1)
        }
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func channelContent(_ page: YouTubeChannelPage) -> some View {
        switch selectedTab {
        case .home:
            VStack(alignment: .leading, spacing: 18) {
                channelSectionHeader("Latest videos", count: page.videos.count)
                videoGrid(page.videos)
            }
        case .videos:
            VStack(alignment: .leading, spacing: 18) {
                channelSectionHeader("Videos", count: page.videos.count)
                videoGrid(page.videos)
            }
        case .shorts:
            VStack(alignment: .leading, spacing: 18) {
                channelSectionHeader("Shorts", count: page.shorts.count)
                if page.shorts.isEmpty {
                    emptyChannelState("No Shorts were returned for this channel.")
                } else {
                    videoGrid(page.shorts)
                }
            }
        case .live:
            VStack(alignment: .leading, spacing: 18) {
                channelSectionHeader("Live", count: page.live.count)
                if page.live.isEmpty {
                    emptyChannelState("No active live broadcasts were returned right now.")
                } else {
                    videoGrid(page.live)
                }
            }
        case .playlists:
            emptyChannelState("Channel playlists will appear here when YouTube returns them through the Data API.")
        }
    }

    private func channelSectionHeader(_ title: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 19, weight: .bold))
            Text("\(count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.secondaryText)
            Spacer()
        }
    }

    private func videoGrid(_ videos: [VideoItem]) -> some View {
        let visible = Array(videos.prefix(24))
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 4),
            spacing: 24
        ) {
            ForEach(visible) { video in
                ChannelVideoCard(video: video, palette: palette) {
                    store.open(video)
                }
            }
        }
    }

    private func emptyChannelState(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.stack.badge.play")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(palette.secondaryText)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.secondaryText)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.stroke, lineWidth: 1))
    }
}

private enum ChannelTab: String, CaseIterable, Identifiable {
    case home
    case videos
    case shorts
    case live
    case playlists

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .videos: return "Videos"
        case .shorts: return "Shorts"
        case .live: return "Live"
        case .playlists: return "Playlists"
        }
    }
}

private struct ChannelVideoCard: View {
    let video: VideoItem
    let palette: Palette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    RemoteImage(url: video.imageURL)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .videoThumbnailParallax()
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    if !video.duration.isEmpty {
                        Text(video.duration)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.82))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .padding(7)
                    }
                }

                Text(video.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(palette.text)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(video.views)  •  \(video.age)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
