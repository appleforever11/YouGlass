import AppKit
import SwiftUI

/// Tracks the media rectangle independently of WebKit's child tracking areas.
/// It never claims clicks, so the native transport remains the hit-test owner.
struct PlayerHoverTrackingView: NSViewRepresentable {
    let onHover: (Bool) -> Void

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onHover = onHover
        return view
    }

    func updateNSView(_ view: TrackingView, context: Context) {
        view.onHover = onHover
    }

    final class TrackingView: NSView {
        var onHover: ((Bool) -> Void)?
        private var isInside = false

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            let inside = window.map {
                visibleRect.contains(convert($0.mouseLocationOutsideOfEventStream, from: nil))
            } ?? false
            var options: NSTrackingArea.Options = [
                .mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect
            ]
            // Layout can replace the area while the pointer is already over
            // the controls. Seed AppKit's state so the next exit is delivered.
            if inside { options.insert(.assumeInside) }
            addTrackingArea(NSTrackingArea(rect: .zero,
                options: options,
                owner: self, userInfo: nil))
            publish(inside)
        }

        override func mouseEntered(with event: NSEvent) { publish(true) }
        override func mouseMoved(with event: NSEvent) { publish(true) }
        override func mouseExited(with event: NSEvent) { publish(false) }

        private func publish(_ inside: Bool) {
            guard inside != isInside else { return }
            isInside = inside
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isInside == inside else { return }
                self.onHover?(inside)
            }
        }
    }
}
