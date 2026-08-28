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
    let palette: Palette
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(palette.secondaryText)

            Text("Recommendations are temporarily unavailable")
                .font(.system(size: 17, weight: .semibold))

            Button(action: retry) {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .center)
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
