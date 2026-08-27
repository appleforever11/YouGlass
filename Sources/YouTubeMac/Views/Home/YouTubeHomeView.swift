import SwiftUI

struct YouTubeHomeView: View {
    @EnvironmentObject private var store: YouTubeStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var compactDragOffset: CGSize = .zero

    private var palette: Palette {
        Palette(colorScheme, theme: store.visualTheme, customization: store.themeCustomization)
    }

    var body: some View {
        GeometryReader { geometry in
            let compactShell = geometry.size.width < 980
            let shellInset: CGFloat = compactShell ? 8 : 14
            let sidebarWidth: CGFloat = compactShell ? 76 : 236
            let mainContentWidth = max(
                1,
                geometry.size.width - shellInset * 2 - sidebarWidth
            )
            // Base the content breakpoint on the space left after the
            // sidebar. This keeps medium windows from forcing desktop-sized
            // grids into a layout that cannot hold them.
            let compactContent = mainContentWidth < 1_000

            ZStack {
                YouGlassAmbientBackdrop(palette: palette, ambientPalette: store.ambientPalette, intensity: 1.15)
                    .ignoresSafeArea()

                HStack(spacing: 0) {
                    SidebarView(palette: palette, compact: compactShell)
                        .frame(width: sidebarWidth)
                        .frame(maxHeight: .infinity, alignment: .top)

                    ZStack(alignment: .topLeading) {
                        if store.selectedChannelItem != nil {
                            channelContent
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        } else {
                            mainContent(compact: compactContent)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }

                        if let video = store.selectedVideo {
                            if store.isDesktopPIPActive {
                                // Playback is hosted by the separate desktop PIP
                                // panel. Keep the feed interactive underneath it.
                                Color.clear
                                    .allowsHitTesting(false)
                            } else if store.isPlayerCompact {
                                GeometryReader { playerGeometry in
                                    compactPlayer(video: video, in: playerGeometry.size)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                YouTubePlayerOverlay(
                                    video: video,
                                    palette: palette,
                                    isCompact: false,
                                    onCompactDragChanged: nil,
                                    onCompactDragEnded: nil
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }

                if store.commandPalettePresented {
                    Color.black.opacity(colorScheme == .dark ? 0.42 : 0.22)
                        .ignoresSafeArea()
                        .onTapGesture { store.commandPalettePresented = false }
                        .zIndex(20)

                    CommandPaletteView(
                        palette: palette,
                        dismiss: { store.commandPalettePresented = false }
                    )
                    .environmentObject(store)
                    .zIndex(21)
                }
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.stroke, lineWidth: 1)
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.45 : 0.12), radius: 24, y: 10)
                // The hidden title-bar region already contributes a safe inset.
                // Add only a small visual breathing room so the app surface does
                // not create a second, oversized black band above the content.
                .padding(.horizontal, shellInset)
                .padding(.top, compactShell ? 8 : 12)
                .padding(.bottom, compactShell ? 8 : 14)
            }
        }
        .onChange(of: store.compactPlayerCorner) { _, _ in
            compactDragOffset = .zero
        }
        .onChange(of: store.selectedVideo?.id) { _, _ in
            compactDragOffset = .zero
        }
    }

    private func compactPlayer(video: VideoItem, in containerSize: CGSize) -> some View {
        // Keep the mini-player inside the visible content area at every
        // window size. Height is intentionally capped as well as width so a
        // short window cannot leave the PIP surface clipped below the edge.
        let shortestSide = min(containerSize.width, containerSize.height)
        let inset = min(
            CompactPlayerMetrics.edgeInset,
            max(8, shortestSide * 0.04)
        )
        let availableWidth = max(1, containerSize.width - inset * 2)
        let availableHeight = max(1, containerSize.height - inset * 2)
        let widthByHeight = availableHeight * 0.36 * CompactPlayerMetrics.aspectRatio
        let widthLimit = min(
            CompactPlayerMetrics.maxWidth,
            availableWidth,
            widthByHeight,
            max(180, containerSize.width * CompactPlayerMetrics.widthFraction)
        )
        let minimumWidth = min(
            CompactPlayerMetrics.minimumWidth,
            availableWidth,
            availableHeight * CompactPlayerMetrics.aspectRatio
        )
        let width = max(minimumWidth, widthLimit)
        let height = width / CompactPlayerMetrics.aspectRatio
        let outerHalfWidth = (width + inset * 2) / 2
        let outerHalfHeight = (height + inset * 2) / 2
        let baseCenter = compactPlayerCenter(
            corner: store.compactPlayerCorner,
            containerSize: containerSize,
            halfWidth: outerHalfWidth,
            halfHeight: outerHalfHeight
        )

        return YouTubePlayerOverlay(
            video: video,
            palette: palette,
            isCompact: true,
            onCompactDragChanged: { translation in
                let desiredCenter = CGPoint(
                    x: baseCenter.x + translation.width,
                    y: baseCenter.y + translation.height
                )
                let clampedCenter = clampedCompactPlayerCenter(
                    desiredCenter,
                    containerSize: containerSize,
                    halfWidth: outerHalfWidth,
                    halfHeight: outerHalfHeight
                )
                compactDragOffset = CGSize(
                    width: clampedCenter.x - baseCenter.x,
                    height: clampedCenter.y - baseCenter.y
                )
            },
            onCompactDragEnded: { translation in
                let desiredCenter = CGPoint(
                    x: baseCenter.x + translation.width,
                    y: baseCenter.y + translation.height
                )
                let clampedCenter = clampedCompactPlayerCenter(
                    desiredCenter,
                    containerSize: containerSize,
                    halfWidth: outerHalfWidth,
                    halfHeight: outerHalfHeight
                )
                let snappedCorner = nearestCompactPlayerCorner(
                    to: clampedCenter,
                    containerSize: containerSize,
                    halfWidth: outerHalfWidth,
                    halfHeight: outerHalfHeight
                )
                withAnimation(.snappy(duration: 0.24)) {
                    compactDragOffset = .zero
                    store.setCompactPlayerCorner(snappedCorner)
                }
            }
        )
        .frame(width: width, height: height)
        .clipped()
        .padding(inset)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: store.compactPlayerCorner.alignment
        )
        .offset(compactDragOffset)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .zIndex(2)
    }

    private func compactPlayerCenter(
        corner: CompactPlayerCorner,
        containerSize: CGSize,
        halfWidth: CGFloat,
        halfHeight: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: corner == .topLeading || corner == .bottomLeading
                ? halfWidth
                : containerSize.width - halfWidth,
            y: corner == .topLeading || corner == .topTrailing
                ? halfHeight
                : containerSize.height - halfHeight
        )
    }

