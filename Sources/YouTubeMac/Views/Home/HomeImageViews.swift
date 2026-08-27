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

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                LinearGradient(colors: [.gray.opacity(0.25), .gray.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .empty:
                Rectangle().fill(.gray.opacity(0.15))
            @unknown default:
                Rectangle().fill(.gray.opacity(0.15))
            }
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
