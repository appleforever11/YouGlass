import Combine
import XCTest
@testable import YouTubeMac

final class ReleaseReliabilityTests: XCTestCase {
    @MainActor
    func testOfflineSearchUsesRealLibraryWithoutCallingServicesOrChangingHome() async {
        let fixture = makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let store = fixture.store
        let video = makeVideo(1, title: "Café camera review", channel: "Glass Studio")
        store.savedVideos = [video]
        let originalFeed = feedIDs(store.feed)
        store.isNetworkAvailable = false
        await store.search("CAFE Studio")
        XCTAssertEqual(store.searchResults, [video])
        XCTAssertEqual(feedIDs(store.feed), originalFeed)
        XCTAssertEqual(fixture.service.credentialChecks, 0)
        XCTAssertEqual(fixture.service.webChecks, 0)
        XCTAssertFalse(store.searchState.isLoading)
        XCTAssertTrue(store.searchState.message.hasPrefix("Offline"))
        await store.search("missing local title")
        XCTAssertTrue(store.searchResults.isEmpty)
        XCTAssertEqual(feedIDs(store.feed), originalFeed)
        XCTAssertTrue(store.searchState.emptyMessage?.contains("offline") == true)
    }

    @MainActor
    func testLateSearchCannotReplaceLibraryAfterNavigation() async {
        let fixture = makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        fixture.store.startSearch("delayed")
        let retiredTask = fixture.store.sectionLoadTask
        await fixture.service.waitForRequest()
        fixture.store.showSection("Library")
        fixture.service.complete(with: [makeVideo(1)])
        await retiredTask?.value
        XCTAssertEqual(fixture.store.route, .destination(.library))
        XCTAssertTrue(fixture.store.searchResults.isEmpty)
        XCTAssertEqual(fixture.service.webChecks, 0)
        XCTAssertFalse(fixture.store.isLoading)
    }

    @MainActor
    func testAccountBoundaryRetiresDelayedSearchWithoutFallback() async {
        let fixture = makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        fixture.store.startSearch("delayed")
        let retiredTask = fixture.store.sectionLoadTask
        await fixture.service.waitForRequest()
        fixture.store.invalidateAccountRequests()
        fixture.service.complete(with: [makeVideo(1)])
        await retiredTask?.value
        XCTAssertTrue(fixture.store.searchResults.isEmpty)
        XCTAssertEqual(fixture.service.webChecks, 0)
        XCTAssertFalse(fixture.store.searchState.isLoading)
    }

    @MainActor
    func testSearchResultsPublishThroughFeatureStateWithoutReplacingFeed() {
        let fixture = makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let originalFeed = feedIDs(fixture.store.feed)
        var feedUpdates = 0
        let observation = fixture.store.$feed.dropFirst().sink { _ in feedUpdates += 1 }
        fixture.store.applySearchResults([makeVideo(2)], message: "YouTube search results")
        XCTAssertEqual(fixture.store.searchState.results.map(\.id), ["video-2"])
        XCTAssertEqual(feedIDs(fixture.store.feed), originalFeed)
        XCTAssertEqual(feedUpdates, 0)
        withExtendedLifetime(observation) {}
    }

    @MainActor
    func testViewportIdentitySeparatesCustomFeedsWithSameTitle() {
        let fixture = makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        fixture.store.selectedCustomFeedID = UUID()
        let first = fixture.store.route
        fixture.store.selectedCustomFeedID = UUID()
        XCTAssertNotEqual(first, fixture.store.route)
        fixture.store.selectedCustomFeedID = nil
        XCTAssertEqual(fixture.store.route, .destination(.home))
    }

    @MainActor
    func testQueueReorderingPreservesCurrentIdentityAndPersists() {
        let fixture = makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let videos = (1...3).map { makeVideo($0) }
        fixture.store.playbackQueue = videos
        fixture.store.selectedVideo = videos[0]
        fixture.store.moveQueuedVideo(videos[2], by: -1)
        XCTAssertEqual(fixture.store.nextQueuedVideo?.id, videos[2].id)
        XCTAssertEqual(fixture.store.selectedVideo?.id, videos[0].id)
        XCTAssertEqual(fixture.store.queueRepository.restore()?.videos.map(\.id), ["video-1", "video-3", "video-2"])
        fixture.store.moveQueuedVideo(videos[0], by: -1)
        XCTAssertEqual(fixture.store.playbackQueue.first?.id, videos[0].id)
    }

