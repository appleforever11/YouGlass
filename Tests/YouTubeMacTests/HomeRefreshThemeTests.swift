import AppKit
import SwiftUI
import XCTest
@testable import YouTubeMac

#if compiler(>=6.4)
@MainActor
final class HomeRefreshThemeTests: XCTestCase {
    func testThemeChangeRetintsExistingRefreshController() throws {
        guard #available(macOS 27.0, *) else { throw XCTSkip("Requires native Home refresh") }
        let coordinator = YouGlassHomeScrollView<Text>.Coordinator(content: Text("Home"), refreshAction: {})
        let scrollView = NSScrollView()
        coordinator.updateRefresh(on: scrollView, enabled: true, tint: .systemPurple)
        let controller = try XCTUnwrap(scrollView.refreshController)
        XCTAssertEqual(controller.tintColor, .systemPurple)

        coordinator.updateRefresh(on: scrollView, enabled: true, tint: .systemOrange)
        XCTAssertTrue(scrollView.refreshController === controller)
        XCTAssertEqual(controller.tintColor, .systemOrange)

        coordinator.updateRefresh(on: scrollView, enabled: false, tint: .systemOrange)
        XCTAssertNil(scrollView.refreshController)
    }
}
#endif
