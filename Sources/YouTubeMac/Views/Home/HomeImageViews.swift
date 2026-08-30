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
        if let cached = YouGlassImageCache.shared.image(for: url) {
            loadedImage = Image(nsImage: cached)
            return
        }
        do {
            let data = try await YouGlassImageLoader.shared.data(for: url)
            guard !Task.isCancelled else { return }
            guard let image = NSImage(data: data) else {
                failed = true
                return
            }
            YouGlassImageCache.shared.insert(image, for: url)
            loadedImage = Image(nsImage: image)
        } catch {
            guard !Task.isCancelled else { return }
            failed = true
        }
    }
}

/// Coalesces duplicate thumbnail/avatar requests while the Home and player
/// surfaces are being assembled. The in-memory NSImage cache handles finished
/// requests; this actor handles the common case where several cards ask for
/// the same URL during one render pass.
private actor YouGlassImageLoader {
    static let shared = YouGlassImageLoader()

    private var inFlight: [URL: Task<Data, Error>] = [:]

    func data(for url: URL) async throws -> Data {
        if let existing = inFlight[url] {
            return try await existing.value
        }

        let task = Task { () throws -> Data in
            var request = URLRequest(
                url: url,
                cachePolicy: .returnCacheDataElseLoad,
                timeoutInterval: 12
            )
            request.setValue(
                "Mozilla/5.0 (Macintosh; Apple Silicon Mac OS X) AppleWebKit/605.1.15",
                forHTTPHeaderField: "User-Agent"
            )
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode else {
                throw URLError(.badServerResponse)
            }
            return data
        }
        inFlight[url] = task

        do {
            let data = try await task.value
            inFlight[url] = nil
            return data
        } catch {
            inFlight[url] = nil
            throw error
        }
    }
}

@MainActor
private final class YouGlassImageCache {
    static let shared = YouGlassImageCache()

    private let cache = NSCache<NSURL, NSImage>()

    private init() {
        cache.countLimit = 180
        cache.totalCostLimit = 80 * 1024 * 1024
    }

    func image(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: NSImage, for url: URL) {
        let cost = max(1, Int(image.size.width * image.size.height * 4))
        cache.setObject(image, forKey: url as NSURL, cost: cost)
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
            .padding(.vertical, 22)
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
            .scaleEffect(isPressed ? 0.92 : (isHovered ? 1.04 : 1))
            .animation(.easeOut(duration: 0.13), value: isHovered)
            .animation(.easeOut(duration: 0.10), value: isPressed)
            .contentShape(Circle())
            .onHover { isHovered = $0 }
    }
}
