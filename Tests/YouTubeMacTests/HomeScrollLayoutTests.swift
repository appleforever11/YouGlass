import AppKit
import XCTest
@testable import YouTubeMac

final class HomeScrollLayoutTests: XCTestCase {
    @MainActor
    func testShortDocumentRemainsAtTopWhenLibraryContentShrinks() {
        let clip = YouGlassHomeClipView(frame: NSRect(x: 0, y: 0, width: 600, height: 700))
        let document = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 1200))
        clip.documentView = document
        document.setFrameSize(NSSize(width: 600, height: 300))
        let constrained = clip.constrainBoundsRect(clip.bounds)
        XCTAssertEqual(constrained.maxY, document.frame.maxY, accuracy: 0.5)
        XCTAssertEqual(constrained.origin.y, -400, accuracy: 0.5)
    }

    @MainActor
    func testLongDocumentRetainsUserScrollPosition() {
        let clip = YouGlassHomeClipView(frame: NSRect(x: 0, y: 0, width: 600, height: 700))
        clip.documentView = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 1400))
        let proposed = NSRect(x: 0, y: 350, width: 600, height: 700)
        XCTAssertEqual(clip.constrainBoundsRect(proposed).origin.y, 350, accuracy: 0.5)
    }
}
