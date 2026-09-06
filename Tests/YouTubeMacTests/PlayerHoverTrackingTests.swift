import AppKit
import XCTest
@testable import YouTubeMac

@MainActor
final class PlayerHoverTrackingTests: XCTestCase {
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
        view.mouseExited(with: event)
        await fulfillment(of: [exited], timeout: 1)

        let reentered = expectation(description: "Pointer returns to controls")
        view.onHover = { values.append($0); reentered.fulfill() }
        view.mouseEntered(with: event)
        await fulfillment(of: [reentered], timeout: 1)
        XCTAssertEqual(values, [true, false, true])
    }
}
