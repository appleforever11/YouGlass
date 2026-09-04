import SwiftUI

struct PlayerQueuePanel: View {
    @ObservedObject var store: YouTubeStore
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .foregroundStyle(palette.accent)
                Text("Queue")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                Text("\(store.playbackQueue.count)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(palette.selected, in: Capsule())
                Spacer()
                Button("Keep current") {
                    store.clearPlaybackQueue()
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
                .disabled(store.playbackQueue.count <= 1)
            }

            Toggle(
                "Play next automatically",
                isOn: Binding(
                    get: { store.queueAutoplay },
                    set: { store.setQueueAutoplay($0) }
                )
            )
            .font(.caption)

            Text("Select a video to jump ahead. Add more from any video card.")
                .font(.caption)
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if store.playbackQueue.isEmpty {
                Text("Your queue is empty")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            } else {
                YouGlassBoundedScrollView(accessibilityIdentifier: "queue-scroll") {
                    VStack(spacing: 6) {
                        ForEach(store.playbackQueue) { queuedVideo in
                            queueRow(queuedVideo)
                        }
                    }
                }
                .frame(height: min(max(CGFloat(store.playbackQueue.count) * 58, 80), 360))
            }
        }
        .padding(14)
        .frame(width: 320, alignment: .leading)
        .background(palette.window, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Playback queue")
    }

    @ViewBuilder
    private func queueRow(_ video: VideoItem) -> some View {
        let isCurrent = video.id == store.selectedVideo?.id
        HStack(spacing: 8) {
            Button {
                store.openFromUserInteraction(video)
            } label: {
                HStack(spacing: 8) {
                    RemoteImage(url: video.thumbnailURL)
                        .frame(width: 70, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(video.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)
                            .foregroundStyle(palette.text)
                        Text(video.channel)
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(1)
                        if isCurrent {
                            Text("NOW PLAYING")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(palette.accent)
                        }
                    }
                    Spacer(minLength: 0)
                    if isCurrent {
                        Image(systemName: "waveform")
                            .foregroundStyle(palette.accent)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                store.removeFromPlaybackQueue(video)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.secondaryText)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(video.title) from queue")
        }
        .padding(6)
        .background(isCurrent ? palette.selected : palette.queueCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
