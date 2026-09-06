import AppKit
import XCTest
@testable import YouTubeMac

final class PointerReplayTests: XCTestCase {
    func testMouseUpIsAvailableBeforeMouseDownEntersTracking() throws {
        let buffer = YouGlassPointerEventBuffer()
        let down = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 1, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        let up = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: .zero, modifierFlags: [], timestamp: 2, windowNumber: 0, context: nil, eventNumber: 2, clickCount: 1, pressure: 0))
        XCTAssertTrue(buffer.append(down))
        XCTAssertFalse(buffer.append(up), "A paired event must not wait in a second actor task")
        XCTAssertEqual(buffer.takeAll().map(\.type), [.leftMouseDown, .leftMouseUp])
        XCTAssertTrue(buffer.takeAll().isEmpty)
        XCTAssertTrue(buffer.append(down), "The next gesture schedules a fresh replay")
    }
}
