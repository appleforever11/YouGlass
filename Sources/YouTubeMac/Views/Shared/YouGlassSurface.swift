import SwiftUI

/// Shared glass treatment for content surfaces. The availability fallback keeps
/// the app usable on the minimum supported macOS version without duplicating
/// the surface styling at every call site.
struct YouGlassSurfaceModifier: ViewModifier {
    let palette: Palette
    let cornerRadius: CGFloat
    let interactive: Bool
    @AppStorage(YouGlassVisualDefaults.glassIntensity) private var glassIntensity = 0.72

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let glassScale = 0.45 + min(max(glassIntensity, 0.25), 1.0) * 0.75
        let tintOpacity = interactive
            ? (palette.isDark ? 0.090 : 0.050) * glassScale
            : (palette.isDark ? 0.070 : 0.035) * glassScale
        let pinkOpacity = interactive
            ? (palette.isDark ? 0.055 : 0.030) * glassScale
            : (palette.isDark ? 0.038 : 0.020) * glassScale

        // Keep the glass treatment available to every supported SDK. The
        // material and layered tint provide the same translucent visual
        // language without requiring a newer SwiftUI SDK at build time.
        return content
            .background(.ultraThinMaterial, in: shape)
            .overlay {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.purple.opacity(tintOpacity),
                                palette.pink.opacity(pinkOpacity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    // The glass tint is decoration only. Keeping it out of
                    // hit testing prevents it from sitting above buttons
                    // hosted inside the surface.
                    .allowsHitTesting(false)
            }
            .overlay {
                shape
                    .stroke(
                        LinearGradient(
                            colors: [
                                palette.pink.opacity(interactive ? 0.30 : 0.22),
                                palette.stroke,
                                palette.purple.opacity(interactive ? 0.24 : 0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
            .clipShape(shape)
    }
}

extension View {
    func youGlassSurface(
        palette: Palette,
        cornerRadius: CGFloat = 16,
        interactive: Bool = false
    ) -> some View {
        modifier(
            YouGlassSurfaceModifier(
                palette: palette,
                cornerRadius: cornerRadius,
                interactive: interactive
            )
        )
    }
}
