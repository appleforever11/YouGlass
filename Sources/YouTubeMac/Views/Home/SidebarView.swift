import AppKit
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: YouTubeStore
    let palette: Palette
    let compact: Bool

    private let topItems: [(String, String, Bool, String, String?)] = [
        ("house.fill", "Home", false, "Home", nil),
        ("safari", "Explore", false, "Explore", nil),
        ("play.rectangle", "Subscriptions", false, "Subscriptions", nil)
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
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: compact ? 30 : 32, height: compact ? 30 : 32)
                    if !compact {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("YouGlass")
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                            Text("YouTube for Mac")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(palette.tertiaryText)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: compact ? .center : .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("YouGlass Home")
            .help("Go to Home")
            .padding(.horizontal, compact ? 12 : 22)
            .padding(.top, 20)
            .padding(.bottom, 22)

            SidebarGroup(items: topItems, palette: palette, compact: compact)
            DividerLine(palette: palette)
            SidebarGroup(items: libraryItems, palette: palette, compact: compact)
            DividerLine(palette: palette)

            if !compact {
                HStack {
                    Text("Subscriptions")
                    Spacer()
                    Button { store.editSubscriptionGroup() } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .buttonStyle(.plain)
                    .help("Create subscription group")
                    .accessibilityLabel("Create subscription group")
                    .disabled(store.sidebarSubscriptionGroupsSnapshot.count >= SubscriptionGroup.maximumGroups)
                }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 14)
            }

            ScrollView(.vertical, showsIndicators: false) {
                // Keep the sidebar responsive for accounts with a large
                // subscription list. A regular VStack constructs every row
                // and starts every avatar load even though this viewport only
                // exposes a small subset at once.
                LazyVStack(spacing: 8) {
                    SubscriptionGroupSidebar(palette: palette, compact: compact)
                    ForEach(store.sidebarSubscriptionsSnapshot) { item in
                        SidebarSubscriptionRow(
                            item: item,
                            palette: palette,
                            compact: compact
                        ) {
                            Task { @MainActor in store.openChannel(item) }
                        }
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
            .frame(minHeight: 60, maxHeight: .infinity)

            Button {
                Task { @MainActor in store.showSection("Subscriptions") }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.2")
                    if !compact {
                        Text("All subscriptions")
                    }
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(palette.secondaryText)
            .padding(.horizontal, compact ? 26 : 27)
            .padding(.vertical, 16)
            .accessibilityLabel("All subscriptions")
            .help("Browse all subscribed channels")
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
