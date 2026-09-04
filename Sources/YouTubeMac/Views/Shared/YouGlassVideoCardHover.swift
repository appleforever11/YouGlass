import SwiftUI

/// Pointer feedback is immediate; speculative network work requires a short dwell.
private struct YouGlassVideoCardHover: ViewModifier {
    @Binding var isHovered: Bool
    let videoID: String
    let prewarm: () -> Void

    func body(content: Content) -> some View {
        content
            .onContinuousHover { phase in
                let active: Bool
                switch phase {
                case .active: active = true
                case .ended: active = false
                }
                // Movement repairs hover state, but never republishes each pixel.
                if isHovered != active { isHovered = active }
            }
            .task(id: isHovered ? videoID : nil) {
                guard isHovered else { return }
                do {
                    try await Task.sleep(for: .milliseconds(150))
                } catch { return }
                guard !Task.isCancelled, isHovered else { return }
                prewarm()
            }
            .onDisappear { isHovered = false }
    }
}

extension View {
    func videoCardHover(isHovered: Binding<Bool>, videoID: String, prewarm: @escaping () -> Void) -> some View {
        modifier(YouGlassVideoCardHover(isHovered: isHovered, videoID: videoID, prewarm: prewarm))
    }
}
