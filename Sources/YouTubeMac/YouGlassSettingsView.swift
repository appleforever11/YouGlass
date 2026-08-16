import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Native preferences for YouGlass. The settings scene is intentionally a
/// sidebar-detail layout so account, playback, and API controls stay
/// discoverable without turning the main YouTube surface into a settings form.
struct YouGlassSettingsView: View {
    @EnvironmentObject private var store: YouTubeStore
    @State private var sidebarVisible = true
    @State private var selection: YouGlassSettingsPage? = .general
    @State private var apiKey = ""
    @State private var clientID = ""
    @State private var clientSecret = ""
    @State private var status: String?
    @State private var authorizing = false
    @State private var showingResetConfirmation = false
    @State private var showingCacheResetConfirmation = false
    @State private var debugStatus: String?
    @AppStorage(YouGlassVisualDefaults.reduceAmbientMotion) private var reduceAmbientMotion = false
    @AppStorage("YouGlass.preferTechnicalErrorAlerts") private var preferTechnicalErrorAlerts = false
    @AppStorage(YouGlassDebugEngine.diagnosticsEnabledKey) private var diagnosticsEnabled = false
    @AppStorage(YouGlassDebugEngine.verboseLoggingKey) private var verboseDiagnostics = false
    @AppStorage(YouGlassDebugEngine.webKitBreadcrumbsKey) private var captureWebKitBreadcrumbs = false
    @AppStorage(YouGlassHiddenWebKitPolicy.enabledKey) private var hiddenWebKitCompatibility = false

    var body: some View {
        VStack(spacing: 0) {
            settingsChrome

            HStack(spacing: 0) {
                if sidebarVisible {
                    settingsSidebar
                        .frame(minWidth: 238, idealWidth: 270, maxWidth: 310)

                    Divider()
                }

                YouGlassSettingsScrollView {
                    settingsDetail
                        .frame(maxWidth: 820, alignment: .topLeading)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 24)
                }
                .background(.regularMaterial)
            }
        }
        .frame(minWidth: 920, minHeight: 620)
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

    private var settingsChrome: some View {
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
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var settingsSidebar: some View {
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
            .background(.bar)
        }
    }

