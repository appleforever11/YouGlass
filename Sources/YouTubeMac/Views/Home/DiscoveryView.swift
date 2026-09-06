import SwiftUI

struct DiscoveryView: View {
    @EnvironmentObject private var store: YouTubeStore
    let palette: Palette

    private let topics: [(title: String, subtitle: String, symbol: String, query: String)] = [
        ("Technology", "Ideas, devices, and what’s next", "desktopcomputer", "technology reviews"),
        ("Science", "Discover how the world works", "atom", "science documentaries"),
        ("Design", "Creative work and inspiration", "paintpalette", "design process"),
        ("Music", "Performances and new sounds", "music.note", "live music performances"),
        ("Gaming", "Deep dives, reviews, and play", "gamecontroller", "gaming reviews"),
        ("Travel", "Places worth exploring", "globe.americas", "travel documentaries")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            YouGlassSectionHeading(title: "Explore", subtitle: "Follow your curiosity. Choose a topic or search for something specific.", palette: palette)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                ForEach(topics, id: \.title) { topic in
                    Button { store.startSearch(topic.query) } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: topic.symbol)
                                .font(.system(size: 25, weight: .medium))
                                .foregroundStyle(palette.accent)
                            Text(topic.title)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                            HStack {
                                Text(topic.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(palette.secondaryText)
                                Spacer(minLength: 4)
                                Image(systemName: "arrow.up.right")
                                    .foregroundStyle(palette.accent)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
                    }
                    .buttonStyle(DashboardActionStyle(palette: palette))
                    .accessibilityLabel("Explore \(topic.title)")
                    .accessibilityHint("Search YouTube for \(topic.query)")
                }
            }
            Button { store.requestSearchFocus() } label: {
                Label("Search all of YouTube", systemImage: "magnifyingglass")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(.top, 20)
    }
}
