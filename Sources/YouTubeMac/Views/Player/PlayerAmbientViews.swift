import SwiftUI

enum PlayerMediaMetrics {
    static let cornerRadius: CGFloat = 24
}

struct PlayerAmbientSurface: View {
    let palette: Palette
    let ambientPalette: VideoAmbientPalette
    let intensity: Double
    var body: some View {
        ZStack {
            // The player is presented as a layer above Home. Keep an opaque
            // theme base here so the backdrop's translucent gradients and
            // materials blend with player ambience rather than sampling Home's
            // cards and headings through the clear portions of the fade.
            (palette.isDark ? Color.black : palette.window)

            YouGlassAmbientBackdrop(
                palette: palette,
                ambientPalette: ambientPalette,
                intensity: intensity,
                // The sampled video palette should change when the video
                // changes, not continuously animate the whole watch hierarchy.
                // Keeping this surface stable prevents the player from
                // competing with WebKit video decoding for the main thread.
                animated: false
            )
        }
    }
}

struct PlayerAmbientTint: View {
    let palette: Palette
    let ambientPalette: VideoAmbientPalette
    let intensity: Double

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let height = max(geometry.size.height, 1)
            let radius = max(width, height) * 0.86
            let energy = min(max(ambientPalette.energy, 0.18), 1.0)
            let glow = 0.92 + energy * 0.24

            ZStack {
                RadialGradient(
                    colors: [
                        ambientPalette.primary.color.opacity((palette.isDark ? 0.18 : 0.12) * intensity * glow),
                        ambientPalette.primary.color.opacity((palette.isDark ? 0.038 : 0.028) * intensity * glow),
                        .clear
                    ],
                    center: UnitPoint(x: 0.10, y: 0.16),
                    startRadius: 0,
                    endRadius: radius
                )

                RadialGradient(
                    colors: [
                        ambientPalette.secondary.color.opacity((palette.isDark ? 0.145 : 0.095) * intensity * glow),
                        ambientPalette.secondary.color.opacity((palette.isDark ? 0.030 : 0.022) * intensity * glow),
                        .clear
                    ],
                    center: UnitPoint(x: 0.90, y: 0.82),
                    startRadius: 0,
                    endRadius: radius * 0.90
                )

                RadialGradient(
                    colors: [
                        ambientPalette.accent.color.opacity((palette.isDark ? 0.105 : 0.070) * intensity * glow),
                        .clear
                    ],
                    center: UnitPoint(x: 0.54, y: 0.46),
                    startRadius: 0,
                    endRadius: radius * 0.72
                )

                AngularGradient(
                    colors: [
                        ambientPalette.primary.color.opacity(0.024 * intensity * glow),
                        ambientPalette.accent.color.opacity(0.036 * intensity * glow),
                        ambientPalette.secondary.color.opacity(0.030 * intensity * glow),
                        ambientPalette.primary.color.opacity(0.024 * intensity * glow)
                    ],
                    center: .center
                )
            }
        }
    }
}

struct BlendedPlayerSurfaceModifier: ViewModifier {
    let palette: Palette
    let ambientPalette: VideoAmbientPalette

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: PlayerMediaMetrics.cornerRadius,
            style: .continuous
        )
        let primaryGlow = ambientPalette.primary.color.opacity(palette.isDark ? 0.18 : 0.10)
        let secondaryGlow = ambientPalette.secondary.color.opacity(palette.isDark ? 0.12 : 0.07)
        let focusGlow = palette.accent.opacity(palette.isDark ? 0.16 : 0.09)
        let neutralEdgeGlow = Color.white.opacity(palette.isDark ? 0.11 : 0.17)

        return content
            .compositingGroup()
            .clipShape(shape)
            .background {
                ZStack {
                    shape
                        .fill(primaryGlow)
                        .blur(radius: 28)
                        .padding(-18)
                    shape
                        .fill(secondaryGlow)
                        .blur(radius: 22)
                        .padding(-12)
                }
                // Let the blurred tint breathe beyond the media bounds. The
                // content itself remains clipped by the modifier below, while
                // this background can blend into the page ambience smoothly.
            }
            .overlay {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                ambientPalette.primary.color.opacity(0.34),
                                palette.stroke.opacity(0.82),
                                palette.accent.opacity(palette.isDark ? 0.42 : 0.30),
                                ambientPalette.secondary.color.opacity(0.26)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
            .shadow(
                color: focusGlow,
                radius: 24,
                x: 0,
                y: 0
            )
            .shadow(
                color: neutralEdgeGlow,
                radius: 8,
                x: 0,
                y: 0
            )
            .shadow(
                color: ambientPalette.primary.color.opacity(palette.isDark ? 0.16 : 0.08),
                radius: 18,
                x: 0,
                y: 0
            )
    }
}
