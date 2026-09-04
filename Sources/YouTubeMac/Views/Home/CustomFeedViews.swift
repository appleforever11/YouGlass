import SwiftUI

struct CustomFeedStripView: View {
    @EnvironmentObject private var store: YouTubeStore
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom Feeds")
                        .font(.system(size: 15, weight: .bold))
                    Text("Describe what you want to watch")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer(minLength: 10)

                Button {
                    store.presentNewCustomFeedComposer()
                } label: {
                    Label("Create", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
                .accessibilityLabel("Create a custom feed")
            }

            if store.customFeeds.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                    Text("Build a private, focused feed from a sentence. Your prompt stays on this Mac.")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.customFeeds) { feed in
                            let isSelected = store.selectedCustomFeedID == feed.id
                            Button {
                                store.selectCustomFeed(feed)
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: isSelected ? "checkmark" : "line.3.horizontal.decrease.circle")
                                        .font(.caption.weight(.bold))
                                    Text(feed.name)
                                        .lineLimit(1)
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(isSelected ? palette.text : palette.secondaryText)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5)
                                .background(
                                    isSelected ? palette.selected : palette.search,
                                    in: Capsule()
                                )
                                .overlay {
                                    Capsule()
                                        .stroke(
                                            isSelected ? palette.accent.opacity(0.72) : palette.stroke,
                                            lineWidth: 1
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Custom feed: \(feed.name)")
                            .contextMenu {
                                Button("Edit Feed", systemImage: "pencil") {
                                    store.presentCustomFeedComposer(for: feed)
                                }
                                Button("Delete Feed", systemImage: "trash", role: .destructive) {
                                    store.deleteCustomFeed(feed)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.card.opacity(palette.isDark ? 0.62 : 0.70), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Custom feeds")
    }
}

struct CustomFeedDetailView: View {
    @EnvironmentObject private var store: YouTubeStore
    let palette: Palette
    let compact: Bool

    var body: some View {
        guard let feed = store.selectedCustomFeed else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(palette.accent)
                            Text(feed.name)
                                .font(.system(size: 23, weight: .bold))
                        }
                        Text("“\(feed.prompt)”")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(2)
                        Text(feed.intent.summary)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(palette.tertiaryText)
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: 7) {
                        Button {
                            store.refreshSelectedCustomFeed()
                        } label: {
                            Image(systemName: store.customFeedLoading ? "hourglass" : "arrow.clockwise")
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(GlassIconButtonStyle(palette: palette))
                        .disabled(store.customFeedLoading)
                        .accessibilityLabel("Refresh custom feed")

                        Button {
                            store.presentCustomFeedComposer(for: feed)
                        } label: {
                            Image(systemName: "pencil")
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(GlassIconButtonStyle(palette: palette))
                        .accessibilityLabel("Edit custom feed")

                        Button {
                            store.clearSelectedCustomFeed()
                        } label: {
                            Image(systemName: "xmark")
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(GlassIconButtonStyle(palette: palette))
                        .accessibilityLabel("Close custom feed")
                    }
                }

                if store.customFeedLoading {
                    ProgressView("Building this feed from YouTube…")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
                } else if !store.customFeedVideos.isEmpty {
                    VideoRow(
                        title: "Your Picks",
                        videos: store.customFeedVideos,
                        palette: palette,
                        compact: compact,
                        showsSeeAll: false
                    )
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(palette.accent)
                        Text(store.customFeedMessage ?? "No matching videos yet")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        Text("Try adding a topic, channel, or time range to the prompt.")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)
                            .multilineTextAlignment(.center)
                        Button("Try Again") {
                            store.refreshSelectedCustomFeed()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(palette.accent)
                    }
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .padding(24)
                    .youGlassSurface(palette: palette, cornerRadius: 16)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        )
    }
}

struct CustomFeedComposerView: View {
    @EnvironmentObject private var store: YouTubeStore
    @Environment(\.dismiss) private var dismiss
    let palette: Palette
    let initialFeed: YouGlassCustomFeed?
    @State private var name: String
    @State private var prompt: String
    @FocusState private var promptFocused: Bool

    init(palette: Palette, feed: YouGlassCustomFeed? = nil) {
        self.palette = palette
        initialFeed = feed
        _name = State(initialValue: feed?.name ?? "")
        _prompt = State(initialValue: feed?.prompt ?? "")
    }

    private var interpretedIntent: YouGlassCustomFeedIntent {
        YouGlassCustomFeedPromptInterpreter.interpret(prompt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 11) {
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundStyle(palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(initialFeed == nil ? "Create a Custom Feed" : "Edit Custom Feed")
                        .font(.title2.weight(.bold))
                    Text("Tell YouGlass what you want to watch.")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Name")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                TextField("Optional — generated from your prompt", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Prompt")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                TextEditor(text: $prompt)
                    .font(.system(size: 15))
                    .focused($promptFocused)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 118)
                    .background(palette.search, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(promptFocused ? palette.accent : palette.stroke, lineWidth: 1)
                    }
                    .accessibilityLabel("Custom feed prompt")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Try an example")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                HStack(spacing: 8) {
                    exampleButton("Long-form analysis from my subscriptions")
                    exampleButton("Fresh videos about Apple design this week")
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(palette.accent)
                Text(interpretedIntent.summary)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.selected.opacity(0.46), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            Text("Your prompt is interpreted locally. YouGlass uses its existing YouTube connection for results and keeps Shorts excluded.")
                .font(.caption2)
                .foregroundStyle(palette.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Cancel") {
                    close()
                }
                .keyboardShortcut(.cancelAction)
                Button(initialFeed == nil ? "Create Feed" : "Save Changes") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 570, height: 500)
        .background(palette.content)
        .task {
            await Task.yield()
            promptFocused = true
        }
    }

    private func exampleButton(_ value: String) -> some View {
        Button {
            prompt = value
        } label: {
            Text(value)
                .font(.caption)
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(palette.search, in: Capsule())
                .overlay { Capsule().stroke(palette.stroke, lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }

    private func save() {
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPrompt.isEmpty else { return }
        if let initialFeed {
            store.updateCustomFeed(initialFeed, name: name, prompt: cleanPrompt)
        } else {
            _ = store.createCustomFeed(name: name, prompt: cleanPrompt)
        }
        close()
    }

    private func close() {
        store.editingCustomFeedID = nil
        store.customFeedComposerPresented = false
        dismiss()
    }
}