    @ViewBuilder
    private func settingsSidebarSection(_ title: String, pages: [YouGlassSettingsPage]) -> some View {
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
    private var settingsDetail: some View {
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

    private var generalPage: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsHeader(.general)

            settingsGroup("Connection", footer: "YouGlass keeps account tokens and API credentials in the macOS Keychain. A normal browser login is used only to establish the YouTube session.") {
                settingsValueRow("Account", value: store.isSignedIn ? "Connected" : "Not connected", systemName: store.isSignedIn ? "checkmark.circle.fill" : "person.crop.circle")
                settingsValueRow("Feed status", value: store.connectionMessage, systemName: "bolt.horizontal.circle")
                settingsValueRow(
                    "Account refresh",
                    value: store.accountSyncInProgress
                        ? "Refreshing account and feed..."
                        : (store.accountSyncStatus ?? "Ready to refresh"),
                    systemName: store.accountSyncInProgress ? "arrow.triangle.2.circlepath" : "checkmark.circle"
                )
                HStack {
                    Spacer()
                    Button {
                        store.refreshAccount()
                    } label: {
                        Label(
                            store.accountSyncInProgress ? "Refreshing..." : "Refresh account and feed",
                            systemImage: store.accountSyncInProgress ? "hourglass" : "arrow.clockwise"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.accountSyncInProgress)
                }
            }

            settingsGroup("This Mac", footer: "YouGlass is a native macOS client. Videos, comments, live chat, and picture in picture stay inside the app experience whenever YouTube makes that data available.") {
                settingsValueRow("App version", value: appVersion, systemName: "macwindow")
                settingsValueRow("Platform", value: "macOS", systemName: "desktopcomputer")
            }
        }
    }

    private var appearancePage: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsHeader(.appearance)

            settingsGroup("Color mode", footer: "The selected appearance is saved and restored the next time YouGlass opens.") {
                Picker("Theme", selection: Binding(
                    get: { store.theme },
                    set: { store.setTheme($0) }
                )) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }

            settingsGroup("Ambient glass", footer: "Reduce motion keeps the glass styling but pauses the breathing pink and purple background animation.") {
                Toggle("Reduce ambient motion", isOn: $reduceAmbientMotion)
            }
        }
    }

    private var accountPage: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsHeader(.account)

            settingsGroup("Google account", footer: accountSyncDescription) {
                HStack(spacing: 12) {
                    if let profileImageURL = store.profileImageURL {
                        AsyncAvatar(url: profileImageURL)
                            .frame(width: 46, height: 46)
                    } else {
                        SettingsIconBadge(systemName: "person.crop.circle.fill", tint: .blue, size: 46)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.isSignedIn ? "Signed in to YouTube" : "Sign in to YouTube")
                            .font(.headline)
                        Text(store.isSignedIn ? "Your profile, subscriptions, and account-aware feed can sync." : "Use the profile button in the main app to open Google sign-in.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Button("Refresh") {
                        store.refreshAccount()
                    }
                    .buttonStyle(.bordered)
                }
            }

            apiKeyGroup
            oauthGroup

            Text("The YouTube Data API key reads public metadata. OAuth is required for private account data and actions such as posting comments. The client secret is not bundled into the app.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var apiKeyGroup: some View {
        settingsGroup("YouTube Data API", footer: "A key enables public metadata such as comments, live status, ratings, and channel details. Keep quota limits in mind when refreshing frequently.") {
            SecureField("Paste YouTube Data API key", text: $apiKey)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Image(systemName: store.hasDataAPIKey ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(store.hasDataAPIKey ? .green : .secondary)
                Text(store.hasDataAPIKey ? "API key saved in Keychain" : "No API key saved")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Save API key") {
                    store.saveDataAPIKey(apiKey)
                    apiKey = ""
                    status = "YouTube Data API key saved."
                }
                .buttonStyle(.bordered)
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var oauthGroup: some View {
        settingsGroup("Google OAuth", footer: "OAuth is the account-level connection used for subscriptions, private feed signals, comments, likes, and live chat access when your Google project allows those scopes.") {
            TextField("Installed-app OAuth client ID", text: $clientID)
                .textFieldStyle(.roundedBorder)

            credentialStatusRow(
                store.hasOAuthClientID,
                savedText: "OAuth client ID saved in Keychain",
                emptyText: "No OAuth client ID saved"
            ) {
                Button("Save client ID") {
                    store.saveOAuthClientID(clientID)
                    clientID = ""
                    status = "Google OAuth client ID saved."
                }
                .buttonStyle(.bordered)
                .disabled(clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            SecureField("Installed-app OAuth client secret", text: $clientSecret)
                .textFieldStyle(.roundedBorder)

            credentialStatusRow(
                store.hasOAuthClientSecret,
                savedText: "OAuth client secret saved in Keychain",
                emptyText: "No OAuth client secret saved"
            ) {
                Button("Save client secret") {
                    store.saveOAuthClientSecret(clientSecret)
                    clientSecret = ""
                    status = "Google OAuth client secret saved."
                }
                .buttonStyle(.bordered)
                .disabled(clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack {
                Button {
                    authorizeComments()
                } label: {
                    Label(authorizing ? "Waiting for Google..." : "Connect Google for account actions", systemImage: "person.badge.key.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(authorizing || !store.hasOAuthClientID || !store.hasOAuthClientSecret)

                if let status {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }

    private var recommendationsPage: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsHeader(.recommendations)

            settingsGroup("Your feed", footer: "YouGlass combines the signed-in YouTube session, subscribed channels, local watch signals, and public metadata. It cannot reproduce YouTube's private ranking model exactly, but it can keep these signals aligned with your account.") {
                settingsValueRow("Account", value: store.isSignedIn ? "Signed in" : "Sign in for account signals", systemName: "person.crop.circle")
                settingsValueRow("Subscribed channels", value: "\(store.subscriptions.count)", systemName: "rectangle.stack.person.crop")
                settingsValueRow("Watched on this Mac", value: "\(store.recentlyWatched.count)", systemName: "clock")
                settingsValueRow("Saved in YouGlass", value: "\(store.savedVideos.count)", systemName: "bookmark")
                settingsValueRow("Liked locally", value: "\(store.locallyLikedVideos.count)", systemName: "hand.thumbsup")
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

    private var playbackPage: some View {
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

    private var commentsAndChatPage: some View {
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

    private var notificationsPage: some View {
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

    private var privacyPage: some View {
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

    private var advancedPage: some View {
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
            }

            settingsGroup("WebKit stability", footer: "Hidden YouTube compatibility bridges use offscreen WKWebViews for session-only feed, history, channel, comments, and live-chat fallbacks. They are disabled by default because WebKit can crash while committing an invisible remote layer tree. Restart YouGlass after changing this setting.") {
                Toggle("Allow hidden YouTube compatibility bridges", isOn: $hiddenWebKitCompatibility)
                    .tint(.orange)
                Text(hiddenWebKitCompatibility
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

    private var aboutPage: some View {
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

    @ViewBuilder
    private func settingsHeader(_ page: YouGlassSettingsPage) -> some View {
        HStack(spacing: 14) {
            SettingsIconBadge(systemName: page.systemName, tint: page.tint, size: 68)
            VStack(alignment: .leading, spacing: 4) {
                Text(page.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(page.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private func settingsGroup<Content: View>(
        _ title: String,
        footer: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        YouGlassSettingsGroup(title: title, footer: footer, content: content)
    }

    private func settingsValueRow(_ title: String, value: String, systemName: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemName)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(title)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }

    private func credentialStatusRow<Content: View>(
        _ saved: Bool,
        savedText: String,
        emptyText: String,
        @ViewBuilder action: @escaping () -> Content
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: saved ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(saved ? .green : .secondary)
            Text(saved ? savedText : emptyText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            action()
        }
    }

    private var accountSyncDescription: String {
        guard store.isSignedIn else {
            return "Sign in from the profile button, then refresh to load your real subscriptions and account-aware feed."
        }
        guard let date = store.lastAccountSyncDate else {
            return "Your account is connected. Subscription and recommendation data has not finished syncing yet."
        }
        return "Last account sync: \(date.formatted(date: .abbreviated, time: .shortened))."
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var buildVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "100000"
    }

    private func authorizeComments() {
        guard !authorizing else { return }
        authorizing = true
        status = "Opening Google authorization..."
        Task { @MainActor in
            let authorized = await store.authorizeYouTubeComments()
            authorizing = false
            status = authorized
                ? "Google account actions are ready."
                : store.connectionMessage
        }
    }

    private func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.title = "Export YouGlass Diagnostics"
        panel.nameFieldStringValue = "YouGlass-Diagnostics-\(Self.debugFilenameTimestamp()).json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try YouGlassDebugEngine.shared.exportDiagnostics(to: url)
            debugStatus = "Diagnostics exported to \(url.lastPathComponent)."
        } catch {
            debugStatus = "Diagnostics export failed: \(error.localizedDescription)"
            YouGlassDiagnostics.record(
                .error,
                category: "debug-engine",
                message: "Diagnostics export failed",
                metadata: ["error": error.localizedDescription]
            )
        }
    }

    private func copyDiagnostics() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(
            YouGlassDebugEngine.shared.makeTextReport(),
            forType: .string
        )
        debugStatus = "Diagnostics copied to the clipboard."
    }

    private func revealDiagnosticsFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([
            YouGlassDebugEngine.shared.diagnosticsDirectoryURL
        ])
        debugStatus = "Opened the local diagnostics folder."
    }

    private static func debugFilenameTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

/// SwiftUI's private HostingScrollView crashes in its hit-test responder path
/// on the macOS 27 beta. Keep settings scrollable while routing the container
/// through AppKit's mature NSScrollView implementation.
@MainActor
private struct YouGlassSettingsScrollView<Content: View>: NSViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(content: content)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = context.coordinator.hostingView
        context.coordinator.scheduleInitialScrollToTop(in: scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.hostingView.rootView = content
        context.coordinator.hostingView.needsLayout = true
        context.coordinator.resizeDocument(to: scrollView.contentSize.width)
        context.coordinator.scheduleInitialScrollToTop(in: scrollView)
    }

    @MainActor
    final class Coordinator {
        let hostingView: NSHostingView<Content>
        // The settings window can receive several layout updates while it is
        // becoming visible. Keep the first presentation at the top until the
        // document height has settled, then leave scrolling entirely to the user.
        private var initialScrollPassesRemaining = 6
        private var initialScrollScheduled = false

        init(content: Content) {
            hostingView = NSHostingView(rootView: content)
            hostingView.autoresizingMask = [.width]
        }

        func resizeDocument(to width: CGFloat) {
            guard width > 0 else { return }
            hostingView.frame.size.width = width
            hostingView.layoutSubtreeIfNeeded()
            hostingView.frame.size.height = max(hostingView.fittingSize.height, 1)
        }

        func scheduleInitialScrollToTop(in scrollView: NSScrollView) {
            guard initialScrollPassesRemaining > 0, !initialScrollScheduled else { return }
            initialScrollScheduled = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self, weak scrollView] in
                guard let self, let scrollView else { return }
                self.initialScrollScheduled = false
                self.hostingView.layoutSubtreeIfNeeded()
                self.resizeDocument(to: scrollView.contentSize.width)
                self.scrollToTop(in: scrollView)
                scrollView.reflectScrolledClipView(scrollView.contentView)

                self.initialScrollPassesRemaining -= 1
                if self.initialScrollPassesRemaining > 0 {
                    self.scheduleInitialScrollToTop(in: scrollView)
                }
            }
        }

        private func scrollToTop(in scrollView: NSScrollView) {
            let documentView = scrollView.documentView
            let topY: CGFloat

            if documentView?.isFlipped ?? true {
                topY = 0
            } else {
                let documentHeight = documentView?.bounds.height ?? 0
                topY = max(0, documentHeight - scrollView.contentView.bounds.height)
            }

            scrollView.contentView.scroll(to: NSPoint(x: 0, y: topY))
        }
    }
}

private enum YouGlassSettingsPage: String, CaseIterable, Identifiable, Hashable {
    case general
    case appearance
    case account
    case recommendations
    case playback
    case commentsAndChat
    case notifications
    case privacy
    case advanced
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .account: "Account & API"
        case .recommendations: "Recommendations"
        case .playback: "Playback"
        case .commentsAndChat: "Comments & Chat"
        case .notifications: "Notifications"
        case .privacy: "Privacy & Data"
        case .advanced: "Advanced"
        case .about: "About & Help"
        }
    }

    var subtitle: String {
        switch self {
        case .general: "Connection, app identity, and this Mac."
        case .appearance: "Theme, ambient glass, and motion."
        case .account: "Google sign-in, API access, and credentials."
        case .recommendations: "Account signals and personalized feed refresh."
        case .playback: "Mute behavior, compact player, and PIP."
        case .commentsAndChat: "Comments, live chat, and community access."
        case .notifications: "YouTube notification center and account status."
        case .privacy: "Cached data, credentials, and local storage."
        case .advanced: "Diagnostics and account recovery tools."
        case .about: "Version details and useful resources."
        }
    }

    var systemName: String {
        switch self {
        case .general: "gearshape.fill"
        case .appearance: "paintbrush.pointed.fill"
        case .account: "person.crop.circle.fill"
        case .recommendations: "wand.and.stars"
        case .playback: "play.circle.fill"
        case .commentsAndChat: "bubble.left.and.bubble.right.fill"
        case .notifications: "bell.fill"
        case .privacy: "lock.fill"
        case .advanced: "slider.horizontal.3"
        case .about: "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .general: .gray
        case .appearance: .purple
        case .account: .blue
        case .recommendations: .pink
        case .playback: .indigo
        case .commentsAndChat: .cyan
        case .notifications: .red
        case .privacy: .green
        case .advanced: .orange
        case .about: .pink
        }
    }
}

private struct SettingsIconBadge: View {
    let systemName: String
    let tint: Color
    let size: CGFloat

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .shadow(color: tint.opacity(0.24), radius: 5, y: 2)
    }
}

private struct YouGlassSettingsGroup<Content: View>: View {
    let title: String
    let footer: String?
    let content: () -> Content

    init(title: String, footer: String?, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.bold))
                .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.quaternary, lineWidth: 1)
            }

            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }
        }
    }
}
