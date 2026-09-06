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
        PlayerHeaderControlLabel(configuration: configuration, palette: palette, minimumWidth: minimumWidth)
    }
}

private struct PlayerHeaderControlLabel: View {
    let configuration: ButtonStyleConfiguration
    let palette: Palette
    let minimumWidth: CGFloat
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(palette.text)
            .frame(minWidth: minimumWidth, minHeight: 32)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(configuration.isPressed || hovered ? palette.text.opacity(0.15) : .clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.96 : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
            .onHover { hovered = $0 }
    }
}

/// One system glass surface for the related header controls, with a stable
/// opaque treatment when the user asks macOS to reduce transparency.
struct PlayerControlShelf: ViewModifier {
    let palette: Palette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 21, style: .continuous)
        if reduceTransparency {
            content.background(palette.window, in: shape)
                .overlay(shape.stroke(palette.stroke, lineWidth: 1).allowsHitTesting(false))
        } else if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(.thinMaterial, in: shape)
                .overlay(shape.stroke(palette.stroke, lineWidth: 1).allowsHitTesting(false))
        }
    }
}
