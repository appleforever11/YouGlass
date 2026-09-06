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

    static func dismantleNSView(_ view: TrackingView, coordinator: ()) {
        view.stopTracking()
    }

    class TrackingView: NSView {
        var onHover: ((Bool) -> Void)?
        private var isInside = false
        private var pointerTimer: Timer?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopTracking()
            guard window != nil else { return }
            // WebKit/SwiftUI can replace tracking regions without delivering
            // an entry event. Reconcile the real pointer position while this
            // player is attached, including after scroll, resize or activation.
            let timer = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.reconcilePointer() }
            }
            pointerTimer = timer
            RunLoop.main.add(timer, forMode: .common)
            reconcilePointer()
        }

        func stopTracking() {
            pointerTimer?.invalidate()
            pointerTimer = nil
        }

        func reconcilePointer() {
            guard let window, window.isVisible, !window.isMiniaturized,
                  NSApp.isActive, !isHiddenOrHasHiddenAncestor else {
                publish(false)
                return
            }
            updatePointer(locationInWindow: window.mouseLocationOutsideOfEventStream)
        }

        func updatePointer(locationInWindow: NSPoint) {
            publish(containsPointer(locationInWindow))
        }

        private func containsPointer(_ locationInWindow: NSPoint) -> Bool {
            let point = convert(locationInWindow, from: nil)
            // AppKit can report a visibleRect outside a non-clipping view's
            // bounds. Only the intersection belongs to this media surface.
            return bounds.contains(point) && visibleRect.contains(point)
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            let inside = window.map {
                containsPointer($0.mouseLocationOutsideOfEventStream)
            } ?? false
            var options: NSTrackingArea.Options = [
                .mouseEnteredAndExited, .mouseMoved, .activeAlways
            ]
            // Layout can replace the area while the pointer is already over
            // the controls. Seed AppKit's state so the next exit is delivered.
            if inside { options.insert(.assumeInside) }
            addTrackingArea(NSTrackingArea(rect: bounds.intersection(visibleRect),
                options: options,
                owner: self, userInfo: nil))
            publish(inside)
        }

        override func mouseEntered(with event: NSEvent) { updatePointer(locationInWindow: event.locationInWindow) }
        override func mouseMoved(with event: NSEvent) { updatePointer(locationInWindow: event.locationInWindow) }
        override func mouseExited(with event: NSEvent) { updatePointer(locationInWindow: event.locationInWindow) }

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
