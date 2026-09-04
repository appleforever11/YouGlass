import AppKit
import SwiftUI

/// A non-intercepting tracking region at the card's unanimated layout bounds.
struct YouGlassCardPointerRegion: NSViewRepresentable {
    let cardFrame: CGRect
    let isHovered: Bool
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> CardPointerView {
        let view = CardPointerView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: CardPointerView, context: Context) {
        view.cardFrame = cardFrame
        view.synchronizeReportedHover(isHovered)
        view.onChange = onChange
        view.scheduleReconciliation()
    }

    static func dismantleNSView(_ view: CardPointerView, coordinator: ()) {
        view.stopMonitoring()
        view.onChange = nil
    }
}

final class CardPointerView: NSView {
    // A bounded sample survives card recreation during a feed diff; never
    // retain the event or its window. Newly mounted cards use the same event
    // coordinates as existing cards rather than an out-of-stream cursor read.
    private static weak var pointerWindow: NSWindow?
    private static var pointerLocation: CGPoint?
    var cardFrame: CGRect = .zero
    private var monitor: Any?
    var onChange: ((Bool) -> Void)?
    private var region: NSTrackingArea?
    private var hovered = false
    private var reconciliationScheduled = false

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func synchronizeReportedHover(_ value: Bool) { hovered = value }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let region { removeTrackingArea(region) }
        let region = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(region)
        self.region = region
        scheduleReconciliation()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopMonitoring()
        if window != nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .mouseEntered, .mouseExited, .scrollWheel]) { [weak self] event in
                if let self {
                    Self.pointerWindow = event.window
                    Self.pointerLocation = event.locationInWindow
                    if event.window === self.window {
                        self.reconcilePointer()
                    } else {
                        self.setHovered(false)
                    }
                }
                return event
            }
        }
        scheduleReconciliation()
    }

    func stopMonitoring() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    override func mouseEntered(with event: NSEvent) { track(event) }
    override func mouseMoved(with event: NSEvent) { track(event) }
    override func mouseExited(with event: NSEvent) { track(event) }

    private func track(_ event: NSEvent) {
        Self.pointerWindow = event.window
        Self.pointerLocation = event.locationInWindow
        reconcilePointer()
    }

    // Layout callbacks must not publish into SwiftUI's active layout transaction.
    // Pointer events themselves are handled synchronously, without debounce.
    func scheduleReconciliation() {
        guard !reconciliationScheduled else { return }
        reconciliationScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.reconciliationScheduled = false
            self.reconcilePointer()
        }
    }

    private func reconcilePointer() {
        guard let window, window.isVisible, !isHiddenOrHasHiddenAncestor else {
            setHovered(false)
            return
        }
        // Match the explicitly named SwiftUI document space, not .global or
        // the representable's transform-dependent native bounds.
        guard let root = enclosingScrollView?.documentView else { setHovered(false); return }
        let sampled = Self.pointerWindow === window ? Self.pointerLocation : nil
        let native = root.convert(sampled ?? window.mouseLocationOutsideOfEventStream, from: nil)
        let point = CGPoint(x: native.x, y: root.isFlipped ? native.y : root.bounds.height - native.y)
        updatePointer(at: point, isVisible: root.visibleRect.contains(native))
    }

    func updatePointer(at point: CGPoint, isVisible: Bool) {
        setHovered(isVisible && !cardFrame.isEmpty && cardFrame.contains(point))
    }

    private func setHovered(_ value: Bool) {
        guard hovered != value else { return }
        hovered = value
        onChange?(value)
    }
}
