import SwiftUI

/// Shared glass treatment for content surfaces. The availability fallback keeps
/// the app usable on the minimum supported macOS version without duplicating
/// the surface styling at every call site.
struct YouGlassSurfaceModifier: ViewModifier {
    let palette: Palette
    let cornerRadius: CGFloat
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(macOS 26.0, *) {
            if interactive {
                content
                    .clipShape(shape)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
                    .overlay {
                        shape.stroke(
                            LinearGradient(
                                colors: [palette.pink.opacity(0.30), palette.stroke, palette.purple.opacity(0.24)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    }
            } else {
                content
                    .clipShape(shape)
                    .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                    .overlay {
                        shape.stroke(
                            LinearGradient(
                                colors: [palette.pink.opacity(0.22), palette.stroke, palette.purple.opacity(0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    }
            }
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape
                          .fill(
                              LinearGradient(
                                  colors: [
                                      palette.purple.opacity(palette.isDark ? 0.070 : 0.035),
                                      palette.pink.opacity(palette.isDark ? 0.038 : 0.020)
                                  ],
                                  startPoint: .topLeading,
                                  endPoint: .bottomTrailing
                              )
                          )
                }
                .overlay {
                    shape
                        .stroke(palette.stroke, lineWidth: 1)
                }
                .clipShape(shape)
        }
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