    private func clampedCompactPlayerCenter(
        _ desired: CGPoint,
        containerSize: CGSize,
        halfWidth: CGFloat,
        halfHeight: CGFloat
    ) -> CGPoint {
        let minX = min(halfWidth, containerSize.width / 2)
        let maxX = max(minX, containerSize.width - halfWidth)
        let minY = min(halfHeight, containerSize.height / 2)
        let maxY = max(minY, containerSize.height - halfHeight)

        return CGPoint(
            x: min(max(desired.x, minX), maxX),
            y: min(max(desired.y, minY), maxY)
        )
    }

    private func nearestCompactPlayerCorner(
        to point: CGPoint,
        containerSize: CGSize,
        halfWidth: CGFloat,
        halfHeight: CGFloat
    ) -> CompactPlayerCorner {
        CompactPlayerCorner.allCases.min { lhs, rhs in
            distanceSquared(
                compactPlayerCenter(
                    corner: lhs,
                    containerSize: containerSize,
                    halfWidth: halfWidth,
                    halfHeight: halfHeight
                ),
                point
            ) < distanceSquared(
                compactPlayerCenter(
                    corner: rhs,
                    containerSize: containerSize,
                    halfWidth: halfWidth,
                    halfHeight: halfHeight
                ),
                point
            )
        } ?? .bottomTrailing
    }

    private func distanceSquared(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        let deltaX = lhs.x - rhs.x
        let deltaY = lhs.y - rhs.y
        return deltaX * deltaX + deltaY * deltaY
    }

