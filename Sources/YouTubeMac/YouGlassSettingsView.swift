import SwiftUI

struct YouGlassSettingsView: View {
    @EnvironmentObject private var store: YouTubeStore
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var clientID = ""
    @State private var clientSecret = ""
    @State private var status: String?
    @State private var authorizing = false
    @State private var showingResetConfirmation = false
    @AppStorage(YouGlassVisualDefaults.reduceAmbientMotion) private var reduceAmbientMotion = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("YouGlass Settings")
                        .font(.system(size: 20, weight: .bold))
                    Text("Connect official YouTube API access for comments, ratings, subscriptions, and live chat.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
            }

            GroupBox("Playback") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(
                        "Start videos muted",
                        isOn: Binding(
                            get: { store.autoMuteOnStart },
                            set: { value in store.setAutoMuteOnStart(value) }
                        )
                    )
                    Text("When disabled, YouGlass requests audio playback and the player opens with sound on. You can still mute any video from the transient player controls.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Picker(
                        "Compact player position",
                        selection: Binding(
                            get: { store.compactPlayerCorner },
                            set: { corner in store.setCompactPlayerCorner(corner) }
                        )
                    ) {
                        ForEach(CompactPlayerCorner.allCases) { corner in
                            Text(corner.title).tag(corner)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.top, 4)
            }

            GroupBox("Appearance") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker(
                        "Theme",
                        selection: Binding(
                            get: { store.theme },
                            set: { newTheme in store.setTheme(newTheme) }
                        )
                    ) {
                        Text(AppTheme.light.rawValue).tag(AppTheme.light)
                        Text(AppTheme.dark.rawValue).tag(AppTheme.dark)
                    }
                    .pickerStyle(.segmented)

                    Toggle("Reduce ambient motion", isOn: $reduceAmbientMotion)
                    Text("Pause the breathing pink and purple ambience while keeping the glass styling active.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }

            GroupBox("YouTube account") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: store.isSignedIn ? "person.crop.circle.fill.badge.checkmark" : "person.crop.circle")
                            .foregroundStyle(store.isSignedIn ? .green : .secondary)
                        Text(store.isSignedIn ? "Signed in to YouTube" : "Not signed in")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Button("Refresh account") {
                            store.refreshAccount()
                        }
                        .controlSize(.small)
                    }
                    Text(accountSyncDescription)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        Label("Reset YouGlass sign-in data", systemImage: "trash")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .help("Remove saved YouTube tokens, API credentials, and browser cookies")
                }
                .padding(.top, 4)
            }

            GroupBox("YouTube Data API key") {
                VStack(alignment: .leading, spacing: 10) {
                    SecureField("Paste API key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Image(systemName: store.hasDataAPIKey ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .foregroundStyle(store.hasDataAPIKey ? .green : .secondary)
                        Text(store.hasDataAPIKey ? "API key saved in Keychain" : "No API key saved")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Save API key") {
                            store.saveDataAPIKey(apiKey)
                            apiKey = ""
                        }
                        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.top, 4)
            }

            GroupBox("Google OAuth for account actions") {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Installed-app OAuth client ID", text: $clientID)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Image(systemName: store.hasOAuthClientID ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .foregroundStyle(store.hasOAuthClientID ? .green : .secondary)
                        Text(store.hasOAuthClientID ? "OAuth client ID saved in Keychain" : "No OAuth client ID saved")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Save client ID") {
                            store.saveOAuthClientID(clientID)
                            clientID = ""
                        }
                        .disabled(clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    SecureField("Installed-app OAuth client secret", text: $clientSecret)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Image(systemName: store.hasOAuthClientSecret ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .foregroundStyle(store.hasOAuthClientSecret ? .green : .secondary)
                        Text(store.hasOAuthClientSecret ? "OAuth client secret saved in Keychain" : "No OAuth client secret saved")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Save client secret") {
                            store.saveOAuthClientSecret(clientSecret)
                            clientSecret = ""
                        }
                        .disabled(clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    Button {
                        guard !authorizing else { return }
                        authorizing = true
                        status = "Opening Google authorization..."
                        Task { @MainActor in
                            let authorized = await store.authorizeYouTubeComments()
                            authorizing = false
                            status = authorized
                                ? "Google comment access is ready."
                                : store.connectionMessage
                        }
                    } label: {
                        Label(authorizing ? "Waiting for Google..." : "Connect Google for comments", systemImage: "person.badge.key.fill")
                    }
                    .disabled(authorizing || !store.hasOAuthClientID || !store.hasOAuthClientSecret)
                }
                .padding(.top, 4)
            }

            Text("A normal YouTube browser login supplies cookies, but it does not grant this app permission to call the official Data API or post comments. API keys, OAuth credentials, and account tokens stay in the macOS Keychain. The downloaded client secret is never embedded in the app bundle.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let status {
                Text(status)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 540)
        .alert("Reset YouTube connection?", isPresented: $showingResetConfirmation) {
            Button("Reset", role: .destructive) {
                store.resetYouTubeCredentials()
                status = "Saved YouTube credentials and browser session removed."
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes the saved API key, Google OAuth token, and YouTube browser session from this Mac. You can connect again afterwards.")
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
}
