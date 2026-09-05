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
            return AnyView(
                SearchEmptyStateView(
                    query: store.query,
                    message: message,
                    palette: palette,
                    clear: {
                        store.query = ""
                        store.requestSearchFocus()
                    },
                    retry: { store.startSearch() }
                )
            )
        }

        return AnyView(EmptyView())
    }
}

struct SearchEmptyStateView: View {
    let query: String
    let message: String
    let palette: Palette
    let clear: () -> Void
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(palette.accent)
                .frame(width: 64, height: 64)
                .background(palette.selected.opacity(0.42), in: Circle())

            Text(query.isEmpty ? "Search YouTube" : "Search results unavailable")
                .font(.title2.weight(.bold))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)

            if !query.isEmpty {
                Text("Try a broader title, channel, or topic. YouTube Shorts remain excluded throughout YouGlass.")
                    .font(.caption)
                    .foregroundStyle(palette.tertiaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 430)

                HStack(spacing: 10) {
                    Button("Clear Search", action: clear)
                        .buttonStyle(.bordered)
                    Button(action: retry) {
                        Label("Try Again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .center)
        .padding(24)
        .youGlassSurface(palette: palette, cornerRadius: 18)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search results unavailable. \(message)")
    }
}

struct HomeSectionEmptyState: View {
    let title: String
    let message: String
    let palette: Palette
    let returnHome: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray.fill")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(palette.accent)
            Text("Nothing in \(title) yet")
                .font(.title2.weight(.bold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            Button(action: returnHome) {
                Label("Return to Home", systemImage: "house.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .center)
        .padding(24)
        .youGlassSurface(palette: palette, cornerRadius: 18)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title) has no content. \(message)")
    }
}
