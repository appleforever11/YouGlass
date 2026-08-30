import XCTest
@testable import YouTubeMac

@MainActor
final class BridgeTests: XCTestCase {
    func testWebFeedPayloadDecodesAndMapsFallbackMetadata() throws {
        let json = """
        {
          "items": [
            {
              "id": "video-one",
              "title": "First video",
              "channel": "",
              "views": "",
              "age": "1 day ago",
              "duration": "",
              "imageURL": "http://[invalid"
            },
            {
              "id": "video-two",
              "title": "Second video",
              "channel": "Example",
              "views": "2K views",
              "age": "now",
              "duration": "4:20",
              "imageURL": "https://i.ytimg.com/vi/video-two/hqdefault.jpg"
            },
            {
              "id": "video-short",
              "title": "Quick tips #shorts",
              "channel": "Example",
              "views": "2K views",
              "age": "now",
              "duration": "0:30",
              "imageURL": "https://i.ytimg.com/vi/video-short/hqdefault.jpg"
            }
          ],
          "signedIn": true,
          "profileImageURL": "https://yt3.ggpht.com/example=s240",
          "title": "YouTube",
          "url": "https://www.youtube.com/",
          "initialCount": 4,
          "domCount": 2
        }
        """

        let payload = try XCTUnwrap(YouTubeWebFeedBridge.decodePayload(from: json))
        let videos = YouTubeWebFeedBridge.videoItems(from: payload)

        XCTAssertEqual(payload.initialCount, 4)
        XCTAssertEqual(payload.domCount, 2)
        XCTAssertEqual(payload.profileImageURL, "https://yt3.ggpht.com/example=s240")
        XCTAssertEqual(videos.map(\.id), ["video-one", "video-two"])
        XCTAssertEqual(videos[0].channel, "YouTube")
        XCTAssertEqual(videos[0].views, "Recommended")
        XCTAssertNil(videos[0].imageURL)
        XCTAssertEqual(videos[1].duration, "4:20")
        XCTAssertEqual(videos[1].imageURL?.absoluteString, "https://i.ytimg.com/vi/video-two/hqdefault.jpg")
    }

    func testWebFeedPayloadRejectsMalformedOrIncompleteJSON() {
        XCTAssertNil(YouTubeWebFeedBridge.decodePayload(from: "{not JSON}"))
        XCTAssertNil(YouTubeWebFeedBridge.decodePayload(from: "{\"items\": []}"))
    }

    func testWebFeedSnapshotMergePreservesOrderAndPrefersEnrichedMetadata() {
        let existing = VideoItem(
            id: "same",
            title: "Video",
            channel: "YouTube",
            views: "Recommended",
            age: "",
            duration: "",
            imageURL: nil,
            verified: false
        )
        let enriched = VideoItem(
            id: "same",
            title: "Video",
            channel: "Example Channel",
            views: "1.2K views",
            age: "1 hour ago",
            duration: "8:00",
            imageURL: URL(string: "https://example.com/video.jpg"),
            verified: false
        )
        let second = VideoItem(
            id: "second",
            title: "Another video",
            channel: "Another Channel",
            views: "Recommended",
            age: "",
            duration: "",
            imageURL: nil,
            verified: false
        )

        let bridge = YouTubeWebFeedBridge()
        let merged = bridge.mergeSnapshotVideos([existing], with: [second, enriched])

        XCTAssertEqual(merged.map(\.id), ["same", "second"])
        XCTAssertEqual(merged[0].channel, "Example Channel")
        XCTAssertEqual(merged[0].views, "1.2K views")
        XCTAssertEqual(merged[0].age, "1 hour ago")
        XCTAssertEqual(merged[0].imageURL?.absoluteString, "https://example.com/video.jpg")
    }

