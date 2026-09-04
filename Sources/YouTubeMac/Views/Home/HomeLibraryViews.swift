import SwiftUI

struct ContinueWatchingRow: View {
    @EnvironmentObject private var store: YouTubeStore
    let palette: Palette
    let compact: Bool

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 260), spacing: 18)]

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Continue Watching")
                            .font(.system(size: 19, weight: .bold))
                        Text("\(store.continueWatching.count)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(palette.secondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(palette.pill, in: Capsule())
                    }
                    Text("Pick up right where you left off")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                Button("View Library") {
                    store.showSection("Library")
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                ForEach(Array(store.continueWatching.prefix(8))) { video in
                    ContinueWatchingCard(video: video, palette: palette)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Continue watching")
    }
}

struct ContinueWatchingCard: View {
    @EnvironmentObject private var store: YouTubeStore
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    let video: VideoItem
    let palette: Palette
    @State private var isHovered = false

    var body: some View {
        Button {
            store.openFromUserInteraction(video)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    YouGlassVideoPreview {
                        RemoteImage(url: video.thumbnailURL)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.32)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    Image(systemName: "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(.black.opacity(0.62), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.56), lineWidth: 1))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .opacity(isHovered ? 1 : 0)
                        .scaleEffect(isHovered ? 1 : 0.82)
                        .allowsHitTesting(false)

                    if store.hasResumeCheckpoint(for: video.id) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.25))
                                Capsule()
                                    .fill(palette.accent)
                                    .frame(width: geometry.size.width * store.playbackProgress(for: video))
                            }
                            .frame(height: 5)
                        }
                        .frame(height: 5)
                        .padding(8)
                    }
                }

                Text(video.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .lineLimit(2)
                    .frame(height: 36, alignment: .topLeading)

                HStack(spacing: 5) {
                    Image(systemName: "arrow.uturn.forward.circle.fill")
                    Text(resumeLabel)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(isHovered ? palette.card.opacity(palette.isDark ? 0.82 : 0.72) : .clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(isHovered ? palette.stroke : .clear, lineWidth: 1)
            }
            .scaleEffect(accessibilityReduceMotion ? 1 : (isHovered ? 1.012 : 1))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            guard isHovered != hovering else { return }
            isHovered = hovering
            if hovering { store.prewarmPlayback(for: video) }
        }
        .shadow(color: isHovered ? .black.opacity(palette.isDark ? 0.30 : 0.10) : .clear, radius: 14, y: 7)
        .animation(accessibilityReduceMotion ? nil : .easeOut(duration: 0.16), value: isHovered)
        .accessibilityLabel("Resume \(video.title) from \(resumeLabel)")
        .contextMenu {
            Button("Remove from Continue Watching") {
                store.clearPlaybackPosition(for: video)
            }
            Button(store.isSaved(video) ? "Remove from Watch Later" : "Save to Watch Later") {
                store.toggleSaved(video)
            }
        }
    }

    private var resumeLabel: String {
        let position = store.playbackPosition(for: video.id)
        guard position > 0 else { return "Resume video" }
        let minutes = Int(position) / 60
        let seconds = Int(position) % 60
        return String(format: "Resume at %d:%02d", minutes, seconds)
    }
}

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
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Local collections, notes, and playback history stay available even when YouTube is offline.")
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
            }
            .padding(.top, 20)

            Picker("Library section", selection: $librarySection) {
                ForEach(["Overview", "Saved", "Liked", "Collections", "Notes"], id: \.self) {
                    Text($0).tag($0)
                }
            }
            .pickerStyle(.segmented)
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
                    Text("No videos in your library match “\(libraryQuery)”.")
                        .foregroundStyle(palette.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 140)
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
                    Text("Nothing here yet. Save a video, like a video, or create your first collection.")
                        .foregroundStyle(palette.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 140)
                }

                if store.savedVideos.isEmpty,
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

struct LibraryNoteSheet: View {
    @EnvironmentObject private var store: YouTubeStore
    @Environment(\.dismiss) private var dismiss
    let palette: Palette
    @State private var selectedVideoID = ""
    @State private var noteText = ""

    private var videos: [VideoItem] { store.libraryVideoCatalog }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New video note")
                .font(.title2.weight(.bold))
            if videos.isEmpty {
                Text("Watch or save a video first, then you can attach a note to it.")
                    .foregroundStyle(palette.secondaryText)
                Button("Done") { dismiss() }
            } else {
                Picker("Video", selection: $selectedVideoID) {
                    ForEach(videos) { video in
                        Text(video.title).tag(video.id)
                    }
                }
                TextEditor(text: $noteText)
                    .font(.body)
                    .frame(minHeight: 130)
                    .padding(6)
                    .background(palette.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                HStack {
                    Spacer()
                    Button("Cancel") { dismiss() }
                    Button("Save note") {
                        guard let video = videos.first(where: { $0.id == selectedVideoID }) else { return }
                        let position = store.playbackPosition(for: video.id)
                        _ = store.addNote(to: video, text: noteText, timestamp: position > 0 ? position : nil)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(24)
        .frame(width: 520)
        .frame(minHeight: 260)
        .onAppear {
            if selectedVideoID.isEmpty { selectedVideoID = videos.first?.id ?? "" }
        }
    }
}
