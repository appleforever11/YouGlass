import XCTest
@testable import YouTubeMac

final class HomepageParserTests: XCTestCase {
    private func renderer(_ id: String, title: String = "A normal video") -> [String: Any] {
        ["videoRenderer": ["videoId": id, "title": ["runs": [["text": title]]],
                           "ownerText": ["runs": [["text": "Channel"]]], "lengthText": ["simpleText": "10:00"]]]
    }

    private func page(_ contents: [[String: Any]], signedIn: Bool = true) throws -> String {
        let root: [String: Any] = [
            "responseContext": ["mainAppWebResponseContext": ["loggedOut": !signedIn]],
            "contents": ["twoColumnBrowseResultsRenderer": ["tabs": [
                ["tabRenderer": ["selected": true, "content": ["richGridRenderer": ["contents": contents]]]]
            ]]]
        ]
        let data = try JSONSerialization.data(withJSONObject: root)
        return "<script>var ytInitialData = \(String(decoding: data, as: UTF8.self));</script>"
    }

    func testHomepagePreservesSourceOrderAndExcludesAdsShortsAndDuplicates() throws {
        let html = try page([
            ["richItemRenderer": ["content": renderer("zzzzzzzzzzz")]],
            ["adSlotRenderer": renderer("advert12345")],
            ["reelShelfRenderer": ["items": [renderer("short123456")]]],
            renderer("aaaaaaaaaaa", title: "A {quoted} \"title\""),
            renderer("zzzzzzzzzzz"), renderer("shorttitle1", title: "Something #shorts")
        ])
        let result = YouTubeHomepageParser.parse(html, limit: 40)
        XCTAssertTrue(result.isSignedIn)
        XCTAssertEqual(result.videos.map(\.id), ["zzzzzzzzzzz", "aaaaaaaaaaa"])
        XCTAssertEqual(result.videos[1].title, "A {quoted} \"title\"")
    }

    func testModernVideoCardsAreSupportedButPlaylistsAreNot() throws {
        func lockup(_ type: String, id: String) -> [String: Any] {
            ["lockupViewModel": ["contentId": id, "contentType": type,
                                 "metadata": ["lockupMetadataViewModel": ["title": ["content": "Modern video"]]]]]
        }
        let html = try page([lockup("LOCKUP_CONTENT_TYPE_VIDEO", id: "newcard1234"),
                             lockup("LOCKUP_CONTENT_TYPE_PLAYLIST", id: "playlist123")], signedIn: false)
        let result = YouTubeHomepageParser.parse(html, limit: 40)
        XCTAssertFalse(result.isSignedIn)
        XCTAssertEqual(result.videos.map(\.id), ["newcard1234"])
    }

    func testMissingMalformedAndBoundedResponses() throws {
        XCTAssertTrue(YouTubeHomepageParser.parse("Sign in", limit: 40).videos.isEmpty)
        XCTAssertTrue(YouTubeHomepageParser.parse("var ytInitialData = {bad}", limit: 40).videos.isEmpty)
        let html = try page([renderer("aaaaaaaaaaa"), renderer("bbbbbbbbbbb")])
        XCTAssertEqual(YouTubeHomepageParser.parse(html, limit: 1).videos.count, 1)
    }

    func testShortsRoutesInsideOrdinaryCardsAreExcluded() throws {
        var short = renderer("short123456")
        var node = short["videoRenderer"] as! [String: Any]
        node["navigationEndpoint"] = ["commandMetadata": ["webCommandMetadata": ["url": "/shorts/short123456"]]]
        short["videoRenderer"] = node
        let html = try page([short, renderer("normal12345")], signedIn: false)
        let result = YouTubeHomepageParser.parse(html, limit: 40)
        XCTAssertFalse(result.isSignedIn)
        XCTAssertEqual(result.videos.map(\.id), ["normal12345"])
    }
}
