import AppKit
import SwiftUI

struct SearchField: View {
    @Binding var text: String
    let palette: Palette
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Search videos, channels, topics...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .onSubmit(onSubmit)
                .accessibilityLabel("Search YouTube")

            Button(action: onSubmit) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .medium))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Search")
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
                .stroke(palette.stroke, lineWidth: 1)
                .allowsHitTesting(false)
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
            let (data, _) = try await URLSession.shared.data(from: url)
            guard !Task.isCancelled, let image = NSImage(data: data) else {
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
        configuration.label
            .foregroundStyle(palette.text)
            .frame(width: 34, height: 34)
            .background(configuration.isPressed ? palette.selected : .clear)
            .clipShape(Circle())
    }
}
