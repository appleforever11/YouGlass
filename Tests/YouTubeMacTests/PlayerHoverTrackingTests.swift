import AppKit
import XCTest
@testable import YouTubeMac

@MainActor
final class PlayerHoverTrackingTests: XCTestCase {
    func testPositionReconciliationRecoversMissedEventsAndLayoutChanges() async {
        let parent = NSView(frame: NSRect(x: 0, y: 0, width: 1200, height: 900))
        let window = NSWindow(contentRect: parent.bounds, styleMask: .borderless,
                              backing: .buffered, defer: false)
        window.contentView = parent
        let view = PositionOnlyTrackingView(frame: NSRect(x: 100, y: 100, width: 800, height: 450))
        parent.addSubview(view)
        view.stopTracking()
        var values: [Bool] = []
        let entered = expectation(description: "Missing entry event recovered from position")
        view.onHover = { values.append($0); entered.fulfill() }
        view.updatePointer(locationInWindow: NSPoint(x: 400, y: 300))
        await fulfillment(of: [entered], timeout: 1)

        let exited = expectation(description: "Stationary pointer leaves after layout moves media")
        view.onHover = { values.append($0); exited.fulfill() }
        view.setFrameOrigin(NSPoint(x: 700, y: 100))
        XCTAssertEqual(view.convert(NSPoint(x: 400, y: 300), from: nil).x, -300)
        XCTAssertFalse(view.bounds.contains(view.convert(NSPoint(x: 400, y: 300), from: nil)))
        view.updatePointer(locationInWindow: NSPoint(x: 400, y: 300))
        await fulfillment(of: [exited], timeout: 1)

        let returned = expectation(description: "Missing reentry recovered after resize")
        view.onHover = { values.append($0); returned.fulfill() }
        view.setFrameOrigin(NSPoint(x: 100, y: 100))
        view.updatePointer(locationInWindow: NSPoint(x: 400, y: 300))
        await fulfillment(of: [returned], timeout: 1)
        XCTAssertEqual(values, [true, false, true])
        XCTAssertNil(view.hitTest(NSPoint(x: 400, y: 300)))
    }

    func testHoverReentryReportsChangesWithoutCapturingTransportClicks() async throws {
        let view = PlayerHoverTrackingView.TrackingView(frame: NSRect(x: 0, y: 0, width: 800, height: 450))
        XCTAssertNil(view.hitTest(NSPoint(x: 400, y: 420)))
        let event = try XCTUnwrap(NSEvent.mouseEvent(with: .mouseMoved, location: .zero,
            modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            eventNumber: 0, clickCount: 0, pressure: 0))
        var values: [Bool] = []
        let entered = expectation(description: "Pointer enters video")
        view.onHover = { values.append($0); entered.fulfill() }
        view.mouseEntered(with: event)
        view.mouseMoved(with: event)
        await fulfillment(of: [entered], timeout: 1)
        XCTAssertEqual(values, [true])

        let exited = expectation(description: "Pointer leaves video")
        view.onHover = { values.append($0); exited.fulfill() }
        let outsideEvent = try XCTUnwrap(NSEvent.mouseEvent(with: .mouseMoved,
            location: NSPoint(x: 900, y: 500), modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, eventNumber: 0, clickCount: 0, pressure: 0))
        view.mouseExited(with: outsideEvent)
        view.mouseEntered(with: outsideEvent)
        await fulfillment(of: [exited], timeout: 1)

        let reentered = expectation(description: "Pointer returns to controls")
        view.onHover = { values.append($0); reentered.fulfill() }
        view.mouseEntered(with: event)
        await fulfillment(of: [reentered], timeout: 1)
        XCTAssertEqual(values, [true, false, true])
    }
}

/// Deliberately withhold OS events and the live cursor while exercising the
/// same position reconciliation against real AppKit coordinate conversion.
@MainActor
private final class PositionOnlyTrackingView: PlayerHoverTrackingView.TrackingView {
    override func viewDidMoveToWindow() {}
    override func updateTrackingAreas() {}
}
