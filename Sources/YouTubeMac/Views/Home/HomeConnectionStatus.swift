import SwiftUI

struct HomeConnectionStatusView: View {
    @ObservedObject var store: YouTubeStore
    let palette: Palette
    let compact: Bool

    private var mode: YouGlassConnectionMode {
        YouGlassConnectionMode.resolve(
            isNetworkAvailable: store.isNetworkAvailable,
            isSignedIn: store.isSignedIn,
            isSyncing: store.accountSyncInProgress || store.isLoading,
            detailMessage: store.connectionMessage
        )
    }

    private var tint: Color {
        switch mode {
        case .offline: .orange
        case .syncing: palette.accent
        case .connected: .green
        case .setupRequired: palette.pink
        case .local: palette.secondaryText
        }
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: mode.systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)

            if compact {
                Text(mode.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(mode.title)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    Text(mode.subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(palette.tertiaryText)
                        .lineLimit(1)
                }
            }
        }
        .foregroundStyle(palette.text)
        .padding(.horizontal, compact ? 8 : 10)
        .frame(height: 36)
        .background(palette.pill, in: Capsule())
        .overlay {
            Capsule()
                .stroke(tint.opacity(palette.isDark ? 0.30 : 0.22), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: compact ? 132 : 188, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(mode.title). \(store.connectionMessage)")
        .help("\(store.networkStatus). \(store.connectionMessage)")
    }
}