    private func mainContent(compact: Bool) -> some View {
        VStack(spacing: 0) {
            topBar

            // Keep this as the single vertical scroll owner for the home
            // surface. Nested adaptive grids can otherwise consume the
            // available height without giving the user a reliable way to
            // reach the lower recommendation rows on smaller displays.
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(store.selectedSection)
                        .font(.system(size: 26, weight: .bold))
                        .padding(.top, 6)

                    if store.selectedSection == "Library" {
                        PersonalLibraryView(palette: palette, compact: compact)
                            .environmentObject(store)
                    } else if let message = store.sectionEmptyMessage {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(palette.secondaryText)
                            Text(message)
                                .font(.system(size: 16, weight: .semibold))
                            Text("Your feed will appear here when this section has content.")
                                .font(.system(size: 13))
                                .foregroundStyle(palette.secondaryText)
                        }
                        .frame(maxWidth: .infinity, minHeight: 260, alignment: .center)
                    } else if let playlist = store.selectedPlaylist {
                        PlaylistDetailView(playlist: playlist, palette: palette)
                    } else if store.selectedSection == "Playlists" {
                        PlaylistLibraryView(palette: palette)
                    } else if store.selectedSection == "Search" {
                        SearchContentView(store: store, palette: palette, compact: compact)
                    } else {
                        if store.feed.forYou.isEmpty && store.feed.trending.isEmpty && store.feed.more.isEmpty {
                            if store.isLoading {
                                HomeLoadingView(palette: palette)
                            } else {
                                HomeUnavailableView(palette: palette) {
                                    Task { await store.loadHome(force: true) }
                                }
                            }
                        } else {
                            HeroSection(palette: palette, compact: compact)
                        }

                        if store.selectedSection == "Home",
                           store.showContinueWatching,
                           !store.continueWatching.isEmpty {
                            ContinueWatchingRow(palette: palette, compact: compact)
                                .environmentObject(store)
                        }

                        if !store.feed.forYou.isEmpty {
                            VideoRow(
                                title: "For You",
                                videos: store.feed.forYou,
                                palette: palette,
                                compact: compact
                            )
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

                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                Text("You're all caught up")
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollBounceBehavior(.basedOnSize)
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

    private var channelContent: some View {
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
            SearchField(text: $store.query, palette: palette) {
                Task { await store.search() }
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

            Spacer(minLength: minimal ? 4 : (compact ? 6 : 12))

            if minimal {
                EmptyView()
            } else if compact {
                HStack(spacing: 5) {
                    Circle()
                        .fill(store.isNetworkAvailable ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Image(systemName: store.isSignedIn ? "checkmark.circle.fill" : "icloud.slash")
                }
                    .foregroundStyle(store.isNetworkAvailable && store.isSignedIn ? Color.green : palette.secondaryText)
                    .accessibilityLabel(store.connectionMessage)
                    .help("\(store.networkStatus). \(store.connectionMessage)")
            } else {
                HStack(spacing: 6) {
                    Circle()
                        .fill(store.isNetworkAvailable ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(store.connectionMessage)
                }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(store.isNetworkAvailable ? palette.secondaryText : Color.orange)
                    .lineLimit(1)
                    .frame(maxWidth: 190, alignment: .trailing)
                    .help("\(store.networkStatus). \(store.connectionMessage)")
            }

            Button(action: { Task { await store.loadHome(force: true) } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(IconButtonStyle(palette: palette))
            .accessibilityLabel("Refresh recommendations")
            .help("Refresh recommendations")

            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(IconButtonStyle(palette: palette))
            .accessibilityLabel("YouGlass settings")
            .help("YouGlass settings")

            if !minimal {
                Picker("", selection: Binding(
                    get: { store.theme },
                    set: { newTheme in store.setTheme(newTheme) }
                )) {
                    Text(AppTheme.light.rawValue).tag(AppTheme.light)
                    Text(AppTheme.dark.rawValue).tag(AppTheme.dark)
                }
                .pickerStyle(.segmented)
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
                    AsyncAvatar(url: store.profileImageURL ?? URL(string: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=120&q=80"))
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
