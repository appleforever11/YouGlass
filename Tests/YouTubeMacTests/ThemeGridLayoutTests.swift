import SwiftUI
import XCTest
@testable import YouTubeMac

final class ThemeGridLayoutTests: XCTestCase {
    @MainActor
    func testCatalogMeasuresEveryRowForAppKitScrolling() {
        let host = NSHostingController(rootView: YouGlassThemeGrid {
            ForEach(0..<24) { index in
                Text("Environment \(index)").frame(height: 154)
            }
        })
        let size = host.sizeThatFits(in: CGSize(width: 670, height: CGFloat.greatestFiniteMagnitude))
        XCTAssertEqual(size.height, 12 * 154 + 11 * 16, accuracy: 1)
    }

    @MainActor
    func testFilteredCatalogDoesNotRetainEmptyRows() {
        let host = NSHostingController(rootView: YouGlassThemeGrid {
            Text("One environment").frame(height: 154)
        })
        let size = host.sizeThatFits(in: CGSize(width: 670, height: CGFloat.greatestFiniteMagnitude))
        XCTAssertEqual(size.height, 154, accuracy: 1)
    }
}
