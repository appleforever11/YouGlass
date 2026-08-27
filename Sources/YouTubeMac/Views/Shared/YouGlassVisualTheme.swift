import SwiftUI

enum YouGlassVisualDefaults {
    static let reduceAmbientMotion = "YouGlass.reduceAmbientMotion"
    static let themeFamily = "YouGlass.visualThemeFamily"
    static let backgroundGlow = "YouGlass.backgroundGlow"
    static let glassIntensity = "YouGlass.glassIntensity"
}

/// Shared animated ambience for the home shell and player. The motion is
/// state-driven so it remains stable during view updates and PIP transitions,
/// including during macOS beta window and PIP transitions.
struct YouGlassAmbientBackdrop: View {
    let palette: Palette
    let ambientPalette: VideoAmbientPalette
    var intensity: Double = 1.0
    var animated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @AppStorage(YouGlassVisualDefaults.reduceAmbientMotion) private var reduceAmbientMotion = false
    @AppStorage(YouGlassVisualDefaults.backgroundGlow) private var backgroundGlow = 0.78
    @State private var animationPhase = 0.0

    private var motionPaused: Bool {
        !animated || accessibilityReduceMotion || reduceAmbientMotion
    }

    var body: some View {
        GeometryReader { geometry in
                let time = motionPaused ? 0 : animationPhase * 18
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
                let glowScale = min(max(backgroundGlow, 0.35), 1.0)

                ZStack {
                    (palette.isDark ? Color.black : palette.window)
                        .opacity(baseOpacity)

                    if palette.theme == .neoCitrus {
                        NeoCitrusBackdropOrnaments(
                            palette: palette,
                            phase: time,
                            motionPaused: motionPaused
                        )
                        .opacity((palette.isDark ? 0.24 : 0.34) * glowScale)
                    }

                    RadialGradient(
                        colors: [
                            pink.opacity((palette.isDark ? 0.22 : 0.14) * breathing * intensity * glowScale),
                            pink.opacity((palette.isDark ? 0.055 : 0.032) * intensity * glowScale),
                            .clear
                        ],
                        center: primaryCenter,
                        startRadius: 0,
                        endRadius: radius
                    )

                    RadialGradient(
                        colors: [
                            purple.opacity((palette.isDark ? 0.24 : 0.15) * counterBreathing * intensity * glowScale),
                            purple.opacity((palette.isDark ? 0.060 : 0.036) * intensity * glowScale),
                            .clear
                        ],
                        center: secondaryCenter,
                        startRadius: 0,
                        endRadius: radius * 0.92
                    )

                    RadialGradient(
                        colors: [
                            violet.opacity((palette.isDark ? 0.16 : 0.10) * (0.82 + energy * 0.18) * intensity * glowScale),
                            .clear
                        ],
                        center: accentCenter,
                        startRadius: 0,
                        endRadius: radius * 0.70
                    )

                    AngularGradient(
                        colors: [
                            pink.opacity(0.022 * intensity * glowScale),
                            purple.opacity(0.040 * intensity * glowScale),
                            violet.opacity(0.032 * intensity * glowScale),
                            pink.opacity(0.022 * intensity * glowScale)
                        ],
                        center: .center,
                        angle: .degrees(time * 2.5)
                    )
                }
        }
        .onAppear {
            guard !motionPaused, animationPhase == 0 else { return }
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) {
                animationPhase = 1
            }
        }
        .onChange(of: motionPaused) { _, paused in
            guard !paused, animationPhase == 0 else { return }
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) {
                animationPhase = 1
            }
        }
        .allowsHitTesting(false)
    }
}

private struct NeoCitrusBackdropOrnaments: View {
    let palette: Palette
    let phase: Double
    let motionPaused: Bool

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let height = max(geometry.size.height, 1)
            let drift = motionPaused ? 0 : CGFloat(sin(phase * 0.11)) * min(width, height) * 0.018

            ZStack {
                citrusCapsule(width: width * 0.16, height: height * 0.72, colors: [palette.pink, palette.purple])
                    .position(x: width * 0.10 + drift, y: height * 0.42)
                citrusCapsule(width: width * 0.13, height: height * 0.48, colors: [palette.pink, palette.violet])
                    .position(x: width * 0.32 - drift * 0.6, y: height * 0.16)
                citrusCapsule(width: width * 0.18, height: height * 0.78, colors: [palette.purple, palette.violet])
                    .position(x: width * 0.61 + drift * 0.5, y: height * 0.64)
                citrusCapsule(width: width * 0.14, height: height * 0.54, colors: [palette.pink, palette.purple])
                    .position(x: width * 0.91 - drift, y: height * 0.26)
            }
            .blur(radius: max(18, min(width, height) * 0.035))
        }
    }

    private func citrusCapsule(width: CGFloat, height: CGFloat, colors: [Color]) -> some View {
        Capsule(style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .frame(width: max(width, 70), height: max(height, 150))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(palette.isDark ? 0.12 : 0.48), lineWidth: 1)
            }
    }
}
