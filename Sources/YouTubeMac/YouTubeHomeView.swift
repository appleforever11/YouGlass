import SwiftUI

struct YouTubeHomeView: View {
    @EnvironmentObject private var store: YouTubeStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var compactDragOffset: CGSize = .zero

    private var palette: Palette { Palette(colorScheme) }

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

                    if let message = store.sectionEmptyMessage {
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
                        HeroSection(palette: palette, compact: compact)

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

            Spacer(minLength: minimal ? 4 : (compact ? 6 : 12))

            if minimal {
                EmptyView()
            } else if compact {
                Image(systemName: store.isSignedIn ? "checkmark.circle.fill" : "icloud.slash")
                    .foregroundStyle(store.isSignedIn ? Color.green : palette.secondaryText)
                    .accessibilityLabel(store.connectionMessage)
                    .help(store.connectionMessage)
            } else {
                Text(store.connectionMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(store.connectionMessage.contains("signed-in") ? Color.green : palette.secondaryText)
                    .lineLimit(1)
                    .frame(maxWidth: 190, alignment: .trailing)
                    .help(store.connectionMessage)
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

private struct SearchContentView: View {
    @ObservedObject var store: YouTubeStore
    let palette: Palette
    let compact: Bool

    var body: some View {
        searchContent
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
    }

    private var searchContent: AnyView {
        if store.isLoading {
            return AnyView(ProgressView("Searching YouTube..."))
        }

        if !store.searchResults.isEmpty {
            return AnyView(
                VideoRow(
                    title: "Search results",
                    videos: store.searchResults,
                    palette: palette,
                    compact: compact,
                    showsSeeAll: false
                )
                .environmentObject(store)
            )
        }

        if let message = store.sectionEmptyMessage {
            return AnyView(SearchEmptyStateView(message: message))
        }

        return AnyView(EmptyView())
    }
}

private struct SearchEmptyStateView: View {
    let message: String

    var body: some View {
        Text(message)
    }
}

struct LiquidBackground: View {
    let palette: Palette
    let ambientPalette: VideoAmbientPalette
    @State private var animationPhase = 0.0

    var body: some View {
        GeometryReader { geometry in
            let time = animationPhase * (Double.pi * 2)
            let energy = min(max(ambientPalette.energy, 0.18), 1.0)
            let glow = 0.90 + energy * 0.24
            let drift = 0.045 + energy * 0.080
            let breathing = 0.78 + 0.20 * ((sin(time * 0.42) + 1) * 0.5) + energy * 0.04
            let secondaryBreathing = 0.76 + 0.22 * ((cos(time * 0.34 + 1.2) + 1) * 0.5)
            let width = max(geometry.size.width, 1)
            let height = max(geometry.size.height, 1)
            let radius = max(width, height) * 0.86
            let primaryCenter = UnitPoint(
                x: 0.10 + sin(time * 0.16) * drift,
                y: 0.12 + cos(time * 0.13) * drift
            )
            let secondaryCenter = UnitPoint(
                x: 0.88 + cos(time * 0.12) * drift,
                y: 0.84 + sin(time * 0.15) * drift
            )
            let accentCenter = UnitPoint(
                x: 0.52 + sin(time * 0.10 + 1.4) * drift * 0.8,
                y: 0.48 + cos(time * 0.14 + 0.7) * drift * 0.8
            )

            ZStack {
                palette.isDark ? Color.black : palette.window

                // Broad fields keep the video present as a restrained glow
                // while the black base stays dominant. Their centers move
                // slowly so the color feels alive without distracting from
                // the watch surface.
                RadialGradient(
                    colors: [
                        ambientPalette.primary.color.opacity((palette.isDark ? 0.23 : 0.15) * breathing * glow),
                        ambientPalette.primary.color.opacity((palette.isDark ? 0.052 : 0.036) * breathing * glow),
                        .clear
                    ],
                    center: primaryCenter,
                    startRadius: 0,
                    endRadius: radius
                )

                RadialGradient(
                    colors: [
                        ambientPalette.secondary.color.opacity((palette.isDark ? 0.18 : 0.12) * secondaryBreathing * glow),
                        ambientPalette.secondary.color.opacity((palette.isDark ? 0.042 : 0.030) * secondaryBreathing * glow),
                        .clear
                    ],
                    center: secondaryCenter,
                    startRadius: 0,
                    endRadius: radius * 0.92
                )

                RadialGradient(
                    colors: [
                        ambientPalette.accent.color.opacity((palette.isDark ? 0.14 : 0.09) * (0.86 + breathing * 0.14) * glow),
                        .clear
                    ],
                    center: accentCenter,
                    startRadius: 0,
                    endRadius: radius * 0.72
                )

                AngularGradient(
                    colors: [
                        ambientPalette.primary.color.opacity(0.024 * glow),
                        ambientPalette.accent.color.opacity(0.036 * glow),
                        ambientPalette.secondary.color.opacity(0.030 * glow),
                        ambientPalette.primary.color.opacity(0.024 * glow)
                    ],
                    center: .center
                )
                .opacity(palette.isDark ? 0.9 : 0.5)
            }
            .animation(.easeInOut(duration: 2.4), value: ambientPalette)
        }
        .onAppear {
            animationPhase = 1
        }
        .animation(.easeInOut(duration: 18).repeatForever(autoreverses: true), value: animationPhase)
        .allowsHitTesting(false)
    }
}

struct SidebarView: View {
    @EnvironmentObject private var store: YouTubeStore
    let palette: Palette
    let compact: Bool

    private let topItems: [(String, String, Bool, String, String?)] = [
        ("house.fill", "Home", false, "Home", nil),
        ("safari", "Explore", false, "Explore", "trending technology"),
        ("play.rectangle", "Subscriptions", false, "Subscriptions", "latest from subscribed channels"),
        ("play.square.stack", "Shorts", false, "Shorts", "youtube shorts")
    ]
    private let libraryItems: [(String, String, Bool, String, String?)] = [
        ("rectangle.stack", "Library", false, "Library", nil),
        ("list.bullet.rectangle", "Playlists", false, "Playlists", nil),
        ("clock.arrow.circlepath", "History", false, "History", nil),
        ("bookmark", "Watch Later", false, "Watch Later", nil),
        ("heart", "Liked Videos", false, "Liked Videos", nil)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                Task { @MainActor in store.showSection("Home") }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 20, weight: .semibold))
                    if !compact {
                        Text("YouTube")
                            .font(.system(size: 21, weight: .bold))
                        Text("Premium")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(palette.tertiaryText)
                            .padding(.top, 6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: compact ? .center : .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, compact ? 12 : 22)
            .padding(.top, compact ? 22 : 28)
            .padding(.bottom, compact ? 24 : 34)

            SidebarGroup(items: topItems, palette: palette, compact: compact)
            DividerLine(palette: palette)
            SidebarGroup(items: libraryItems, palette: palette, compact: compact)
            DividerLine(palette: palette)

            if !compact {
                Text("Subscriptions")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 22)
                    .padding(.bottom, 14)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 11) {
                    ForEach(store.sidebarSubscriptionsSnapshot) { item in
                        Button {
                            Task { @MainActor in store.openChannel(item) }
                        } label: {
                            HStack(spacing: 12) {
                                AsyncAvatar(url: item.avatarURL)
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        if item.avatarURL == nil {
                                            Text(String(item.name.prefix(2)))
                                                .font(.system(size: 9, weight: .heavy))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                if !compact {
                                    Text(item.name)
                                        .font(.system(size: 13))
                                        .lineLimit(1)
                                    Spacer()
                                }
                                if item.isLive {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 5, height: 5)
                                }
                            }
                            .foregroundStyle(palette.text)
                            .frame(maxWidth: .infinity, alignment: compact ? .center : .leading)
                            .padding(.horizontal, compact ? 12 : 22)
                        }
                        .buttonStyle(.plain)
                    }

                    if store.sidebarSubscriptionsSnapshot.isEmpty {
                        Button {
                            Task { @MainActor in
                                if store.sidebarIsSignedInSnapshot {
                                    store.refreshAccount()
                                } else {
                                    store.login()
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: store.sidebarIsSignedInSnapshot ? "arrow.clockwise" : "person.crop.circle.badge.plus")
                                    .frame(width: 28)
                                if !compact {
                                    Text(store.sidebarIsSignedInSnapshot ? "Refresh account subscriptions" : "Sign in to load subscriptions")
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                            }
                            .foregroundStyle(palette.secondaryText)
                            .frame(maxWidth: .infinity, alignment: compact ? .center : .leading)
                            .padding(.horizontal, compact ? 12 : 22)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: compact ? 250 : 320)

            Button {
                Task { @MainActor in store.showSection("Subscriptions") }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "chevron.down")
                    if !compact {
                        Text("Show More")
                    }
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(palette.secondaryText)
            .padding(.horizontal, compact ? 26 : 27)
            .padding(.top, compact ? 16 : 24)

            Spacer()
        }
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [
                        palette.purple.opacity(palette.isDark ? 0.14 : 0.08),
                        .clear,
                        palette.pink.opacity(palette.isDark ? 0.08 : 0.045)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(palette.hairline)
                .frame(width: 1)
        }
    }
}

private struct PlaylistLibraryView: View {
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

private struct PlaylistDetailView: View {
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

private struct PlaylistCard: View {
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

struct SidebarGroup: View {
    @EnvironmentObject private var store: YouTubeStore
    let items: [(String, String, Bool, String, String?)]
    let palette: Palette
    let compact: Bool

    var body: some View {
        VStack(spacing: 7) {
            ForEach(items, id: \.1) { symbol, title, selected, section, query in
                let active = selected || store.selectedSection == title
                Button(action: { store.showSection(section, query: query) }) {
                    HStack(spacing: 13) {
                        Image(systemName: symbol)
                            .font(.system(size: 18, weight: active ? .bold : .regular))
                            .frame(width: 20)
                        if !compact {
                            Text(title)
                                .font(.system(size: 14, weight: active ? .semibold : .regular))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                            Spacer()
                        }
                    }
                .foregroundStyle(palette.text)
                .frame(maxWidth: .infinity, alignment: compact ? .center : .leading)
                .padding(.horizontal, compact ? 8 : 14)
                .frame(height: 42)
                    .background(active ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.clear))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(active ? palette.stroke : .clear, lineWidth: 1)
                    }
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(active ? palette.accent : .clear)
                            .frame(width: 3, height: 22)
                            .padding(.leading, 4)
                    }
                }
                .buttonStyle(.plain)
                .help(title)
            }
        }
        .padding(.horizontal, compact ? 8 : 22)
    }
}

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

                        Button(action: { store.open(store.feed.hero) }) {
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
                        Button(action: { store.open(video) }) {
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

    var body: some View {
        Button(action: { store.open(video) }) {
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
        .scaleEffect(1.0)
    }
}

struct CompactVideoCard: View {
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
    }
}

struct SearchField: View {
    @Binding var text: String
    let palette: Palette
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Search videos, channels, topics...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .onSubmit(onSubmit)
                .accessibilityLabel("Search YouTube")

            Button(action: onSubmit) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .medium))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Search")
        }
        .padding(.horizontal, 20)
        .frame(height: 42)
        .background(.thinMaterial)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .fill(palette.accent.opacity(palette.isDark ? 0.025 : 0.014))
                .allowsHitTesting(false)
        }
        .overlay {
            Capsule()
                .stroke(palette.stroke, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

struct RemoteImage: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                LinearGradient(colors: [.gray.opacity(0.25), .gray.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .empty:
                Rectangle().fill(.gray.opacity(0.15))
            @unknown default:
                Rectangle().fill(.gray.opacity(0.15))
            }
        }
    }
}

/// Keeps every video preview at a deterministic 16:9 size while its remote
/// image moves through loading, success, or failure states.
struct YouGlassVideoPreview<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .clipped()
    }
}

