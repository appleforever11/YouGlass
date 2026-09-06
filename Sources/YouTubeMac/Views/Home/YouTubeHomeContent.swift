import SwiftUI

extension YouTubeHomeView {
    func mainContent(compact: Bool) -> some View {
        VStack(spacing: 0) {
            topBar

            // Keep this as the single vertical scroll owner for the home
            // surface. Nested adaptive grids can otherwise consume the
            // available height without giving the user a reliable way to
            // reach the lower recommendation rows on smaller displays.
            homeRefreshContainer {
                VStack(alignment: .leading, spacing: 22) {
                    if store.selectedSection == "Home" {
                        HomeDashboardHeader(palette: palette, compact: compact)
                    } else if store.selectedSection != "Library" && store.selectedSection != "Search" {
                        Text(store.selectedSection)
                            .font(.system(size: 26, weight: .bold))
                            .padding(.top, 6)
                    }

                    if store.selectedSection == "Home" {
                        CustomFeedStripView(palette: palette)
                            .environmentObject(store)
                    }

                    if store.selectedSection == "Library" {
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
                    } else {
                        if store.feed.forYou.isEmpty && store.feed.trending.isEmpty && store.feed.more.isEmpty {
                            if store.isLoading {
                                HomeLoadingView(palette: palette)
                            } else {
                                HomeUnavailableView(store: store, palette: palette) {
                                    Task { await store.loadHome(force: true) }
                                }
                            }
                        } else {
                            HeroSection(palette: palette, compact: compact)
                        }

                        if !store.feed.forYou.isEmpty {
                            VideoRow(
                                title: "For You",
                                videos: store.feed.forYou,
                                palette: palette,
                                compact: compact
                            )
                        }

                        if store.selectedSection == "Home",
                           store.showContinueWatching,
                           !store.continueWatching.isEmpty {
                            ContinueWatchingRow(palette: palette, compact: compact)
                                .environmentObject(store)
                        }

                        if !store.feed.trending.isEmpty {
                            VideoRow(
                                title: "Trending",
                                videos: store.feed.trending,
                                palette: palette,
                                compact: compact
                            )
                        }
                        if !store.feed.more.isEmpty {
                            VideoRow(
                                title: "More to watch",
                                videos: store.feed.more,
                                palette: palette,
                                compact: compact,
                                showsSeeAll: false
                            )

                            VStack(spacing: 10) {
                                Text("Ready for something different?")
                                    .font(.headline)
                                Text("Refresh Home for another mix of videos.")
                                Button("Discover more") {
                                    store.showSection("Home")
                                    Task { await store.loadHome(force: true) }
                                }
                                .buttonStyle(.bordered)
                                .disabled(store.isLoading)
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(palette.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        }
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
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [
                        palette.purple.opacity(palette.isDark ? 0.13 : 0.07),
                        .clear,
                        palette.pink.opacity(palette.isDark ? 0.10 : 0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    @ViewBuilder
    private func homeRefreshContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(macOS 27.0, *) {
            YouGlassHomeScrollView(
                isRefreshEnabled: store.selectedSection == "Home" && store.selectedCustomFeed == nil,
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

    private var topBar: some View {
        GeometryReader { geometry in
            let minimal = geometry.size.width < 560
            let compact = geometry.size.width < 860

            Group {
                if minimal {
                    topBarContent(compact: true, minimal: true)
                } else {
                    topBarContent(compact: compact, minimal: false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 68)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.hairline)
                .frame(height: 1)
                .padding(.horizontal, 22)
        }
    }

    private func topBarContent(compact: Bool, minimal: Bool) -> some View {
        HStack(spacing: minimal ? 6 : (compact ? 10 : 22)) {
            SearchField(
                text: $store.query,
                focusRequestID: store.searchFocusRequestID,
                palette: palette
            ) {
                store.startSearch()
            }
            .frame(
                minWidth: minimal ? 80 : (compact ? 160 : 250),
                maxWidth: minimal ? .infinity : (compact ? 360 : 500)
            )
            .layoutPriority(1)

            Button(action: store.toggleCommandPalette) {
                Image(systemName: "command")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(IconButtonStyle(palette: palette))
            .accessibilityLabel("Open command palette")
            .help("Command palette (⌘K)")

            if !minimal {
                Button(action: store.presentNewCustomFeedComposer) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(IconButtonStyle(palette: palette))
                .accessibilityLabel("Create a custom feed")
                .help("Create a custom feed")
            }

            Spacer(minLength: minimal ? 4 : (compact ? 6 : 12))

            if minimal {
                EmptyView()
            } else {
                HomeConnectionStatusView(
                    store: store,
                    palette: palette,
                    compact: compact
                )
            }

            if store.selectedSection != "Library" {
            Button {
                if store.selectedCustomFeed != nil {
                    store.refreshSelectedCustomFeed()
                } else if store.selectedSection == "Search" {
                    store.startSearch()
                } else {
                    Task { await store.loadHome(force: true) }
                }
            } label: {
                if store.isLoading || store.customFeedLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .buttonStyle(IconButtonStyle(palette: palette))
            .accessibilityLabel(store.selectedSection == "Search" ? "Refresh search results" : "Refresh recommendations")
            .help(store.selectedSection == "Search" ? "Refresh search results" : "Refresh recommendations")
            .disabled(store.isLoading || store.customFeedLoading)
            }

            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(IconButtonStyle(palette: palette))
            .accessibilityLabel("YouGlass settings")
            .help("YouGlass settings")

            if minimal {
                Menu {
                    Button("Create custom feed", action: store.presentNewCustomFeedComposer)
                    Button("Notifications") { store.showSection("Notifications") }
                    Divider()
                    Picker("Appearance", selection: Binding(
                        get: { store.theme }, set: { store.setTheme($0) }
                    )) {
                        Text("Light").tag(AppTheme.light)
                        Text("Dark").tag(AppTheme.dark)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel("More Home actions")
            }

            if !minimal {
                Picker("Appearance", selection: Binding(
                    get: { store.theme },
                    set: { newTheme in store.setTheme(newTheme) }
                )) {
                    Text(AppTheme.light.rawValue).tag(AppTheme.light)
                    Text(AppTheme.dark.rawValue).tag(AppTheme.dark)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: compact ? 100 : 122)
            }

            if !minimal {
                Button(action: { store.showSection("Notifications") }) {
                    Image(systemName: "bell")
                        .font(.system(size: 17, weight: .medium))
                }
                .buttonStyle(IconButtonStyle(palette: palette))
                .accessibilityLabel("Notifications")
            }

            Button(action: { store.login() }) {
                ZStack(alignment: .bottomTrailing) {
                    AsyncAvatar(url: store.profileImageURL)
                        .frame(width: 34, height: 34)

                    if store.isSignedIn {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(palette.window, lineWidth: 2))
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.isSignedIn ? "YouTube account" : "Sign in to YouTube")
            .help(store.isSignedIn ? "Signed in" : "Sign in")
        }
        .padding(.horizontal, minimal ? 8 : (compact ? 12 : 28))
        .frame(maxWidth: .infinity)
    }
}
