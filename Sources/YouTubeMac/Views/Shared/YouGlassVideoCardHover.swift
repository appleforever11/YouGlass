import SwiftUI

private struct CardPointerDocumentKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var cardPointerUsesDocumentSpace: Bool {
        get { self[CardPointerDocumentKey.self] }
        set { self[CardPointerDocumentKey.self] = newValue }
    }
}

/// Pointer feedback is immediate; speculative network work requires a short dwell.
private struct YouGlassVideoCardHover: ViewModifier {
    @Binding var isHovered: Bool
    let videoID: String
    let prewarm: () -> Void
    @State private var cardFrame: CGRect = .zero
    @Environment(\.cardPointerUsesDocumentSpace) private var usesDocumentSpace

    func body(content: Content) -> some View {
        let documentSpace = usesDocumentSpace
        return content
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: documentSpace ? .named("youglass-card-document") : .global)
            } action: { cardFrame = $0 }
            .background {
                if usesDocumentSpace {
                    YouGlassCardPointerRegion(cardFrame: cardFrame, isHovered: isHovered) { active in
                        if isHovered != active { isHovered = active }
                    }
                }
            }
            .onContinuousHover { phase in
                guard !usesDocumentSpace else { return }
                switch phase {
                case .active: isHovered = true
                case .ended: isHovered = false
                }
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
