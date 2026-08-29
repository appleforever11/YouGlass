import SwiftUI

extension YouGlassSettingsView {
        var generalPage: some View {
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

        var appearancePage: some View {
            VStack(alignment: .leading, spacing: 24) {
                settingsHeader(.appearance)

                selectedThemeSummary

                settingsGroup("Theme controls", footer: "Every environment includes a coordinated light and dark palette. Changes apply throughout Home, channels, the player, compact windows, and Settings.") {
                    Picker("Appearance", selection: Binding(
                        get: { store.theme },
                        set: { store.setTheme($0) }
                    )) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)

                    Divider()

                    HStack(alignment: .top, spacing: 24) {
                        ThemeControlSlider(
                            title: "Background glow",
                            systemImage: "sun.max",
                            value: Binding(
                                get: { store.backgroundGlow },
                                set: { store.setBackgroundGlow($0) }
                            ),
                            range: 0.35...1.0
                        )

                        ThemeControlSlider(
                            title: "Glass tint",
                            systemImage: "circle.lefthalf.filled",
                            value: Binding(
                                get: { store.glassIntensity },
                                set: { store.setGlassIntensity($0) }
                            ),
                            range: 0.25...1.0
                        )
                    }

                    Toggle("Reduce ambient motion", isOn: $reduceAmbientMotion)
                }

                settingsGroup("Accent editor", footer: "Use a six-digit hex color to tune the selection, accent, and highlight treatment across the app. Leave it blank to use the environment default.") {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(store.themeCustomization.accentColor ?? store.visualTheme.colors(isDark: effectiveColorScheme == .dark).accent)
                            .frame(width: 24, height: 24)
                            .overlay(Circle().stroke(.quaternary, lineWidth: 1))

                        TextField("#4C8DFF", text: $accentHexDraft)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .onSubmit { store.setThemeAccentHex(accentHexDraft) }

                        Button("Apply") {
                            store.setThemeAccentHex(accentHexDraft)
                            accentHexDraft = store.themeCustomization.normalizedAccentHex ?? ""
                        }
                        .buttonStyle(.bordered)
                        .disabled(YouGlassThemeCustomization.normalizeHex(accentHexDraft) == nil)

                        Button("Reset") {
                            store.resetThemeCustomization()
                            accentHexDraft = ""
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.themeCustomization.normalizedAccentHex == nil)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Theme Center")
                            .font(.title3.weight(.bold))
                        Text("Choose an environment. Each preview shows its light and dark treatments together.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    Text("\(filteredThemeFamilies.count) of \(YouGlassThemeFamily.allCases.count) environments")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 2)

                themeBrowserControls

                if filteredThemeFamilies.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No matching environments")
                            .font(.headline)
                        Text("Try a different name or collection.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 34)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 240, maximum: 360), spacing: 16)],
                        alignment: .leading,
                        spacing: 16
                    ) {
                        ForEach(filteredThemeFamilies) { theme in
                            YouGlassThemeCard(
                                theme: theme,
                                isSelected: store.visualTheme == theme,
                                action: { store.setVisualTheme(theme) }
                            )
                        }
                    }
                }
            }
            .onAppear {
                accentHexDraft = store.themeCustomization.normalizedAccentHex ?? ""
            }
        }

        var themeBrowserControls: some View {
            HStack(spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(palette.accent)
                    Picker("Collection", selection: $themeCollection) {
                        ForEach(YouGlassThemeCollection.allCases) { collection in
                            Text(collection.title).tag(collection)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                TextField("Search environments", text: $themeQuery)
                    .textFieldStyle(.roundedBorder)
                    .overlay(alignment: .trailing) {
                        if !themeQuery.isEmpty {
                            Button {
                                themeQuery = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 7)
                            .accessibilityLabel("Clear theme search")
                        }
                    }
                    .frame(maxWidth: 280)

                Spacer(minLength: 0)

                Button {
                    let candidates = YouGlassThemeFamily.allCases.filter { $0 != store.visualTheme }
                    store.setVisualTheme(candidates.randomElement() ?? .neoCitrus)
                } label: {
                    Label("Surprise me", systemImage: "shuffle")
                }
                .buttonStyle(.bordered)
                .help("Apply a different environment")
            }
            .padding(10)
            .background(palette.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(palette.stroke, lineWidth: 1)
            }
        }

        var selectedThemeSummary: some View {
            let colors = store.visualTheme.colors(isDark: effectiveColorScheme == .dark)

            return HStack(spacing: 12) {
                SettingsIconBadge(
                    systemName: store.visualTheme.systemImage,
                    tint: colors.accent,
                    size: 42
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Current environment")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(store.visualTheme.title)
                        .font(.headline)
                    Text(store.visualTheme.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Label(
                    effectiveColorScheme == .dark ? "Dark" : "Light",
                    systemImage: effectiveColorScheme == .dark ? "moon.fill" : "sun.max.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(colors.accent)
            }
            .padding(14)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.quaternary, lineWidth: 1)
            }
        }

        var accountPage: some View {
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

        var apiKeyGroup: some View {
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

        var oauthGroup: some View {
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
}
