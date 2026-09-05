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
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        let documentSpace = usesDocumentSpace
        return content
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: documentSpace ? .named("youglass-card-document") : .global)
            } action: { cardFrame = $0 }
            .background {
                if usesDocumentSpace && isEnabled {
                    YouGlassCardPointerRegion(cardFrame: cardFrame, isHovered: isHovered) { active in
                        updateHover(active)
                    }
                }
            }
            .onContinuousHover { phase in
                guard !usesDocumentSpace, isEnabled else { return }
                switch phase {
                case .active: updateHover(true)
                case .ended: updateHover(false)
                }
            }
            .task(id: isHovered && isEnabled ? videoID : nil) {
                guard isHovered, isEnabled else { return }
                do {
                    try await Task.sleep(for: .milliseconds(150))
                } catch { return }
                guard !Task.isCancelled, isHovered, isEnabled else { return }
                prewarm()
            }
            .onDisappear { isHovered = false }
            .onChange(of: isEnabled) { _, enabled in
                if !enabled { updateHover(false) }
            }
    }

    private func updateHover(_ active: Bool) {
        guard isHovered != active else { return }
        // Pointer feedback must not inherit card or feed transition animations.
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { isHovered = active }
    }
}

extension View {
    func videoCardHover(isHovered: Binding<Bool>, videoID: String, prewarm: @escaping () -> Void) -> some View {
        modifier(YouGlassVideoCardHover(isHovered: isHovered, videoID: videoID, prewarm: prewarm))
    }
}
