import SwiftUI

enum YouGlassVisualDefaults {
    static let reduceAmbientMotion = "YouGlass.reduceAmbientMotion"
}

/// Shared animated ambience for the home shell and player. The motion is
/// timeline-driven so it stays smooth during view updates and can be paused
/// for accessibility or lower-power use.
struct YouGlassAmbientBackdrop: View {
    let palette: Palette
    let ambientPalette: VideoAmbientPalette
    var intensity: Double = 1.0

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @AppStorage(YouGlassVisualDefaults.reduceAmbientMotion) private var reduceAmbientMotion = false

    private var motionPaused: Bool {
        accessibilityReduceMotion || reduceAmbientMotion
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: motionPaused)) { context in
            GeometryReader { geometry in
                let time = motionPaused ? 0 : context.date.timeIntervalSinceReferenceDate
                let energy = min(max(ambientPalette.energy, 0.18), 1.0)
                let breathing = 0.86 + 0.14 * ((sin(time * 0.48) + 1) * 0.5)
                let counterBreathing = 0.82 + 0.18 * ((cos(time * 0.36 + 1.4) + 1) * 0.5)
                let drift = 0.045 + energy * 0.055
                let width = max(geometry.size.width, 1)
                let height = max(geometry.size.height, 1)
                let radius = max(width, height) * 0.90
                let primaryCenter = UnitPoint(
                    x: 0.12 + CGFloat(sin(time * 0.14) * drift),
                    y: 0.14 + CGFloat(cos(time * 0.18) * drift)
                )
                let secondaryCenter = UnitPoint(
                    x: 0.86 + CGFloat(cos(time * 0.12 + 1.8) * drift),
                    y: 0.78 + CGFloat(sin(time * 0.16 + 0.6) * drift)
                )
                let accentCenter = UnitPoint(
                    x: 0.48 + CGFloat(sin(time * 0.10 + 2.2) * drift * 0.7),
                    y: 0.48 + CGFloat(cos(time * 0.13 + 1.0) * drift * 0.7)
                )
                let pink = palette.pink
                let purple = palette.purple
                let violet = palette.violet
                let baseOpacity = palette.isDark ? 1.0 : 0.72

                ZStack {
                    (palette.isDark ? Color.black : palette.window)
                        .opacity(baseOpacity)

                    RadialGradient(
                        colors: [
                            pink.opacity((palette.isDark ? 0.22 : 0.14) * breathing * intensity),
                            pink.opacity((palette.isDark ? 0.055 : 0.032) * intensity),
                            .clear
                        ],
                        center: primaryCenter,
                        startRadius: 0,
                        endRadius: radius
                    )

                    RadialGradient(
                        colors: [
                            purple.opacity((palette.isDark ? 0.24 : 0.15) * counterBreathing * intensity),
                            purple.opacity((palette.isDark ? 0.060 : 0.036) * intensity),
                            .clear
                        ],
                        center: secondaryCenter,
                        startRadius: 0,
                        endRadius: radius * 0.92
                    )

                    RadialGradient(
                        colors: [
                            violet.opacity((palette.isDark ? 0.16 : 0.10) * (0.82 + energy * 0.18) * intensity),
                            .clear
                        ],
                        center: accentCenter,
                        startRadius: 0,
                        endRadius: radius * 0.70
                    )

                    AngularGradient(
                        colors: [
                            pink.opacity(0.022 * intensity),
                            purple.opacity(0.040 * intensity),
                            violet.opacity(0.032 * intensity),
                            pink.opacity(0.022 * intensity)
                        ],
                        center: .center,
                        angle: .degrees(time * 2.5)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
