import AppKit
import SwiftUI

private struct YouGlassThumbnailParallax: ViewModifier {
    private let translation: CGFloat
    private let rotation: Double

    @State private var pointer: CGPoint = .zero
    @State private var isHovering = false

    init(translation: CGFloat = 5, rotation: Double = 2.8) {
        self.translation = translation
        self.rotation = rotation
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if YouGlassRuntimeStabilityPolicy.parallaxMode == .stableHover {
            stableHoverBody(content: content)
        } else {
            pointerParallaxBody(content: content)
        }
    }

    private func stableHoverBody(content: Content) -> some View {
        content
            .scaleEffect(isHovering ? 1.012 : 1)
            .shadow(
                color: .black.opacity(isHovering ? 0.18 : 0),
                radius: isHovering ? 10 : 0,
                y: isHovering ? 5 : 0
            )
            .animation(.easeOut(duration: 0.18), value: isHovering)
            .contentShape(Rectangle())
            .onHover { hovering in
                guard isHovering != hovering else { return }
                isHovering = hovering
            }
    }

    private func pointerParallaxBody(content: Content) -> some View {
        content
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
            .background {
                YouGlassParallaxTrackingView { phase in
                    updatePointer(for: phase)
                }
            }
    }

    private func updatePointer(for phase: YouGlassParallaxTrackingView.Phase) {
        switch phase {
        case .active(let normalized):
            pointer = normalized
            isHovering = true
        case .ended:
            pointer = .zero
            isHovering = false
        }
    }
}

/// Tracks pointer movement without putting a GeometryReader-backed state
/// update into SwiftUI's layout graph. That matters for cards that are removed
/// while a personalized feed refresh is diffing its LazyVGrid.
private struct YouGlassParallaxTrackingView: NSViewRepresentable {
    enum Phase {
        case active(CGPoint)
        case ended
    }

    let onChange: (Phase) -> Void

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.onChange = onChange
    }

    static func dismantleNSView(_ nsView: TrackingView, coordinator: ()) {
        nsView.onChange = nil
    }

    final class TrackingView: NSView {
        var onChange: ((Phase) -> Void)?
        private var trackingArea: NSTrackingArea?
        private var pendingPhase: Phase?
        private var reportScheduled = false

        override var isFlipped: Bool { true }

        override func updateTrackingAreas() {
            if let trackingArea {
                removeTrackingArea(trackingArea)
            }

            let options: NSTrackingArea.Options = [
                .mouseEnteredAndExited,
                .mouseMoved,
                .activeInKeyWindow,
                .inVisibleRect
            ]
            let trackingArea = NSTrackingArea(
                rect: .zero,
                options: options,
                owner: self,
                userInfo: nil
            )
            addTrackingArea(trackingArea)
            self.trackingArea = trackingArea
            super.updateTrackingAreas()
        }

        override func mouseEntered(with event: NSEvent) {
            report(event)
        }

        override func mouseMoved(with event: NSEvent) {
            report(event)
        }

        override func mouseExited(with event: NSEvent) {
            scheduleReport(.ended)
        }

        private func report(_ event: NSEvent) {
            let width = max(bounds.width, 1)
            let height = max(bounds.height, 1)
            let location = convert(event.locationInWindow, from: nil)
            let normalized = CGPoint(
                x: min(max((location.x / width - 0.5) * 2, -1), 1),
                y: min(max((location.y / height - 0.5) * 2, -1), 1)
            )
            scheduleReport(.active(normalized))
        }

        private func scheduleReport(_ phase: Phase) {
            pendingPhase = phase
            guard !reportScheduled else { return }
            reportScheduled = true

            // Keep AppKit's mouse event out of SwiftUI's current transaction.
            // Coalescing also prevents a fast pointer sweep from rebuilding a
            // LazyVGrid once for every event.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.reportScheduled = false
                guard let pendingPhase = self.pendingPhase else { return }
                self.pendingPhase = nil
                self.onChange?(pendingPhase)
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
