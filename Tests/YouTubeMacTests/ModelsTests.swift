import XCTest
@testable import YouTubeMac

final class ModelsTests: XCTestCase {
    func testDataAPIKeyUsesStablePrivateCredentialIdentity() {
        XCTAssertEqual(YouGlassCredentialStore.service, "com.kevinhowe.YouGlass")
        XCTAssertEqual(YouGlassCredentialStore.legacyService, "com.kevinhowe.YouTubeMac")
        XCTAssertEqual(YouGlassCredentialStore.dataAPIKeyAccount, "YOUTUBE_API_KEY")
        XCTAssertEqual(KeychainStore.StorageMode.allCases, [.dataProtection, .login])
    }

    func testThemeCatalogProvidesPairedLightAndDarkFamilies() throws {
        let themes = YouGlassThemeFamily.allCases

        XCTAssertEqual(themes.count, 24)
        XCTAssertEqual(Set(themes.map(\.id)).count, themes.count)
        XCTAssertEqual(themes.filter(\.isFeatured), [.neoCitrus, .auroraBloom, .midnightVelvet, .paperLantern])
        XCTAssertEqual(themes.filter(\.isNew).count, 12)
        XCTAssertTrue(themes.allSatisfy { !$0.title.isEmpty && !$0.subtitle.isEmpty })

        for theme in themes {
            _ = theme.colors(isDark: false)
            _ = theme.colors(isDark: true)

            let encoded = try JSONEncoder().encode(theme)
            XCTAssertEqual(try JSONDecoder().decode(YouGlassThemeFamily.self, from: encoded), theme)
        }
    }

    func testThemeCollectionsCoverEveryEnvironment() {
        let themes = YouGlassThemeFamily.allCases
        let collections = Set(themes.map(\.collection))

        XCTAssertFalse(collections.contains(.all))
        XCTAssertEqual(collections, Set([.vivid, .calm, .warm, .cool, .nature, .minimal]))
        XCTAssertTrue(themes.contains { $0.badgeTitle == "NEW" })
        XCTAssertTrue(themes.contains { $0.badgeTitle == "FEATURED" })
    }

    func testPIPTransitionOnlyMatchesItsCurrentVideo() {
        let presenting = PIPTransitionState.presenting(videoID: "video-a")
        XCTAssertTrue(presenting.isTransitioning)
        XCTAssertTrue(presenting.matches(videoID: "video-a"))
        XCTAssertFalse(presenting.matches(videoID: "video-b"))

        let active = PIPTransitionState.active(videoID: "video-a")
        XCTAssertFalse(active.isTransitioning)
        XCTAssertTrue(active.matches(videoID: "video-a"))
        XCTAssertEqual(PIPTransitionState.idle, .idle)
    }

    func testPIPHandoffUsesShortAnimatedWindow() {
        XCTAssertGreaterThan(PIPTransitionPolicy.sourceTeardownDelayNanoseconds, 0)
        XCTAssertLessThan(PIPTransitionPolicy.sourceTeardownDelayNanoseconds, 500_000_000)
        XCTAssertGreaterThan(PIPTransitionPolicy.panelFadeDuration, 0)
        XCTAssertLessThan(PIPTransitionPolicy.panelFadeDuration, 0.5)
    }

    func testConnectionModePrioritizesReachabilityAndAccountState() {
        XCTAssertEqual(
            YouGlassConnectionMode.resolve(
                isNetworkAvailable: false,
                isSignedIn: true,
                isSyncing: false,
                detailMessage: "Connected"
            ),
            .offline
        )
        XCTAssertEqual(
            YouGlassConnectionMode.resolve(
                isNetworkAvailable: true,
                isSignedIn: false,
                isSyncing: true,
                detailMessage: "Loading recommendations"
            ),
            .syncing
        )
        XCTAssertEqual(
            YouGlassConnectionMode.resolve(
                isNetworkAvailable: true,
                isSignedIn: true,
                isSyncing: false,
                detailMessage: "Account feed ready"
            ),
            .connected
        )
    }

    func testConnectionModeSeparatesSetupFromLocalMode() {
        XCTAssertEqual(
            YouGlassConnectionMode.resolve(
                isNetworkAvailable: true,
                isSignedIn: false,
                isSyncing: false,
                detailMessage: "API key needed for live YouTube"
            ),
            .setupRequired
        )
        XCTAssertEqual(
            YouGlassConnectionMode.resolve(
                isNetworkAvailable: true,
                isSignedIn: false,
                isSyncing: false,
                detailMessage: "Saved YouTube recommendations"
            ),
            .local
        )
    }