    func testWebFeedScriptAvoidsRedundantAnchorNormalizationAndPolling() {
        let script = YouTubeWebFeedBridge.extractionScript(maxResults: 20)

        XCTAssertEqual(script.components(separatedBy: "normalizeId(candidate.href)").count - 1, 1)
        XCTAssertFalse(script.contains("MutationObserver"))
        XCTAssertFalse(script.contains("setInterval"))
        XCTAssertFalse(script.contains("includeShorts"))
        XCTAssertTrue(script.contains("entry.isShort"))
        XCTAssertTrue(script.contains("items.slice(0, limit)"))
        XCTAssertTrue(script.contains("profileImageURL"))
        XCTAssertTrue(script.contains("#avatar-btn img#img"))
    }

    func testPlayerChromeScopesCaptionsAndUsesNativeCaptionSurface() {
        let script = YouTubeInlinePlayerView.playerChromeScript

        XCTAssertTrue(script.contains("findCaptionButton"))
        XCTAssertTrue(script.contains("invokeCaptionFallback"))
        XCTAssertTrue(script.contains("toggleSubtitles"))
        XCTAssertTrue(script.contains("setOption('captions', 'track'"))
        XCTAssertTrue(script.contains("ensureCaptionTrack"))
        XCTAssertTrue(script.contains("readCaptionsState(media)"))
        XCTAssertTrue(script.contains("formatPlaybackRate"))
        XCTAssertTrue(script.contains("No captions available for this video"))
        XCTAssertTrue(script.contains("display: block !important"))
        XCTAssertTrue(script.contains("display: inline !important"))
        XCTAssertTrue(script.contains("font-size: clamp(18px, 3.2vw, 32px) !important"))
        XCTAssertTrue(script.contains("readRenderedCaptionText"))
        XCTAssertTrue(script.contains("emitCaptionState"))
        XCTAssertTrue(script.contains("captionText: text"))
        XCTAssertTrue(script.contains("__youglassLastCaptionState"))
        XCTAssertTrue(script.contains("'ended'"))
        XCTAssertTrue(script.contains("media.loop = false"))
        XCTAssertFalse(script.contains("Captions unavailable for this video"))
    }

    func testPlaybackMessageCarriesCaptionTextToNativePlayer() {
        let message = YouTubeInlinePlayerView.PlaybackMessage(body: [
            "videoID": "video-one",
            "captionsEnabled": true,
            "captionText": "Hello from the active track",
            "ended": false,
            "frameReady": true
        ])

        XCTAssertEqual(message?.captionText, "Hello from the active track")
        XCTAssertEqual(message?.captionsEnabled, true)
        XCTAssertEqual(message?.ended, false)
        XCTAssertEqual(message?.dictionary["captionText"] as? String, "Hello from the active track")
        XCTAssertEqual(message?.dictionary["ended"] as? Bool, false)
    }

    func testPlaybackEndedMessageReachesNativeAutoAdvanceState() {
        let message = YouTubeInlinePlayerView.PlaybackMessage(body: [
            "videoID": "video-one",
            "playing": false,
            "ended": true
        ])
        let controller = YouTubePlaybackController()
        controller.activeVideoID = "video-one"

        controller.update(from: message!.dictionary)

        XCTAssertTrue(controller.didFinish)
    }

    func testCaptionOnlyPlaybackMessagePreservesReadySurface() {
        let controller = YouTubePlaybackController()
        controller.activeVideoID = "video-one"
        controller.isSurfaceReady = true

        controller.update(from: [
            "videoID": "video-one",
            "captionsEnabled": true,
            "captionText": "A live caption update"
        ])

        XCTAssertTrue(controller.isSurfaceReady)
        XCTAssertEqual(controller.captionText, "A live caption update")
    }

    func testTransientCaptionStateDoesNotClearNativeText() {
        let controller = YouTubePlaybackController()
        controller.activeVideoID = "video-one"
        controller.captionText = "Keep this line visible"
        controller.isCaptionsEnabled = true

        controller.update(from: [
            "videoID": "video-one",
            "captionsEnabled": false,
            "playing": true
        ])

        XCTAssertEqual(controller.captionText, "Keep this line visible")

        controller.update(from: [
            "videoID": "video-one",
            "captionsEnabled": false,
            "captionText": "",
            "playing": true
        ])

        XCTAssertEqual(controller.captionText, "Keep this line visible")

        controller.update(from: [
            "videoID": "video-one",
            "captionsEnabled": false,
            "status": "Captions off"
        ])

        XCTAssertEqual(controller.captionText, "")
    }

