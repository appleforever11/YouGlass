import AppKit
import XCTest
@testable import YouTubeMac

final class CardPointerTests: XCTestCase {
    @MainActor
    func testRapidCrossingsAndFeedStateReset() {
        let first = CardPointerView()
        let second = CardPointerView()
        first.cardFrame = CGRect(x: 0, y: 800, width: 260, height: 220)
        second.cardFrame = CGRect(x: 280, y: 800, width: 260, height: 220)
        var active = [false, false]
        first.onChange = { active[0] = $0 }
        second.onChange = { active[1] = $0 }
        for index in 0..<100 {
            let point = CGPoint(x: index.isMultiple(of: 2) ? 130 : 410, y: 900)
            first.updatePointer(at: point, isVisible: true)
            second.updatePointer(at: point, isVisible: true)
            XCTAssertEqual(active, index.isMultiple(of: 2) ? [true, false] : [false, true])
        }
        active[1] = false
        second.synchronizeReportedHover(false)
        second.updatePointer(at: CGPoint(x: 410, y: 900), isVisible: true)
        XCTAssertTrue(active[1])
        second.updatePointer(at: CGPoint(x: 410, y: 900), isVisible: false)
        XCTAssertFalse(active[1])
    }

    @MainActor
    func testTrackingDoesNotInterceptCardClicks() {
        let view = CardPointerView(frame: NSRect(x: 0, y: 0, width: 260, height: 220))
        XCTAssertNil(view.hitTest(NSPoint(x: 130, y: 110)))
    }

    @MainActor
    func testTrackingAreaIsReplacedAndFollowsVisibleBounds() {
        let view = CardPointerView(frame: NSRect(x: 0, y: 0, width: 260, height: 220))
        for _ in 0..<20 { view.updateTrackingAreas() }
        XCTAssertEqual(view.trackingAreas.count, 1)
        let options = view.trackingAreas[0].options
        XCTAssertTrue(options.contains(.inVisibleRect))
        XCTAssertTrue(options.contains(.mouseMoved))
        XCTAssertTrue(options.contains(.mouseEnteredAndExited))
        XCTAssertTrue(options.contains(.activeAlways))
    }
}
