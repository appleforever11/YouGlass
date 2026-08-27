import SwiftUI

struct GlassIconButtonStyle: ButtonStyle {
    let palette: Palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(palette.text)
            .background(.thinMaterial)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(palette.isDark ? 0.16 : 0.44), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

struct GlassCapsuleButtonStyle: ButtonStyle {
    let palette: Palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(palette.text)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(.thinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(palette.isDark ? 0.16 : 0.44), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

/// Header controls share one continuous glass shelf. Individual rings around
/// every icon made the player chrome look noisy and left the menu control with
/// a different visual weight from its neighboring buttons.
struct PlayerHeaderControlButtonStyle: ButtonStyle {
    let palette: Palette
    var minimumWidth: CGFloat = 34

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(palette.text)
            .frame(minWidth: minimumWidth, minHeight: 32)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(configuration.isPressed ? palette.text.opacity(0.15) : .clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
