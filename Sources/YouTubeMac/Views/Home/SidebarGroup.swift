import SwiftUI

struct SidebarGroup: View {
    @EnvironmentObject private var store: YouTubeStore
    let items: [(String, String, Bool, String, String?)]
    let palette: Palette
    let compact: Bool
    @State private var hoveredSection: String?

    var body: some View {
        VStack(spacing: 4) {
            ForEach(items, id: \.1) { symbol, title, selected, section, query in
                let active = selected || store.selectedSection == title
                let hovered = hoveredSection == section
                Button(action: { store.showSection(section, query: query) }) {
                    HStack(spacing: 13) {
                        Image(systemName: symbol)
                            .font(.system(size: 16, weight: active ? .semibold : .regular))
                            .foregroundStyle(active ? palette.accent : palette.text)
                            .frame(width: 20)
                        if !compact {
                            Text(title)
                                .font(.system(size: 14, weight: active ? .semibold : .regular))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                            Spacer()
                        }
                    }
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity, alignment: compact ? .center : .leading)
                    .padding(.horizontal, compact ? 8 : 14)
                    .frame(height: 36)
                    .background {
                        if active {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.thinMaterial)
                        } else if hovered {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(palette.selected.opacity(palette.isDark ? 0.32 : 0.20))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                active
                                    ? palette.accent.opacity(0.46)
                                    : (hovered ? palette.stroke : .clear),
                                lineWidth: 1
                            )
                    }
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(active ? palette.accent : .clear)
                            .frame(width: 3, height: 22)
                            .padding(.leading, 4)
                    }
                }
                .buttonStyle(.plain)
                .onHover { isHovering in
                    hoveredSection = isHovering ? section : (hoveredSection == section ? nil : hoveredSection)
                }
                .help(title)
                .accessibilityLabel(title)
                .accessibilityValue(active ? "Selected" : "Not selected")
            }
        }
        .padding(.horizontal, compact ? 8 : 22)
    }
}
