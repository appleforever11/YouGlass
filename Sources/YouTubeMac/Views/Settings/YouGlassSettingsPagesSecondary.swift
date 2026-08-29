import SwiftUI

extension YouGlassSettingsView {
        var recommendationsPage: some View {
            VStack(alignment: .leading, spacing: 24) {
                settingsHeader(.recommendations)

                settingsGroup("Your feed", footer: "YouGlass combines the signed-in YouTube session, subscribed channels, local watch signals, and public metadata. It cannot reproduce YouTube's private ranking model exactly, but it can keep these signals aligned with your account.") {
                    settingsValueRow("Account", value: store.isSignedIn ? "Signed in" : "Sign in for account signals", systemName: "person.crop.circle")
                    settingsValueRow("Subscribed channels", value: "\(store.subscriptions.count)", systemName: "rectangle.stack.person.crop")
                    settingsValueRow("Watched on this Mac", value: "\(store.recentlyWatched.count)", systemName: "clock")
                    settingsValueRow("Saved in YouGlass", value: "\(store.savedVideos.count)", systemName: "bookmark")
                    settingsValueRow("Liked locally", value: "\(store.locallyLikedVideos.count)", systemName: "hand.thumbsup")
                    Toggle(
                        "Show Continue Watching on Home",
                        isOn: Binding(
                            get: { store.showContinueWatching },
                            set: { store.setShowContinueWatching($0) }
                        )
                    )
                }

                settingsGroup("Refresh", footer: "Refreshing asks the signed-in session and the official API for new candidates, then reranks them with your local signals.") {
                    HStack {
                        Text("Last account sync")
                        Spacer()
                        Text(store.lastAccountSyncDate?.formatted(date: .abbreviated, time: .shortened) ?? "Not synced yet")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Last feed refresh")
                        Spacer()
                        Text(store.feedLastRefreshedDate?.formatted(date: .abbreviated, time: .shortened) ?? "Not refreshed yet")
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        store.refreshAccount()
                    } label: {
                        Label(
                            store.accountSyncInProgress ? "Refreshing account and feed..." : "Refresh personalized recommendations",
                            systemImage: store.accountSyncInProgress ? "hourglass" : "wand.and.stars"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.accountSyncInProgress)
                }
            }
        }

        var playbackPage: some View {
            VStack(alignment: .leading, spacing: 24) {
                settingsHeader(.playback)

                settingsGroup("Player behavior", footer: "Native YouTube playback is hosted inside the YouGlass player surface. Audio remains controlled by the player, not by a separate browser window.") {
                    Toggle(
                        "Start videos muted",
                        isOn: Binding(
                            get: { store.autoMuteOnStart },
                            set: { store.setAutoMuteOnStart($0) }
                        )
                    )
                    Text("Mute is the safer default while you work. You can change it here or from the YouGlass menu.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                settingsGroup("Compact player", footer: "When you minimize a player inside YouGlass, it snaps to the selected corner and remains in the same app window.") {
                    Picker(
                        "Compact player position",
                        selection: Binding(
                            get: { store.compactPlayerCorner },
                            set: { store.setCompactPlayerCorner($0) }
                        )
                    ) {
                        ForEach(CompactPlayerCorner.allCases) { corner in
                            Text(corner.title).tag(corner)
                        }
                    }
                    .pickerStyle(.menu)
                }

                settingsGroup("Picture in Picture", footer: "Desktop picture in picture is available after a video is selected. YouGlass keeps the PIP playback surface separate from the main feed so it can float above other windows.") {
                    HStack {
                        Text(store.selectedVideo == nil ? "Choose a video in YouGlass first" : "Ready for the selected video")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            store.presentDesktopPIP()
                        } label: {
                            Label("Open PIP", systemImage: "pip.enter")
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.selectedVideo == nil)
                    }
                }
            }
        }

        var commentsAndChatPage: some View {
            VStack(alignment: .leading, spacing: 24) {
                settingsHeader(.commentsAndChat)

                settingsGroup("Community data", footer: "Public comments and live chat require the YouTube Data API. Posting comments and other account actions also require Google OAuth authorization.") {
                    settingsValueRow("API access", value: store.hasDataAPIKey ? "Connected" : "Add an API key", systemName: "key")
                    settingsValueRow("Google authorization", value: store.hasOAuthClientID ? "Configured" : "Not configured", systemName: "person.badge.key")
                    settingsValueRow("Live chat", value: "Loads when YouTube returns a live chat ID", systemName: "bubble.left.and.bubble.right")
                    SettingsLink {
                        Label("Open account and API settings", systemImage: "arrow.right.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }

                settingsGroup("Troubleshooting", footer: "If a video shows no comments, confirm the API key has YouTube Data API v3 enabled and that the video owner allows comments. A browser sign-in alone does not grant API access.") {
                    HStack {
                        Text(store.connectionMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Spacer()
                        Button {
                            status = "Comment and live chat access will retry the next time a player opens."
                        } label: {
                            Label("Retry on next player", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }

        var notificationsPage: some View {
            VStack(alignment: .leading, spacing: 24) {
                settingsHeader(.notifications)

                settingsGroup("Notification center", footer: "The notification bell in the main YouGlass window opens the app's notification section. This page keeps that entry point easy to find.") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("YouTube notifications")
                                .font(.headline)
                            Text("Open the native notification section to review account updates.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            store.showSection("Notifications")
                        } label: {
                            Label("Open notifications", systemImage: "bell")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                settingsGroup("Account status", footer: "Notification delivery follows the signed-in YouTube session. YouGlass does not request macOS notification permission until a notification feature is enabled.") {
                    settingsValueRow("Account", value: store.isSignedIn ? "Connected" : "Not connected", systemName: "person.crop.circle")
                    settingsValueRow("Connection", value: store.connectionMessage, systemName: "antenna.radiowaves.left.and.right")
                }
            }
        }

        var privacyPage: some View {
            VStack(alignment: .leading, spacing: 24) {
                settingsHeader(.privacy)

                settingsGroup("Local data", footer: "YouGlass stores local feed caches, watch history, saved videos, and preference values on this Mac. Cached media thumbnails remain remote and are not downloaded as video files.") {
                    settingsValueRow("Cached recommendations", value: "Stored locally for faster launch", systemName: "externaldrive")
                    HStack {
                        Text("Clear cached recommendations")
                        Spacer()
                        Button("Clear Cache", role: .destructive) {
                            showingCacheResetConfirmation = true
                        }
                        .buttonStyle(.bordered)
                    }
                }

                settingsGroup("Google connection", footer: "Resetting the connection removes credentials, tokens, cookies, and cached account-specific recommendations. It does not delete anything from your Google or YouTube account.") {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Reset YouTube sign-in data")
                                .font(.headline)
                            Text("Sign out this Mac and remove saved connection data.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Reset…", role: .destructive) {
                            showingResetConfirmation = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
}
