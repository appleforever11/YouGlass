import SwiftUI

struct HomeLoadingView: View {
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.card.opacity(0.70))
                .frame(maxWidth: .infinity)
                .aspectRatio(2.75, contentMode: .fit)

            HStack {
                Text("Refreshing your recommendations")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                Spacer()
                ProgressView()
                    .controlSize(.small)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 170, maximum: 310), spacing: 18)],
                alignment: .leading,
                spacing: 18
            ) {
                ForEach(Array(0..<4), id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 10) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(palette.card.opacity(0.64))
                            .aspectRatio(16 / 9, contentMode: .fit)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(palette.card.opacity(0.64))
                            .frame(height: 12)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(palette.card.opacity(0.44))
                            .frame(width: 110, height: 10)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Refreshing your YouTube recommendations")
    }
}

struct HomeUnavailableView: View {
    @ObservedObject var store: YouTubeStore
    let palette: Palette
    let retry: () -> Void

    private var connectionMode: YouGlassConnectionMode {
        YouGlassConnectionMode.resolve(
            isNetworkAvailable: store.isNetworkAvailable,
            isSignedIn: store.isSignedIn,
            isSyncing: store.accountSyncInProgress || store.isLoading,
            detailMessage: store.connectionMessage
        )
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: connectionMode.systemImage)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(connectionMode == .offline ? .orange : palette.accent)

            Text(connectionMode == .offline
                ? "YouTube is offline"
                : connectionMode == .setupRequired
                    ? "Connect YouTube to load recommendations"
                    : "Recommendations are temporarily unavailable")
                .font(.system(size: 17, weight: .semibold))

            Text(store.connectionMessage)
                .font(.system(size: 13))
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: 430)

            HStack(spacing: 10) {
                Button(action: retry) {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)

                if connectionMode.isSetupActionRecommended {
                    SettingsLink {
                        Label("Open Settings", systemImage: "gearshape")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 320, alignment: .center)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(connectionMode.title). \(store.connectionMessage)")
    }
}

struct SearchContentView: View {
    @ObservedObject var store: YouTubeStore
    let palette: Palette
    let compact: Bool

    var body: some View {
        searchContent
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
    }

    private var searchContent: AnyView {
        if store.isLoading {
            return AnyView(ProgressView("Searching YouTube..."))
        }

        if !store.searchResults.isEmpty {
            return AnyView(
                VideoRow(
                    title: "Search results",
                    videos: store.searchResults,
                    palette: palette,
                    compact: compact,
                    showsSeeAll: false
                )
                .environmentObject(store)
            )
        }

        if let message = store.sectionEmptyMessage {
            return AnyView(SearchEmptyStateView(message: message))
        }

        return AnyView(EmptyView())
    }
}

struct SearchEmptyStateView: View {
    let message: String

    var body: some View {
        Text(message)
    }
}
