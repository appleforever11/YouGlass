import SwiftUI

/// Navigation shortcuts are local presentation state, never a second feed loader.
struct HomeDashboardHeader: View {
    @EnvironmentObject private var store: YouTubeStore
    let palette: Palette
    let compact: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                heading
                Spacer(minLength: 12)
                shortcuts
            }
            VStack(alignment: .leading, spacing: 8) {
                heading
                HStack(spacing: 8) { shortcuts }
            }
        }
        .padding(.top, 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Home dashboard")
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("YOUGLASS / DISCOVER")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(palette.accent)
            Text("Made for your curiosity.")
                .font(.system(size: compact ? 26 : 34, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(palette.text)
            Text(store.homeRecommendationsAreFromYouTube
                 ? "Your YouTube Home feed. A clearer view."
                 : "Discover, save, and pick up where you left off.")
                .font(.system(size: 12))
                .foregroundStyle(palette.secondaryText)
        }
        .accessibilityAddTraits(.isHeader)
    }

    private var shortcuts: some View {
        Group {
            if !store.continueWatching.isEmpty {
                shortcut("Continue watching", detail: "Resume your latest video", icon: "play.fill") {
                    store.resumeLastVideo()
                }
            }
            Menu {
                Button("Watch Later") { store.showSection("Watch Later") }
                Button("Library") { store.showSection("Library") }
                Button("Subscriptions") { store.showSection("Subscriptions") }
                Divider()
                Button("Open YouTube Home") {
                    store.openURL(URL(string: "https://www.youtube.com/")!, title: "YouTube Home")
                }
            } label: {
                Label("Your space", systemImage: "square.stack")
                    .font(.system(size: 12, weight: .semibold))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .foregroundStyle(palette.secondaryText)
        }
    }

    private func shortcut(_ title: String, detail: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(palette.accent)
                Text(title)
            }
            .font(.system(size: 12, weight: .semibold))
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .buttonStyle(DashboardActionStyle(palette: palette))
        .help(detail)
    }
}

struct DashboardActionStyle: ButtonStyle {
    let palette: Palette

    func makeBody(configuration: Configuration) -> some View {
        DashboardActionLabel(configuration: configuration, palette: palette)
    }

    private struct DashboardActionLabel: View {
        let configuration: Configuration
        let palette: Palette
        @State private var hovered = false

        var body: some View {
            configuration.label
                .foregroundStyle(palette.text)
                .youGlassSurface(palette: palette, cornerRadius: 16, interactive: true)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(hovered ? palette.accent.opacity(0.65) : palette.stroke, lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: 16))
                .onHover { hovered = $0 }
        }
    }
}
