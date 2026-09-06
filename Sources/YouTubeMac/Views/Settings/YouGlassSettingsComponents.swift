import SwiftUI

extension YouGlassSettingsView {
        @ViewBuilder
        func settingsHeader(_ page: YouGlassSettingsPage) -> some View {
            HStack(spacing: 14) {
                SettingsIconBadge(systemName: page.systemName, tint: palette.accent, size: 42)
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
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }

        func settingsGroup<Content: View>(
            _ title: String,
            footer: String? = nil,
            @ViewBuilder content: @escaping () -> Content
        ) -> some View {
            YouGlassSettingsGroup(title: title, footer: footer, background: palette.card, content: content)
        }

        func settingsValueRow(_ title: String, value: String, systemName: String) -> some View {
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

        func credentialStatusRow<Content: View>(
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

        var accountSyncDescription: String {
            guard store.isSignedIn else {
                return "Sign in from the profile button, then refresh to load your real subscriptions and account-aware feed."
            }
            guard let date = store.lastAccountSyncDate else {
                return "Your account is connected. Subscription and recommendation data has not finished syncing yet."
            }
            return "Last account sync: \(date.formatted(date: .abbreviated, time: .shortened))."
        }

        var appVersion: String {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        }

        var buildVersion: String {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "100000"
        }
}
