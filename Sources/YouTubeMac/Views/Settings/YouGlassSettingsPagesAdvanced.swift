import SwiftUI

extension YouGlassSettingsView {
        var advancedPage: some View {
            VStack(alignment: .leading, spacing: 24) {
                settingsHeader(.advanced)

                settingsGroup("Debug engine", footer: "YouGlass keeps a bounded, privacy-safe breadcrumb trail for lifecycle, API, feed, and playback failures. Native macOS crash reports remain authoritative; exported reports never include API keys, OAuth tokens, cookies, comments, or request bodies.") {
                    Toggle("Enable diagnostic logging", isOn: $diagnosticsEnabled)
                    Toggle("Verbose request timing", isOn: $verboseDiagnostics)
                    Toggle("WebKit and playback breadcrumbs", isOn: $captureWebKitBreadcrumbs)

                    settingsValueRow(
                        "Current session",
                        value: YouGlassDebugEngine.shared.sessionSummary,
                        systemName: "waveform.path.ecg"
                    )

                    HStack(spacing: 8) {
                        Button {
                            exportDiagnostics()
                        } label: {
                            Label("Export report", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            copyDiagnostics()
                        } label: {
                            Label("Copy report", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            revealDiagnosticsFolder()
                        } label: {
                            Label("Open logs", systemImage: "folder")
                        }
                        .buttonStyle(.bordered)
                    }

                    HStack {
                        Button("Clear stored logs", role: .destructive) {
                            YouGlassDebugEngine.shared.clearPersistedDiagnostics()
                            debugStatus = "Stored diagnostic logs cleared."
                        }
                        .buttonStyle(.bordered)
                        Spacer(minLength: 0)
                    }

                    if let debugStatus {
                        Text(debugStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                settingsGroup("Diagnostics", footer: "Technical details are useful when a YouTube API request or native player surface fails. They never include API keys or OAuth secrets.") {
                    Toggle("Prefer technical error alerts", isOn: $preferTechnicalErrorAlerts)
                    settingsValueRow("Feed engine", value: "YouTube session + Data API + local ranking", systemName: "cpu")
                    settingsValueRow("Player engine", value: "Native SwiftUI surface with WebKit playback", systemName: "play.tv")
                    settingsValueRow("Thumbnail motion", value: YouGlassRuntimeStabilityPolicy.parallaxMode.rawValue, systemName: "rectangle.3.group")
                }

                settingsGroup("WebKit stability", footer: "Hidden YouTube compatibility bridges use offscreen WKWebViews for session-only feed, history, channel, comments, and live-chat fallbacks. They are disabled by default and forced off on macOS 26+ because WebKit can crash while committing an invisible remote layer tree.") {
                    Toggle("Allow hidden YouTube compatibility bridges", isOn: $hiddenWebKitCompatibility)
                        .tint(.orange)
                        .disabled(YouGlassHiddenWebKitPolicy.isForcedOffOnCurrentSystem)
                    Text(YouGlassHiddenWebKitPolicy.isForcedOffOnCurrentSystem
                        ? "Stable mode is enforced on macOS 26+. The compatibility setting is preserved but cannot start hidden WebViews on this system."
                        : hiddenWebKitCompatibility
                        ? "Compatibility bridges are enabled. Use this only when API-backed data is unavailable and you accept the additional WebKit crash risk."
                        : "Stable mode is active. YouGlass will use OAuth, the YouTube Data API, local caches, and the visible player/login WebViews only.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                settingsGroup("Account recovery", footer: "Use this when a signed-in browser session is stale or the account profile is not reflected in the app.") {
                    Button {
                        store.refreshAccount()
                        status = "Account refresh requested."
                    } label: {
                        Label("Recheck YouTube session", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.borderedProminent)

                    if let status {
                        Text(status)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }

        var aboutPage: some View {
            VStack(alignment: .leading, spacing: 24) {
                settingsHeader(.about)

                settingsGroup("YouGlass", footer: "YouGlass is a native macOS interface for your YouTube account. It uses official YouTube APIs where available and keeps the Apple-inspired presentation separate from the standard YouTube website UI.") {
                    settingsValueRow("Version", value: appVersion, systemName: "number")
                    settingsValueRow("Build", value: buildVersion, systemName: "hammer")
                    settingsValueRow("Minimum macOS", value: "14.0", systemName: "macos.window")
                }

                settingsGroup("Resources") {
                    Link(destination: URL(string: "https://developers.google.com/youtube/v3")!) {
                        Label("YouTube Data API documentation", systemImage: "book")
                    }
                    Link(destination: URL(string: "https://support.google.com/youtube")!) {
                        Label("YouTube Help", systemImage: "questionmark.circle")
                    }
                }
            }
        }
}
