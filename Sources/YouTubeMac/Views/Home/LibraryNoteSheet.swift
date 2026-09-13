import SwiftUI

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
