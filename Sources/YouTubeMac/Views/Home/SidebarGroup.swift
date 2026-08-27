import SwiftUI

struct SidebarGroup: View {
    @EnvironmentObject private var store: YouTubeStore
    let items: [(String, String, Bool, String, String?)]
    let palette: Palette
    let compact: Bool

    var body: some View {
        VStack(spacing: 7) {
            ForEach(items, id: \.1) { symbol, title, selected, section, query in
                let active = selected || store.selectedSection == title
                Button(action: { store.showSection(section, query: query) }) {
                    HStack(spacing: 13) {
                        Image(systemName: symbol)
                            .font(.system(size: 18, weight: active ? .bold : .regular))
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
                .frame(height: 42)
                    .background(active ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.clear))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(active ? palette.stroke : .clear, lineWidth: 1)
                    }
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(active ? palette.accent : .clear)
                            .frame(width: 3, height: 22)
                            .padding(.leading, 4)
                    }
                }
                .buttonStyle(.plain)
                .help(title)
            }
        }
        .padding(.horizontal, compact ? 8 : 22)
    }
}
