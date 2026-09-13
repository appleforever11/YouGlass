import SwiftUI

struct PersonalLibraryView: View {
    @EnvironmentObject private var store: YouTubeStore
    let palette: Palette
    let compact: Bool
    @State private var showingNewCollection = false
    @State private var newCollectionName = ""
    @State private var showingNewNote = false
    @State private var librarySection = "Overview"
    @State private var libraryQuery = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Library")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Your saved videos, collections, and notes. Always available on this Mac.")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 12) {
                    Button {
                        showingNewNote = true
                    } label: {
                        Label("New note", systemImage: "note.text.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    Button {
                        newCollectionName = ""
                        showingNewCollection = true
                    } label: {
                        Label("New collection", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .controlSize(.large)
                .tint(palette.accent)
            }
            .padding(.top, 20)

            Picker("Library section", selection: $librarySection) {
                ForEach(["Overview", "Saved", "Liked", "Collections", "Notes"], id: \.self) {
                    Text($0).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier("library-section-picker")

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(palette.secondaryText)
                TextField("Find a video in your library", text: $libraryQuery)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search local library")
                if !libraryQuery.isEmpty {
                    Button { libraryQuery = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear library search")
                }
            }
            .padding(12)
            .background(palette.search, in: RoundedRectangle(cornerRadius: 12))

            if !libraryQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let matches = YouGlassLibrarySearch.videos(matching: libraryQuery, in: personalVideos)
                if matches.isEmpty {
                    YouGlassEmptyState(title: "No matching videos", message: "Try another title or channel in your saved videos and history.", symbol: "magnifyingglass", palette: palette, actionTitle: "Clear search") { libraryQuery = "" }
                } else {
                    VideoRow(title: "In your library", videos: matches, palette: palette, compact: compact, showsSeeAll: false)
                }
            } else {

                if librarySection == "Overview", store.showContinueWatching, !store.continueWatching.isEmpty {
                    ContinueWatchingRow(palette: palette, compact: compact)
                }

                if librarySection == "Overview" || librarySection == "Saved", !store.savedVideos.isEmpty {
                    VideoRow(
                        title: "Watch Later",
                        videos: librarySection == "Saved" ? store.savedVideos : Array(store.savedVideos.prefix(8)),
                        palette: palette,
                        compact: compact,
                        showsSeeAll: false
                    )
                }

                if librarySection == "Overview" || librarySection == "Liked", !store.locallyLikedVideos.isEmpty {
                    VideoRow(
                        title: "Liked on this Mac",
                        videos: librarySection == "Liked" ? store.locallyLikedVideos : Array(store.locallyLikedVideos.prefix(8)),
                        palette: palette,
                        compact: compact,
                        showsSeeAll: false
                    )
                }

                if librarySection == "Overview" || librarySection == "Collections", !store.customCollections.isEmpty {
                    collectionsSection
                }

                if librarySection == "Overview" || librarySection == "Notes" {
                    notesSection
                }

                if (librarySection == "Saved" && store.savedVideos.isEmpty)
                    || (librarySection == "Liked" && store.locallyLikedVideos.isEmpty)
                    || (librarySection == "Collections" && store.customCollections.isEmpty) {
                    YouGlassEmptyState(
                        title: librarySection == "Collections" ? "Make room for your favorites" : librarySection == "Saved" ? "Watch on your own time" : "Keep your favorites close",
                        message: librarySection == "Collections" ? "Group videos by topic, project, or mood. Add videos using a card’s context menu." : librarySection == "Saved" ? "Save a video to Watch Later from its context menu or the player’s bookmark button." : "Like a video in the player to find it here again.",
                        symbol: librarySection == "Collections" ? "folder" : librarySection == "Saved" ? "bookmark" : "heart",
                        palette: palette,
                        actionTitle: librarySection == "Collections" ? "New collection" : "Discover videos"
                    ) {
                        if librarySection == "Collections" {
                            newCollectionName = ""
                            showingNewCollection = true
                        } else { store.showSection("Home") }
                    }
                }

                if librarySection == "Overview", store.savedVideos.isEmpty,
                   store.locallyLikedVideos.isEmpty,
                   store.customCollections.isEmpty,
                   store.videoNotes.isEmpty,
                   store.continueWatching.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 30))
                            .foregroundStyle(palette.secondaryText)
                        Text("Your library is ready")
                            .font(.headline)
                        Text("Save a video, create a collection, or add a note while watching.")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .alert("New collection", isPresented: $showingNewCollection) {
            TextField("Collection name", text: $newCollectionName)
            Button("Create") {
                _ = store.createCollection(named: newCollectionName)
            }
            .disabled(newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Use collections to organize saved videos locally on this Mac.")
        }
        .sheet(isPresented: $showingNewNote) {
            LibraryNoteSheet(palette: palette)
                .environmentObject(store)
        }
    }

    private var personalVideos: [VideoItem] {
        let ids = Set((store.recentlyWatched + store.savedVideos + store.locallyLikedVideos + store.playbackQueue).map(\.id))
            .union(store.customCollections.flatMap(\.videoIDs))
            .union(store.videoNotes.map(\.videoID))
        return store.libraryVideoCatalog.filter { ids.contains($0.id) }
    }

    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Collections")
                .font(.system(size: 19, weight: .bold))

            ForEach(store.customCollections) { collection in
                let videos = store.videos(in: collection)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(collection.name, systemImage: "folder.fill")
                            .font(.headline)
                        Spacer()
                        Text("\(collection.videoIDs.count) videos")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryText)
                        Button {
                            store.deleteCollection(collection)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Delete collection")
                    }
                    if videos.isEmpty {
                        Text("Add videos from any card's context menu.")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)
                            .padding(.vertical, 12)
                    } else {
                        VideoRow(
                            title: collection.name,
                            videos: Array(videos.prefix(8)),
                            palette: palette,
                            compact: compact,
                            showsSeeAll: false
                        )
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Notes")
                    .font(.system(size: 19, weight: .bold))
                Spacer()
                if !store.videoNotes.isEmpty {
                    Button("Add note") { showingNewNote = true }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondaryText)
                }
            }

            if store.videoNotes.isEmpty {
                Text("Capture ideas and timestamps from the player with a local note.")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            } else {
                ForEach(librarySection == "Notes" ? store.videoNotes : Array(store.videoNotes.prefix(12))) { note in
                    let video = store.libraryVideoCatalog.first { $0.id == note.videoID }
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "note.text")
                            .foregroundStyle(palette.accent)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(video?.title ?? "Saved video")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(note.text)
                                .font(.subheadline)
                                .foregroundStyle(palette.secondaryText)
                                .lineLimit(3)
                            if let timestamp = note.timestamp, timestamp > 0 {
                                Text("At \(Int(timestamp) / 60):\(String(format: "%02d", Int(timestamp) % 60))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(palette.tertiaryText)
                            }
                        }
                        Spacer(minLength: 0)
                        Button {
                            store.deleteNote(note)
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(palette.secondaryText)
                    }
                    .padding(12)
                    .background(palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
}
