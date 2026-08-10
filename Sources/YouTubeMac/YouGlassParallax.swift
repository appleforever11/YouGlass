import SwiftUI

private struct YouGlassThumbnailParallax: ViewModifier {
    private let translation: CGFloat
    private let rotation: Double

    @State private var pointer: CGPoint = .zero
    @State private var isHovering = false
    @State private var contentSize: CGSize = .zero

    init(translation: CGFloat = 5, rotation: Double = 2.8) {
        self.translation = translation
        self.rotation = rotation
    }

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            contentSize = geometry.size
                        }
                        .onChange(of: geometry.size) { _, newSize in
                            contentSize = newSize
                        }
                }
            }
            .scaleEffect(isHovering ? 1.025 : 1)
            .rotation3DEffect(
                .degrees(-Double(pointer.y) * rotation),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.72
            )
            .rotation3DEffect(
                .degrees(Double(pointer.x) * rotation),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.72
            )
            .offset(
                x: pointer.x * translation,
                y: pointer.y * translation
            )
            .shadow(
                color: .black.opacity(isHovering ? 0.22 : 0),
                radius: isHovering ? 12 : 0,
                y: isHovering ? 6 : 0
            )
            .animation(
                .interactiveSpring(response: 0.24, dampingFraction: 0.82),
                value: pointer
            )
            .animation(
                .spring(response: 0.34, dampingFraction: 0.84),
                value: isHovering
            )
            .contentShape(Rectangle())
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let location):
                    let width = max(contentSize.width, 1)
                    let height = max(contentSize.height, 1)
                    let normalized = CGPoint(
                        x: min(max((location.x / width - 0.5) * 2, -1), 1),
                        y: min(max((location.y / height - 0.5) * 2, -1), 1)
                    )
                    pointer = normalized
                    isHovering = true
                case .ended:
                    pointer = .zero
                    isHovering = false
                }
            }
    }
}

extension View {
    /// Gives video artwork a restrained, pointer-directed liquid-glass lift.
    func videoThumbnailParallax(
        translation: CGFloat = 5,
        rotation: Double = 2.8
    ) -> some View {
        modifier(
            YouGlassThumbnailParallax(
                translation: translation,
                rotation: rotation
            )
        )
    }
}
