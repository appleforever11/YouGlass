import SwiftUI

struct SettingsIconBadge: View {
    let systemName: String
    let tint: Color
    let size: CGFloat

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .shadow(color: tint.opacity(0.24), radius: 5, y: 2)
    }
}

struct YouGlassSettingsGroup<Content: View>: View {
    let title: String
    let footer: String?
    let background: Color
    let content: () -> Content

    init(title: String, footer: String?, background: Color, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.footer = footer
        self.background = background
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.quaternary, lineWidth: 1)
            }

            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }
        }
    }
}
