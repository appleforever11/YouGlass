import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: YouTubeStore
    let palette: Palette
    let compact: Bool

    private let topItems: [(String, String, Bool, String, String?)] = [
        ("house.fill", "Home", false, "Home", nil),
        ("safari", "Explore", false, "Explore", "trending technology"),
        ("play.rectangle", "Subscriptions", false, "Subscriptions", "latest from subscribed channels")
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
                // Keep the sidebar responsive for accounts with a large
                // subscription list. A regular VStack constructs every row
                // and starts every avatar load even though this viewport only
                // exposes a small subset at once.
                LazyVStack(spacing: 11) {
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
