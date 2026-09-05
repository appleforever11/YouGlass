import XCTest
@testable import YouTubeMac

final class SearchResponseTests: XCTestCase {
    func testMixedSearchResourceIDsDoNotDiscardVideoResults() throws {
        let data = Data("""
        {"items":[
          {"id":{"kind":"youtube#channel","channelId":"channel-1"},"snippet":\(snippet)},
          {"id":{"kind":"youtube#video","videoId":"abcdefghijk"},"snippet":\(snippet)},
          {"id":{"kind":"youtube#playlist","playlistId":"playlist-1"},"snippet":\(snippet)}
        ]}
        """.utf8)
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)
        XCTAssertEqual(response.items.compactMap(\.id.videoId), ["abcdefghijk"])
        XCTAssertEqual(response.items[1].snippet.channelID, "channel-1")
    }

    func testEmptySearchResponseIsValid() throws {
        let response = try JSONDecoder().decode(SearchResponse.self, from: Data(#"{"items":[]}"#.utf8))
        XCTAssertTrue(response.items.isEmpty)
    }

    private var snippet: String {
        """
        {"title":"Example","channelTitle":"Example channel","channelId":"channel-1",
         "publishedAt":"2026-09-01T10:00:00Z",
         "thumbnails":{"default":{"url":"https://example.invalid/image.jpg"}}}
        """
    }
}
