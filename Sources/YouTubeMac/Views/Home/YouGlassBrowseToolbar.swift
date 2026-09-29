import SwiftUI

/// Destination actions stay independent of the scrolling content and player.
struct YouGlassBrowseToolbar: View {
    @EnvironmentObject private var store: YouTubeStore
    let palette: Palette

    var body: some View {
        YouGlassSurfaceGroup {
        GeometryReader { geometry in
            HStack(spacing: 12) {
                SearchField(text: $store.query, focusRequestID: store.searchFocusRequestID,
                            palette: palette) { store.startSearch() }
                    .frame(maxWidth: 540)
                    .layoutPriority(1)

                Spacer(minLength: 0)

                if geometry.size.width > 760 {
                    HomeConnectionStatusView(store: store, palette: palette, compact: true)
                }

                if store.refreshDestination != .unavailable {
                    Button(action: store.refreshCurrentDestination) {
                        if store.isLoading || store.customFeedLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(IconButtonStyle(palette: palette))
                    .accessibilityLabel("Refresh \(store.selectedSection)")
                    .help("Refresh \(store.selectedSection) (⌘R)")
                    .disabled(!store.canRefreshCurrentDestination)
                }

                Button(action: store.toggleCommandPalette) {
                    Image(systemName: "command")
                }
                .buttonStyle(IconButtonStyle(palette: palette))
                .accessibilityLabel("Open command palette")
                .help("Command palette (⌘K)")

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
                    SettingsLink { Text("YouGlass settings") }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 26, height: 28)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel("More browsing actions")
                .help("Appearance, custom feeds, and settings")

                Button(action: store.login) {
                    AsyncAvatar(url: store.profileImageURL)
                        .frame(width: 32, height: 32)
                        .overlay(alignment: .bottomTrailing) {
                            if store.isSignedIn {
                                Circle().fill(.green)
                                    .frame(width: 9, height: 9)
                                    .overlay(Circle().stroke(palette.window, lineWidth: 2))
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(store.isSignedIn ? "YouTube account" : "Sign in to YouTube")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(palette.text)
            .padding(.horizontal, geometry.size.width < 560 ? 12 : 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 72)
        }
    }
}
