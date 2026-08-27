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