struct AsyncAvatar: View {
    let url: URL?

    var body: some View {
        RemoteImage(url: url)
            .background(
                LinearGradient(colors: [.red, .orange, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Circle())
    }
}

struct DividerLine: View {
    let palette: Palette

    var body: some View {
        Rectangle()
            .fill(palette.hairline)
            .frame(height: 1)
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
    }
}

struct IconButtonStyle: ButtonStyle {
    let palette: Palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(palette.text)
            .frame(width: 34, height: 34)
            .background(configuration.isPressed ? palette.selected : .clear)
            .clipShape(Circle())
    }
}

struct Palette {
    let isDark: Bool

    init(_ scheme: ColorScheme) {
        isDark = scheme == .dark
    }

    var window: Color { isDark ? Color(red: 0.008, green: 0.006, blue: 0.016) : Color(red: 0.95, green: 0.93, blue: 0.96) }
    var sidebar: Color { isDark ? Color(red: 0.018, green: 0.012, blue: 0.038) : Color(red: 0.975, green: 0.95, blue: 0.98) }
    var content: Color { isDark ? Color(red: 0.014, green: 0.008, blue: 0.028) : Color(red: 0.99, green: 0.97, blue: 0.99) }
    var card: Color { isDark ? Color(red: 0.035, green: 0.018, blue: 0.060) : Color(red: 0.96, green: 0.94, blue: 0.98) }
    var queueCard: Color { isDark ? Color.white.opacity(0.034) : .white.opacity(0.60) }
    var search: Color { isDark ? Color.white.opacity(0.055) : Color.black.opacity(0.028) }
    var selected: Color { isDark ? Color(red: 0.28, green: 0.08, blue: 0.25).opacity(0.52) : Color(red: 0.90, green: 0.75, blue: 0.91).opacity(0.48) }
    var pill: Color { isDark ? Color.white.opacity(0.042) : .white.opacity(0.64) }
    var stroke: Color { isDark ? Color(red: 0.96, green: 0.26, blue: 0.72).opacity(0.20) : Color(red: 0.58, green: 0.20, blue: 0.58).opacity(0.16) }
    var hairline: Color { isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.07) }
    var text: Color { isDark ? .white : .black }
    var secondaryText: Color { isDark ? Color.white.opacity(0.62) : Color.black.opacity(0.58) }
    var tertiaryText: Color { isDark ? Color.white.opacity(0.38) : Color.black.opacity(0.36) }
    var pink: Color { isDark ? Color(red: 0.98, green: 0.16, blue: 0.64) : Color(red: 0.80, green: 0.06, blue: 0.44) }
    var purple: Color { isDark ? Color(red: 0.62, green: 0.24, blue: 1.0) : Color(red: 0.44, green: 0.12, blue: 0.78) }
    var violet: Color { isDark ? Color(red: 0.30, green: 0.18, blue: 0.98) : Color(red: 0.24, green: 0.10, blue: 0.64) }
    var accent: Color { isDark ? Color(red: 0.50, green: 0.56, blue: 1.0) : Color(red: 0.20, green: 0.30, blue: 0.82) }
    var playButton: Color { isDark ? .white : .white }
    var playText: Color { .black }
}
