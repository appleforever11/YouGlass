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
        Text("Home")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(palette.text)
    }

    private var shortcuts: some View {
        Group {
            shortcut("Watch Later", detail: "\(store.savedVideos.count) saved", icon: "bookmark.fill") {
                store.showSection("Watch Later")
            }
            shortcut("Library", detail: "Collections & notes", icon: "square.stack.fill") {
                store.showSection("Library")
            }
            shortcut("Subscriptions", detail: "Your channels", icon: "person.2.fill") {
                store.showSection("Subscriptions")
            }
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
                .background(
                    hovered || configuration.isPressed ? palette.selected : palette.card,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(hovered ? palette.accent.opacity(0.65) : palette.stroke, lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: 16))
                .onHover { hovered = $0 }
        }
    }
}
