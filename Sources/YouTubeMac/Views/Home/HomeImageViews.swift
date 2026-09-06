import AppKit
import SwiftUI

struct SearchField: View {
    @Binding var text: String
    let focusRequestID: UUID
    let palette: Palette
    let onSubmit: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isFocused ? palette.accent : palette.secondaryText)

            TextField("Search videos, channels, topics...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($isFocused)
                .onSubmit(onSubmit)
                .accessibilityLabel("Search YouTube")
                .accessibilityIdentifier("home-search-field")

            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(palette.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            } else if !isFocused {
                Text("⌘L")
                    .font(.caption2.monospaced())
                    .foregroundStyle(palette.tertiaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(palette.pill, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            }

            Button(action: onSubmit) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? palette.tertiaryText
                        : palette.accent)
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Run search")
        }
        .padding(.horizontal, 20)
        .frame(height: 42)
        .background(.thinMaterial)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .fill(palette.accent.opacity(palette.isDark ? 0.025 : 0.014))
                .allowsHitTesting(false)
        }
        .overlay {
            Capsule()
                .stroke(isFocused ? palette.accent.opacity(0.72) : palette.stroke, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: isFocused ? palette.accent.opacity(0.12) : .clear, radius: 10)
        .onChange(of: focusRequestID) { _, _ in
            isFocused = true
        }
    }
}

struct RemoteImage: View {
    let url: URL?
    @State private var loadedImage: Image?
    @State private var failed = false

    var body: some View {
        Group {
            if let loadedImage {
                loadedImage
                    .resizable()
                    .scaledToFill()
            } else if failed {
                LinearGradient(
                    colors: [.gray.opacity(0.25), .gray.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Rectangle().fill(.gray.opacity(0.15))
            }
        }
        .task(id: url) { await loadImage() }
    }

    @MainActor
    private func loadImage() async {
        loadedImage = nil
        failed = false
        guard let url else {
            failed = true
            return
        }
        do {
            let image = try await YouGlassImageLoader.shared.image(for: url)
            guard !Task.isCancelled else { return }
            loadedImage = Image(decorative: image, scale: 1)
        } catch {
            guard !Task.isCancelled else { return }
            failed = true
        }
    }
}

/// Keeps every video preview at a deterministic 16:9 size while its remote
/// image moves through loading, success, or failure states.
struct YouGlassVideoPreview<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .clipped()
    }
}

struct AsyncAvatar: View {
    let url: URL?

    var body: some View {
        RemoteImage(url: url)
            .background(
                LinearGradient(colors: [.red, .orange, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Circle())
    }
}

struct DividerLine: View {
    let palette: Palette

    var body: some View {
        Rectangle()
            .fill(palette.hairline)
            .frame(height: 1)
            .padding(.horizontal, 26)
            .padding(.vertical, 16)
    }
}

struct IconButtonStyle: ButtonStyle {
    let palette: Palette

    func makeBody(configuration: Configuration) -> some View {
        IconButtonStyleBody(
            label: configuration.label,
            isPressed: configuration.isPressed,
            palette: palette
        )
    }
}

private struct IconButtonStyleBody<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let palette: Palette
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        label
            .foregroundStyle(isHovered ? palette.accent : palette.text)
            .frame(width: 34, height: 34)
            .background {
                Circle()
                    .fill(isPressed
                        ? palette.selected
                        : (isHovered ? palette.selected.opacity(0.46) : .clear))
            }
            .overlay {
                Circle()
                    .stroke(isHovered ? palette.stroke : .clear, lineWidth: 1)
            }
            .scaleEffect(reduceMotion ? 1 : (isPressed ? 0.92 : (isHovered ? 1.04 : 1)))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.13), value: isHovered)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: isPressed)
            .contentShape(Circle())
            .onHover { isHovered = $0 }
    }
}