    @MainActor
    func testLocalLibraryAndCheckpointsSurviveIsolatedRelaunch() throws {
        let fixture = makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let video = makeVideo(7)
        fixture.store.toggleSaved(video)
        let collection = try XCTUnwrap(fixture.store.createCollection(named: "Release rehearsal"))
        fixture.store.add(video, toCollectionID: collection.id)
        let note = try XCTUnwrap(fixture.store.addNote(to: video, text: "Saved note", timestamp: 42))
        fixture.store.savePlaybackPosition(for: video, at: 42, duration: 600)
        let restored = YouTubeStore(defaults: fixture.defaults, client: YouTubeAPIClient(apiKey: nil),
                                    searchService: fixture.service, connectRuntime: false)
        XCTAssertEqual(restored.savedVideos, [video])
        XCTAssertEqual(restored.customCollections.first?.id, collection.id)
        XCTAssertEqual(restored.customCollections.first?.videoIDs, [video.id])
        XCTAssertEqual(restored.videoNotes.first?.id, note.id)
        XCTAssertEqual(restored.playbackPosition(for: video.id), 42)
        XCTAssertEqual(restored.playbackDuration(for: video.id), 600)
    }

    @MainActor
    func testCorruptCheckpointDataIsNotOverwrittenDuringStartup() {
        let fixture = makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let bytes = Data("{truncated".utf8)
        fixture.defaults.set(bytes, forKey: YouTubeStore.DefaultsKey.playbackPositions)
        let restored = YouTubeStore(defaults: fixture.defaults, client: YouTubeAPIClient(apiKey: nil),
                                    searchService: fixture.service, connectRuntime: false)
        XCTAssertTrue(restored.playbackPositions.isEmpty)
        XCTAssertEqual(fixture.defaults.data(forKey: YouTubeStore.DefaultsKey.playbackPositions), bytes)
    }

    func testQueueRepositoryReadsLegacyStateAndBoundsDuplicateEntries() throws {
        let suite = "YouGlass.Tests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = YouGlassQueueRepository(defaults: defaults, key: "queue")
        let videos = (1...40).map { makeVideo($0) }
        let encodedVideos = try JSONEncoder().encode([videos[0]] + videos)
        defaults.set(Data("{\"videos\":\(String(decoding: encodedVideos, as: UTF8.self)),\"autoplay\":false}".utf8), forKey: "queue")
        let restored = try XCTUnwrap(repository.restore())
        XCTAssertEqual(restored.videos.count, 24)
        XCTAssertEqual(restored.videos.map(\.id), Array(videos.prefix(24)).map(\.id))
        XCTAssertFalse(restored.autoplay)
        repository.save(restored)
        XCTAssertEqual(repository.restore(), restored)
        let object = try JSONSerialization.jsonObject(with: defaults.data(forKey: "queue")!) as! [String: Any]
        XCTAssertEqual(object["version"] as? Int, 1)
    }

    func testCorruptAndFutureQueuePayloadsArePreservedForRecovery() {
        let suite = "YouGlass.Tests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = YouGlassQueueRepository(defaults: defaults, key: "queue")
        for raw in ["{", "{\"version\":99,\"videos\":[],\"autoplay\":false}"] {
            let data = Data(raw.utf8)
            defaults.set(data, forKey: "queue")
            XCTAssertNil(repository.restore())
            XCTAssertEqual(defaults.data(forKey: "queue"), data)
        }
    }

    @MainActor
    private func makeFixture() -> (store: YouTubeStore, service: DelayedSearchService, defaults: UserDefaults, suite: String) {
        let suite = "YouGlass.Tests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        let service = DelayedSearchService()
        let store = YouTubeStore(defaults: defaults, client: YouTubeAPIClient(apiKey: nil),
                                searchService: service, connectRuntime: false)
        return (store, service, defaults, suite)
    }

    private func makeVideo(_ index: Int, title: String = "Video", channel: String = "Channel") -> VideoItem {
        VideoItem(id: "video-\(index)", title: title, channel: channel, views: "", age: "",
                  duration: "10:00", imageURL: nil, verified: false)
    }

    private func feedIDs(_ feed: HomeFeed) -> [String] {
        ([feed.hero] + feed.forYou + feed.trending + feed.more + feed.queue).map(\.id)
    }
}

@MainActor
private final class DelayedSearchService: YouGlassSearchService {
    var credentialChecks = 0
    var webChecks = 0
    private var request: CheckedContinuation<[VideoItem], Never>?
    private var started: CheckedContinuation<Void, Never>?

    func hasCredentials() async -> Bool { credentialChecks += 1; return true }
    func search(_ query: String) async throws -> [VideoItem] {
        await withCheckedContinuation { continuation in
            request = continuation
            started?.resume()
            started = nil
        }
    }
    func webSearch(_ query: String) async -> YouTubeWebFeedResult {
        webChecks += 1
        return .empty
    }
    func waitForRequest() async {
        if request != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func complete(with videos: [VideoItem]) {
        request?.resume(returning: videos)
        request = nil
    }
}
