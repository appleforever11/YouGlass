import Foundation

extension YouTubeStore {
    var libraryVideoCatalog: [VideoItem] {
        mergeVideos(
            recentlyWatched + savedVideos + locallyLikedVideos + playbackQueue +
                feed.forYou + feed.trending + feed.more + feed.queue
        )
    }

    func videos(in collection: YouGlassLibraryCollection) -> [VideoItem] {
        let catalog = libraryVideoCatalog
        return collection.videoIDs.compactMap { id in catalog.first { $0.id == id } }
    }

    @discardableResult
    func createCollection(named rawName: String) -> YouGlassLibraryCollection? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let collection = YouGlassLibraryCollection(name: String(name.prefix(64)))
        customCollections.insert(collection, at: 0)
        customCollections = Array(customCollections.prefix(40))
        persistLibrary()
        return collection
    }

    func deleteCollection(_ collection: YouGlassLibraryCollection) {
        customCollections.removeAll { $0.id == collection.id }
        persistLibrary()
    }

    func collectionContains(_ video: VideoItem, collectionID: UUID) -> Bool {
        customCollections.first { $0.id == collectionID }?.videoIDs.contains(video.id) == true
    }

    func add(_ video: VideoItem, toCollectionID collectionID: UUID) {
        guard let index = customCollections.firstIndex(where: { $0.id == collectionID }) else { return }
        customCollections[index].add(videoID: video.id)
        persistLibrary()
    }

    func remove(_ video: VideoItem, fromCollectionID collectionID: UUID) {
        guard let index = customCollections.firstIndex(where: { $0.id == collectionID }) else { return }
        customCollections[index].remove(videoID: video.id)
        persistLibrary()
    }

    func notes(for video: VideoItem) -> [YouGlassVideoNote] {
        videoNotes
            .filter { $0.videoID == video.id }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    @discardableResult
    func addNote(to video: VideoItem, text rawText: String, timestamp: Double? = nil) -> YouGlassVideoNote? {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let note = YouGlassVideoNote(videoID: video.id, text: String(text.prefix(2_000)), timestamp: timestamp)
        videoNotes.insert(note, at: 0)
        videoNotes = Array(videoNotes.prefix(200))
        persistLibrary()
        return note
    }

    func updateNote(_ note: YouGlassVideoNote, text rawText: String, timestamp: Double? = nil) {
        guard let index = videoNotes.firstIndex(where: { $0.id == note.id }) else { return }
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            deleteNote(note)
            return
        }
        videoNotes[index].text = String(text.prefix(2_000))
        videoNotes[index].timestamp = timestamp
        videoNotes[index].updatedAt = Date()
        persistLibrary()
    }

    func deleteNote(_ note: YouGlassVideoNote) {
        videoNotes.removeAll { $0.id == note.id }
        persistLibrary()
    }
}
