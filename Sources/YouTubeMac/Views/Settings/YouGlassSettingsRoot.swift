import SwiftUI

extension YouGlassSettingsView {
        var body: some View {
            ZStack {
                palette.window
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    settingsChrome

                    HStack(spacing: 0) {
                        if sidebarVisible {
                            settingsSidebar
                                .frame(minWidth: 238, idealWidth: 270, maxWidth: 310)

                            Divider()
                        }

                        YouGlassSettingsScrollView(resetID: selection ?? .general) {
                            settingsDetail
                                .frame(
                                    maxWidth: selection == .appearance ? 1_120 : 820,
                                    alignment: .topLeading
                                )
                                .padding(.horizontal, 30)
                                .padding(.top, 24)
                                .padding(.bottom, 40)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(palette.content)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(minWidth: 920, minHeight: 620)
            .background(
                YouGlassSettingsWindowConfigurator(
                    isDark: effectiveColorScheme == .dark
                )
            )
            .alert("Reset YouTube connection?", isPresented: $showingResetConfirmation) {
                Button("Reset", role: .destructive) {
                    store.resetYouTubeCredentials()
                    status = "Saved YouTube credentials and browser session removed."
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This removes the saved API key, Google OAuth token, and YouTube browser session from this Mac. You can connect again afterwards.")
            }
            .alert("Clear cached recommendations?", isPresented: $showingCacheResetConfirmation) {
                Button("Clear Cache", role: .destructive) {
                    store.clearCachedRecommendationData()
                    status = "Cached recommendation data cleared."
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This removes cached home recommendations from YouGlass. Your Google sign-in, API credentials, saved videos, and local watch history stay intact.")
            }
        }

        var settingsChrome: some View {
            HStack(spacing: 9) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        sidebarVisible.toggle()
                    }
                } label: {
                    Image(systemName: sidebarVisible ? "sidebar.leading" : "sidebar.trailing")
                        .frame(width: 26, height: 22)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(sidebarVisible ? "Hide Settings Sidebar" : "Show Settings Sidebar")
                .accessibilityLabel(sidebarVisible ? "Hide Settings Sidebar" : "Show Settings Sidebar")

                Text("Settings")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(palette.window)
            .overlay(alignment: .bottom) {
                Divider()
            }
        }

        var settingsSidebar: some View {
            List(selection: $selection) {
                Section {
                    HStack(spacing: 11) {
                        SettingsIconBadge(systemName: "play.rectangle.fill", tint: .red, size: 31)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("YouGlass")
                                .font(.headline)
                            Text("YouTube for Mac")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 5)
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 7, trailing: 8))
                    .listRowSeparator(.hidden)
                }

                settingsSidebarSection("YouGlass", pages: [.general, .appearance])
                settingsSidebarSection("YouTube", pages: [.account, .recommendations, .playback])
                settingsSidebarSection("Community", pages: [.commentsAndChat, .notifications])
                settingsSidebarSection("System", pages: [.privacy, .advanced, .about])
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(palette.sidebar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(store.isSignedIn ? Color.green : Color.secondary.opacity(0.55))
                        .frame(width: 8, height: 8)
                    Text(store.isSignedIn ? "YouTube account connected" : "YouTube account not connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(palette.sidebar)
            }
        }

        @ViewBuilder
        func settingsSidebarSection(_ title: String, pages: [YouGlassSettingsPage]) -> some View {
            Section(title) {
                ForEach(pages) { page in
                    HStack(spacing: 10) {
                        SettingsIconBadge(systemName: page.systemName, tint: page.tint, size: 29)
                        Text(page.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .tag(page)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(page.title)
                }
            }
        }

        @ViewBuilder
        var settingsDetail: some View {
            switch selection ?? .general {
            case .general:
                generalPage
            case .appearance:
                appearancePage
            case .account:
                accountPage
            case .recommendations:
                recommendationsPage
            case .playback:
                playbackPage
            case .commentsAndChat:
                commentsAndChatPage
            case .notifications:
                notificationsPage
            case .privacy:
                privacyPage
            case .advanced:
                advancedPage
            case .about:
                aboutPage
            }
        }
}
