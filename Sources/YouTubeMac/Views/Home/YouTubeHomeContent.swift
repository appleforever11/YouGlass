import SwiftUI

extension YouTubeHomeView {
    func mainContent(compact: Bool) -> some View {
        VStack(spacing: 0) {
            YouGlassBrowseToolbar(palette: palette)

            // Keep this as the single vertical scroll owner for the home
            // surface. Nested adaptive grids can otherwise consume the
            // available height without giving the user a reliable way to
            // reach the lower recommendation rows on smaller displays.
            homeRefreshContainer {
                VStack(alignment: .leading, spacing: 22) {
                    if store.selectedSection == "Home" {
                        HomeDashboardHeader(palette: palette, compact: compact)
                    }

                    if store.selectedSection == "Home" {
                        CustomFeedStripView(palette: palette)
                            .environmentObject(store)
                    }

                    if store.selectedSection == "Subscription Group" {
                        SubscriptionGroupDetailView(palette: palette, compact: compact)
                    } else if store.selectedSection == "Explore" {
                        DiscoveryView(palette: palette)
                    } else if store.selectedSection == "Library" {
                        PersonalLibraryView(palette: palette, compact: compact)
                            .environmentObject(store)
                    } else if store.selectedSection == "Search" {
                        SearchContentView(store: store, palette: palette, compact: compact)
                    } else if store.selectedCustomFeed != nil {
                        CustomFeedDetailView(palette: palette, compact: compact)
                            .environmentObject(store)
                    } else if let message = store.sectionEmptyMessage {
                        HomeSectionEmptyState(
                            title: store.selectedSection,
                            message: message,
                            palette: palette
                        ) {
                            store.showSection("Home")
                        }
                    } else if let playlist = store.selectedPlaylist {
                        PlaylistDetailView(playlist: playlist, palette: palette)
                    } else if store.selectedSection == "Playlists" {
                        PlaylistLibraryView(palette: palette)
                    } else if store.selectedSection != "Home" {
                        if store.isLoading {
                            ProgressView("Loading \(store.selectedSection)…")
                                .frame(maxWidth: .infinity, minHeight: 260)
                        } else {
                            VideoRow(title: store.selectedSection, videos: sectionVideos, palette: palette, compact: compact, showsSeeAll: false)
                                .padding(.top, 20)
                        }
                    } else {
                        HomeRecommendationContent(palette: palette, compact: compact)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, compact ? 14 : 30)
                // Leave a real, reachable breathing room after the final row.
                .padding(.bottom, compact ? 72 : 88)
            }
            // A navigation destination gets a fresh viewport; feed updates do not.
            .id(store.selectedSection)
        }
    }

    @ViewBuilder
    private func homeRefreshContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(macOS 27.0, *) {
            YouGlassHomeScrollView(
                isRefreshEnabled: store.selectedSection == "Home" && store.selectedCustomFeed == nil,
                refreshTint: palette.accent,
                refreshAction: {
                    await store.loadHome(force: true)
                },
                content: {
                    content()
                        .coordinateSpace(name: "youglass-card-document")
                        .environment(\.cardPointerUsesDocumentSpace, true)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.vertical, showsIndicators: true) {
                content()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollBounceBehavior(.basedOnSize)
            .refreshable {
                guard store.selectedSection == "Home", store.selectedCustomFeed == nil else { return }
                await store.loadHome(force: true)
            }
        }
    }

    var channelContent: some View {
        YouTubeChannelView(palette: palette)
            .environmentObject(store)
            .background {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    LinearGradient(
                        colors: [
                            palette.purple.opacity(palette.isDark ? 0.10 : 0.05),
                            .clear,
                            palette.pink.opacity(palette.isDark ? 0.08 : 0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
    }

    private var sectionVideos: [VideoItem] {
        switch store.selectedSection {
        case "Watch Later": return store.savedVideos
        case "For You": return store.feed.forYou
        case "Trending": return store.feed.trending
        case "More to watch": return store.feed.more
        default:
            var seen = Set<String>()
            return (store.feed.forYou + store.feed.trending + store.feed.more + store.feed.queue)
                .filter { seen.insert($0.id).inserted }
        }
    }
}
