import SwiftUI

/// Navigation shortcuts are local presentation state, never a second feed loader.
struct HomeDashboardHeader: View {
    @EnvironmentObject private var store: YouTubeStore
    let palette: Palette
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("YOUR DAILY MIX")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(palette.accent)
                    Text("Find your next favorite.")
                        .font(.system(size: compact ? 28 : 36, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Fresh discoveries. Familiar channels. A space that’s yours.")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer(minLength: 0)
                if !compact {
                    Image(systemName: "play.rectangle.on.rectangle.fill")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(palette.accent)
                        .frame(width: 78, height: 78)
                        .background(palette.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 24))
                        .accessibilityHidden(true)
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { shortcuts }
                VStack(spacing: 10) { shortcuts }
            }
        }
        .padding(.vertical, 20)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Home dashboard")
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
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 36, height: 36)
                    .background(palette.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 13, weight: .bold))
                    Text(detail).font(.caption).foregroundStyle(palette.secondaryText)
                }
                .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right").font(.caption.weight(.semibold))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(DashboardActionStyle(palette: palette))
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