    func testCommentsPayloadMapsContinuationAndInvalidAvatarSafely() throws {
        let json = """
        {
          "comments": [
            {
              "id": "comment-one",
              "author": "Viewer",
              "text": "A useful comment",
              "age": "2 hours ago",
              "likes": "12",
              "avatarURL": "http://[invalid"
            }
          ],
          "totalCount": 1200,
          "isAvailable": true,
          "message": null,
          "nextPageToken": "bridge-offset:1",
          "nextContinuationToken": "continuation-token",
          "channelID": "UC123"
        }
        """

        let payload = try XCTUnwrap(YouTubeCommentsBridge.decodePayload(from: json))
        let page = YouTubeCommentsBridge.commentPage(from: payload)

        XCTAssertEqual(page.totalCount, 1200)
        XCTAssertTrue(page.isAvailable)
        XCTAssertEqual(page.nextPageToken, "bridge-offset:1")
        XCTAssertEqual(page.channelID, "UC123")
        XCTAssertEqual(page.comments.first?.text, "A useful comment")
        XCTAssertNil(page.comments.first?.avatarURL)
    }

    func testCommentsPayloadRejectsMalformedOrIncompleteJSON() {
        XCTAssertNil(YouTubeCommentsBridge.decodePayload(from: "[]"))
        XCTAssertNil(YouTubeCommentsBridge.decodePayload(from: "{\"comments\": []}"))
    }

    func testCommentsBridgeAcceptsOnlyYouTubeVideoIDs() {
        XCTAssertTrue(YouTubeCommentsBridge.isValidVideoID("dQw4w9WgXcQ"))
        XCTAssertTrue(YouTubeCommentsBridge.isValidVideoID("___________"))
        XCTAssertTrue(YouTubeCommentsBridge.isValidVideoID("-----------"))
        XCTAssertFalse(YouTubeCommentsBridge.isValidVideoID("dQw4w9WgXC"))
        XCTAssertFalse(YouTubeCommentsBridge.isValidVideoID("dQw4w9WgXcQ1"))
        XCTAssertFalse(YouTubeCommentsBridge.isValidVideoID("dQw4w9WgXc!"))
        XCTAssertFalse(YouTubeCommentsBridge.isValidVideoID(" dQw4w9WgXcQ"))
    }

    func testCommentsScriptCachesShadowRootsAndAvoidsDuplicateContinuationClicks() {
        let extractionScript = YouTubeCommentsBridge.extractionScript(
            maxResults: 50,
            offset: 50,
            continuationToken: "token-with-\"quotes"
        )
        let loadingScript = YouTubeCommentsBridge.stagedLoadingScript(offset: 50, maxResults: 50)

        XCTAssertTrue(extractionScript.contains("const searchRoots = [...roots]"))
        XCTAssertTrue(extractionScript.contains("if (direct.length > 0) return direct"))
        XCTAssertTrue(extractionScript.contains("const nestedRootsCache = new WeakMap()"))
        XCTAssertTrue(extractionScript.contains("status !== 'done'"))
        XCTAssertFalse(extractionScript.contains("const continuationCount"))
        XCTAssertEqual(extractionScript.components(separatedBy: "queryAll('ytd-continuation-item-renderer')").count - 1, 1)
        XCTAssertTrue(loadingScript.contains("continuationButton.click();"))
        XCTAssertFalse(loadingScript.contains("new MouseEvent('click'"))
        XCTAssertFalse(extractionScript.contains("new MutationObserver"))
        XCTAssertFalse(extractionScript.contains("setInterval"))
    }
}