    func testPlaybackCheckpointPolicyHasBoundedResumeData() {
        XCTAssertEqual(PlaybackCheckpointPolicy.maxEntries, 200)
        XCTAssertGreaterThan(PlaybackCheckpointPolicy.completionGraceSeconds, 0)
        XCTAssertLessThan(PlaybackCheckpointPolicy.completionGraceSeconds, 10)
        XCTAssertGreaterThan(PlaybackCheckpointPolicy.completionFraction, 0.9)
        XCTAssertLessThan(PlaybackCheckpointPolicy.completionFraction, 1)
        XCTAssertTrue(PlaybackCheckpointPolicy.isResumable(position: 30, duration: 300))
        XCTAssertFalse(PlaybackCheckpointPolicy.isResumable(position: 0, duration: 300))
        XCTAssertFalse(PlaybackCheckpointPolicy.isResumable(position: 30, duration: 0))
        XCTAssertFalse(PlaybackCheckpointPolicy.isResumable(position: 299, duration: 300))
    }

    func testParsesStandardWatchURL() {
        let video = VideoItem.fromYouTubeInput("https://www.youtube.com/watch?v=5sTQfGJiVdc")
        XCTAssertEqual(video?.id, "5sTQfGJiVdc")
        XCTAssertTrue(video?.isPlayableOnYouTube == true)
        XCTAssertEqual(video?.playbackURL.absoluteString, "https://www.youtube.com/watch?v=5sTQfGJiVdc")
    }

    func testPlaylistPreservesAccountMetadata() {
        let playlist = YouTubePlaylist(
            id: "PL123",
            title: "My playlist",
            description: "Saved videos",
            thumbnailURL: URL(string: "https://i.ytimg.com/vi/5sTQfGJiVdc/hqdefault.jpg"),
            itemCount: 19
        )

        XCTAssertEqual(playlist.id, "PL123")
        XCTAssertEqual(playlist.itemCount, 19)
        XCTAssertEqual(playlist.title, "My playlist")
    }

    func testSubscriptionMatchesChannelIDAndWebChannelName() {
        let byID = SubscriptionItem(
            id: "UC1234567890123456789012",
            name: "Example Channel",
            avatarURL: nil,
            isLive: false
        )
        XCTAssertTrue(byID.matches(channelID: "UC1234567890123456789012", channelName: "Different display name"))

        let fromWebSession = SubscriptionItem(
            id: "https://www.youtube.com/@ReportingLiveFromMySofaThePodcast",
            name: "ReportingLiveFromMySofaThePodcast",
            avatarURL: nil,
            channelURL: URL(string: "https://www.youtube.com/@ReportingLiveFromMySofaThePodcast"),
            isLive: false
        )
        XCTAssertTrue(fromWebSession.matches(channelID: nil, channelName: "Reporting Live From My Sofa The Podcast"))
        XCTAssertFalse(fromWebSession.matches(channelID: nil, channelName: "A different channel"))

        let shortenedWebLabel = SubscriptionItem(
            id: "https://www.youtube.com/@ReportingLiveFromMySofaThePodcast",
            name: "Reporting live from my sofa",
            avatarURL: nil,
            channelURL: URL(string: "https://www.youtube.com/@ReportingLiveFromMySofaThePodcast"),
            isLive: false
        )
        XCTAssertTrue(shortenedWebLabel.matches(channelID: nil, channelName: "ReportingLiveFromMySofaThePodcast"))

        XCTAssertTrue(shortenedWebLabel.matches(channelID: nil, channelName: "ReportingLiveFromMySofa..."))

        let sameNameDifferentID = SubscriptionItem(
            id: "UC9999999999999999999999",
            name: "Example Channel",
            avatarURL: nil,
            isLive: false
        )
        XCTAssertFalse(sameNameDifferentID.matches(channelID: "UC1234567890123456789012", channelName: "Example Channel"))
    }

