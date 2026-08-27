import SwiftUI

private struct YouGlassPaletteCommand: Identifiable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let shortcut: String?
    let action: () -> Void
}

struct CommandPaletteView: View {
    @EnvironmentObject private var store: YouTubeStore
    let palette: Palette
    let dismiss: () -> Void
    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var searchFocused: Bool

    private var commands: [YouGlassPaletteCommand] {
        var result: [YouGlassPaletteCommand] = [
            command("home", "Go to Home", "Open your personalized home feed", "house.fill") { store.showSection("Home") },
            command("library", "Open Library", "Collections, notes, and local history", "books.vertical") { store.showSection("Library") },
            command("watch-later", "Open Watch Later", "Show videos saved for later", "bookmark.fill") { store.showSection("Watch Later") },
            command("history", "Open History", "Show videos watched on this Mac", "clock.fill") { store.showSection("History") },
            command("subscriptions", "Open Subscriptions", "See recent uploads from subscribed channels", "person.2.fill") { store.showSection("Subscriptions") },
            command("refresh", "Refresh recommendations", "Fetch fresh feed data", "arrow.clockwise", "⌘R") { Task { await store.loadHome(force: true) } },
            command("theme", "Cycle visual theme", "Move to the next Theme Center environment", "paintbrush.pointed.fill") { store.cycleVisualTheme() }
        ]

        if store.selectedVideo != nil {
            result.insert(
                command("play-pause", "Play or Pause", "Control the selected video", "playpause.fill", "Space") {
                    store.sendPlaybackCommand(.togglePlayback)
                },
                at: 0
            )
            result.insert(
                command("next", "Play next in queue", "Advance to the next queued video", "forward.fill", "N") {
                    store.playNextInQueue()
                },
                at: 1
            )
            result.insert(
                command("previous", "Play previous in queue", "Return to the previous queued video", "backward.fill", "P") {
                    store.playPreviousInQueue()
                },
                at: 2
            )
            result.insert(
                command("save", store.isSaved(store.selectedVideo!) ? "Remove from Watch Later" : "Save to Watch Later", "Keep this video in your local library", "bookmark.fill") {
                    store.toggleSaved(store.selectedVideo!)
                },
                at: 3
            )
            result.insert(
                command("pip", "Open Picture in Picture", "Float the selected video above other windows", "pip.enter") {
                    store.presentDesktopPIP()
                },
                at: 4
            )
            result.insert(
                command("mini", "Minimize player", "Keep playback in the in-app mini-player", "minus") {
                    store.minimizePlayer()
                },
                at: 5
            )
            result.insert(
                command("fullscreen", "Toggle full screen", "Expand the main window", "arrow.up.left.and.arrow.down.right") {
                    store.toggleMainWindowFullScreen()
                },
                at: 6
            )
        }

        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return result }
        return result.filter {
            $0.title.localizedCaseInsensitiveContains(normalizedQuery) ||
                $0.detail.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "command")
                    .foregroundStyle(palette.accent)
                TextField("Type a command...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium))
                    .focused($searchFocused)
                    .onSubmit(runSelectedCommand)
                Text("Esc")
                    .font(.caption.monospaced())
                    .foregroundStyle(palette.secondaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(palette.queueCard, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .padding(11)
            .background(palette.search, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(palette.stroke, lineWidth: 1)
            }

            if commands.isEmpty {
                Text("No matching commands")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(commands.enumerated()), id: \.element.id) { index, item in
                            Button {
                                item.action()
                                dismiss()
                            } label: {
                                HStack(spacing: 11) {
                                    Image(systemName: item.systemImage)
                                        .frame(width: 22)
                                        .foregroundStyle(index == selectedIndex ? palette.accent : palette.secondaryText)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(palette.text)
                                        Text(item.detail)
                                            .font(.caption)
                                            .foregroundStyle(palette.secondaryText)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 8)
                                    if let shortcut = item.shortcut {
                                        Text(shortcut)
                                            .font(.caption.monospaced())
                                            .foregroundStyle(palette.tertiaryText)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(index == selectedIndex ? palette.selected : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 330)
            }
        }
        .padding(14)
        .frame(width: 560)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.34), radius: 30, y: 14)
        .onAppear {
            searchFocused = true
        }
        .onChange(of: query) { _, _ in
            selectedIndex = 0
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onKeyPress(.downArrow) {
            guard !commands.isEmpty else { return .ignored }
            selectedIndex = min(selectedIndex + 1, commands.count - 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            guard !commands.isEmpty else { return .ignored }
            selectedIndex = max(selectedIndex - 1, 0)
            return .handled
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Command palette")
    }

    private func command(
        _ id: String,
        _ title: String,
        _ detail: String,
        _ systemImage: String,
        _ shortcut: String? = nil,
        action: @escaping () -> Void
    ) -> YouGlassPaletteCommand {
        YouGlassPaletteCommand(
            id: id,
            title: title,
            detail: detail,
            systemImage: systemImage,
            shortcut: shortcut,
            action: action
        )
    }

    private func runSelectedCommand() {
        guard commands.indices.contains(selectedIndex) else { return }
        commands[selectedIndex].action()
        dismiss()
    }
}
