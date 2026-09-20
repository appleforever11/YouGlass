import XCTest
@testable import YouTubeMac

final class RefreshDestinationTests: XCTestCase {
    func testSearchAndCustomFeedsKeepTheirOwnRefreshBoundary() {
        XCTAssertEqual(destination("Search"), .search)
        XCTAssertEqual(destination("Home", custom: true), .customFeed)
        XCTAssertEqual(destination("Subscription Group"), .section("Subscription Group"))
        XCTAssertEqual(destination("Subscriptions"), .section("Subscriptions"))
    }

    func testLocalDestinationsNeverRefreshHome() {
        for section in ["Library", "Explore", "Notifications"] {
            XCTAssertEqual(destination(section), .unavailable)
        }
    }

    func testDetailSurfacesDoNotRefreshObscuredFeed() {
        XCTAssertEqual(destination("Home", channel: true), .unavailable)
        XCTAssertEqual(destination("Playlists", playlist: true), .unavailable)
    }

    func testHomeDrilldownsShareRecommendationRefresh() {
        for section in ["Home", "For You", "Trending", "More to watch"] {
            XCTAssertEqual(destination(section), .home)
        }
    }

    private func destination(
        _ section: String, custom: Bool = false, channel: Bool = false, playlist: Bool = false
    ) -> YouGlassRefreshDestination {
        YouGlassRefreshDestination(
            section: section, hasCustomFeed: custom, hasChannel: channel, hasPlaylist: playlist
        )
    }
}