    func testSubscriptionItemRoundTripsThroughJSON() throws {
        let item = SubscriptionItem(
            id: "UC1234567890123456789012",
            name: "Example Channel",
            avatarURL: URL(string: "https://example.com/avatar.jpg"),
            channelURL: URL(string: "https://www.youtube.com/channel/UC1234567890123456789012"),
            isLive: true
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(SubscriptionItem.self, from: data)

        XCTAssertEqual(decoded, item)
        XCTAssertEqual(decoded.canonicalChannelID, item.canonicalChannelID)
    }

    func testAccountChannelResponseDecodesProfileThumbnail() throws {
        let json = """
        {
          "items": [
            {
              "id": "UC1234567890123456789012",
              "snippet": {
                "title": "Example Channel",
                "description": "",
                "customUrl": "@example",
                "thumbnails": {
                  "default": { "url": "https://yt3.ggpht.com/example=s88" },
                  "medium": { "url": "https://yt3.ggpht.com/example=s240" },
                  "high": { "url": "https://yt3.ggpht.com/example=s800" }
                }
              }
            }
          ]
        }
        """

        let response = try JSONDecoder().decode(
            ChannelListResponse.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(
            response.items.first?.snippet.thumbnails.high?.url,
            "https://yt3.ggpht.com/example=s800"
        )
    }

    func testParsesShortLiveAndEmbedURLs() {
        let id = "5sTQfGJiVdc"
        XCTAssertEqual(VideoItem.fromYouTubeInput("https://youtu.be/\(id)")?.id, id)
        XCTAssertNil(VideoItem.fromYouTubeInput("https://youtube.com/shorts/\(id)"))
        XCTAssertEqual(VideoItem.fromYouTubeInput("https://youtube.com/live/\(id)")?.id, id)
        XCTAssertEqual(VideoItem.fromYouTubeInput("https://youtube.com/embed/\(id)")?.id, id)
        XCTAssertTrue(YouGlassContentPolicy.isShortsURL("https://youtube.com/shorts/\(id)"))
    }

    func testContentPolicyRecognizesShortsSignalsWithoutBlockingShortWords() {
        XCTAssertTrue(YouGlassContentPolicy.isShortsText("Quick tips #shorts"))
        XCTAssertTrue(YouGlassContentPolicy.isShortsText("YouTube Shorts compilation"))
        XCTAssertTrue(YouGlassContentPolicy.isShortsSearch("latest shorts"))
        XCTAssertFalse(YouGlassContentPolicy.isShortsText("A short film festival interview"))
    }

    func testRejectsUnsupportedOrMalformedInput() {
        XCTAssertNil(VideoItem.fromYouTubeInput("https://example.com/watch?v=5sTQfGJiVdc"))
        XCTAssertNil(VideoItem.fromYouTubeInput("too-short"))
        XCTAssertNil(VideoItem.fromYouTubeInput("invalid id!"))
    }

    func testVideoThumbnailFallsBackToYouTubeHostedImage() {
        let videoID = "5sTQfGJiVdc"
        let video = VideoItem(
            id: videoID,
            title: "Video",
            channel: "YouTube",
            views: "",
            age: "",
            duration: "",
            imageURL: nil,
            verified: false
        )

        XCTAssertEqual(
            video.thumbnailURL?.absoluteString,
            "https://i.ytimg.com/vi/\(videoID)/hqdefault.jpg"
        )
    }

    func testYouTubeAPIErrorClassifiesQuotaAndTransientFailures() {
        let quota = YouTubeAPIError.httpStatus(
            403,
            reason: "quotaExceeded",
            message: "The request cannot be completed because you have exceeded your quota."
        )
        XCTAssertFalse(quota.isRetryable)
        XCTAssertTrue(quota.localizedDescription.localizedCaseInsensitiveContains("quota"))

        let transient = YouTubeAPIError.httpStatus(503, reason: "backendError", message: "Temporary backend error")
        XCTAssertTrue(transient.isRetryable)
        XCTAssertTrue(transient.localizedDescription.localizedCaseInsensitiveContains("temporary"))

        let throttled = YouTubeAPIError.httpStatus(429, reason: "rateLimitExceeded", message: "Too many requests")
        XCTAssertFalse(throttled.isRetryable)
    }

    func testYouTubeAPIErrorExplainsAuthorizationFailures() {
        let unauthorized = YouTubeAPIError.httpStatus(401, reason: "authError", message: "Invalid Credentials")
        XCTAssertFalse(unauthorized.isRetryable)
        XCTAssertTrue(unauthorized.localizedDescription.localizedCaseInsensitiveContains("authorization"))
    }

    func testLocalCollectionDeduplicatesAndMutatesVideoIDs() {
        var collection = YouGlassLibraryCollection(
            name: "Research",
            videoIDs: ["one", "one", "two"]
        )

        XCTAssertEqual(collection.videoIDs, ["one", "two"])
        collection.add(videoID: "three")
        collection.add(videoID: "three")
        collection.remove(videoID: "one")

        XCTAssertEqual(collection.videoIDs, ["three", "two"])
    }

    func testThemeCustomizationNormalizesShortAndLongHexValues() {
        XCTAssertEqual(YouGlassThemeCustomization.normalizeHex(" #abc "), "#AABBCC")
        XCTAssertEqual(YouGlassThemeCustomization.normalizeHex("#4c8dff"), "#4C8DFF")
        XCTAssertNil(YouGlassThemeCustomization.normalizeHex("#12"))
        XCTAssertNil(YouGlassThemeCustomization.normalizeHex("#GGGGGG"))
    }
}
