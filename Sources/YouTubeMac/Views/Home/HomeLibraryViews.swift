import SwiftUI

struct ContinueWatchingRow: View {
    @EnvironmentObject private var store: YouTubeStore
    let palette: Palette
    let compact: Bool

    var body: some View {
        let columns = Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: 18),
            count: compact ? 2 : 4
        )

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(palette.accent)
                Text("Continue Watching")
                    .font(.system(size: 19, weight: .bold))
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
    let video: VideoItem
    let palette: Palette

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

                    if store.playbackPosition(for: video.id) > 1 {
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
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .buttonStyle(.plain)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Library")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Local collections, notes, and playback history stay available even when YouTube is offline.")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
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

            if store.showContinueWatching, !store.continueWatching.isEmpty {
                ContinueWatchingRow(palette: palette, compact: compact)
            }

            if !store.savedVideos.isEmpty {
                VideoRow(
                    title: "Watch Later",
                    videos: Array(store.savedVideos.prefix(8)),
                    palette: palette,
                    compact: compact,
                    showsSeeAll: false
                )
            }

            if !store.locallyLikedVideos.isEmpty {
                VideoRow(
                    title: "Liked on this Mac",
                    videos: Array(store.locallyLikedVideos.prefix(8)),
                    palette: palette,
                    compact: compact,
                    showsSeeAll: false
                )
            }

            if !store.customCollections.isEmpty {
                collectionsSection
            }

            notesSection

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
                ForEach(Array(store.videoNotes.prefix(12))) { note in
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
