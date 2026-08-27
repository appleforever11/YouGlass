import SwiftUI

struct LiquidBackground: View {
    let palette: Palette
    let ambientPalette: VideoAmbientPalette
    @State private var animationPhase = 0.0

    var body: some View {
        GeometryReader { geometry in
            let time = animationPhase * (Double.pi * 2)
            let energy = min(max(ambientPalette.energy, 0.18), 1.0)
            let glow = 0.90 + energy * 0.24
            let drift = 0.045 + energy * 0.080
            let breathing = 0.78 + 0.20 * ((sin(time * 0.42) + 1) * 0.5) + energy * 0.04
            let secondaryBreathing = 0.76 + 0.22 * ((cos(time * 0.34 + 1.2) + 1) * 0.5)
            let width = max(geometry.size.width, 1)
            let height = max(geometry.size.height, 1)
            let radius = max(width, height) * 0.86
            let primaryCenter = UnitPoint(
                x: 0.10 + sin(time * 0.16) * drift,
                y: 0.12 + cos(time * 0.13) * drift
            )
            let secondaryCenter = UnitPoint(
                x: 0.88 + cos(time * 0.12) * drift,
                y: 0.84 + sin(time * 0.15) * drift
            )
            let accentCenter = UnitPoint(
                x: 0.52 + sin(time * 0.10 + 1.4) * drift * 0.8,
                y: 0.48 + cos(time * 0.14 + 0.7) * drift * 0.8
            )

            ZStack {
                palette.isDark ? Color.black : palette.window

                // Broad fields keep the video present as a restrained glow
                // while the black base stays dominant. Their centers move
                // slowly so the color feels alive without distracting from
                // the watch surface.
                RadialGradient(
                    colors: [
                        ambientPalette.primary.color.opacity((palette.isDark ? 0.23 : 0.15) * breathing * glow),
                        ambientPalette.primary.color.opacity((palette.isDark ? 0.052 : 0.036) * breathing * glow),
                        .clear
                    ],
                    center: primaryCenter,
                    startRadius: 0,
                    endRadius: radius
                )

                RadialGradient(
                    colors: [
                        ambientPalette.secondary.color.opacity((palette.isDark ? 0.18 : 0.12) * secondaryBreathing * glow),
                        ambientPalette.secondary.color.opacity((palette.isDark ? 0.042 : 0.030) * secondaryBreathing * glow),
                        .clear
                    ],
                    center: secondaryCenter,
                    startRadius: 0,
                    endRadius: radius * 0.92
                )

                RadialGradient(
                    colors: [
                        ambientPalette.accent.color.opacity((palette.isDark ? 0.14 : 0.09) * (0.86 + breathing * 0.14) * glow),
                        .clear
                    ],
                    center: accentCenter,
                    startRadius: 0,
                    endRadius: radius * 0.72
                )

                AngularGradient(
                    colors: [
                        ambientPalette.primary.color.opacity(0.024 * glow),
                        ambientPalette.accent.color.opacity(0.036 * glow),
                        ambientPalette.secondary.color.opacity(0.030 * glow),
                        ambientPalette.primary.color.opacity(0.024 * glow)
                    ],
                    center: .center
                )
                .opacity(palette.isDark ? 0.9 : 0.5)
            }
            .animation(.easeInOut(duration: 2.4), value: ambientPalette)
        }
        .onAppear {
            animationPhase = 1
        }
        .animation(.easeInOut(duration: 18).repeatForever(autoreverses: true), value: animationPhase)
        .allowsHitTesting(false)
    }
}
