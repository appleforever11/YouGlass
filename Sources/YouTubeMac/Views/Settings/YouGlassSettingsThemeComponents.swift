import SwiftUI

struct ThemeControlSlider: View {
    let title: String
    let systemImage: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
            Slider(value: $value, in: range)
                .controlSize(.small)
                .accessibilityLabel(title)
                .accessibilityValue("\(Int(value * 100)) percent")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct YouGlassThemeCard: View {
    @EnvironmentObject private var store: YouTubeStore

    let theme: YouGlassThemeFamily
    let isSelected: Bool
    let action: () -> Void
    @State private var hovered = false

    private var cardColor: Color {
        theme.colors(isDark: store.colorScheme == .dark).card
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 6) {
                    YouGlassThemePreview(theme: theme, isDark: false)
                    YouGlassThemePreview(theme: theme, isDark: true)
                }
                .frame(height: 92)

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: theme.systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.colors(isDark: false).accent)
                        .frame(width: 24, height: 24)
                        .background(theme.colors(isDark: false).accent.opacity(0.13), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(theme.title)
                                .font(.system(size: 14, weight: .bold))
                                .lineLimit(1)
                            if let badgeTitle = theme.badgeTitle {
                                Text(badgeTitle)
                                    .font(.system(size: 8, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(theme.colors(isDark: false).secondary.opacity(0.20), in: Capsule())
                            }
                        }
                        Text(theme.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isSelected ? theme.colors(isDark: false).accent : Color.secondary.opacity(0.50))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 154, alignment: .topLeading)
            .background(cardColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected || hovered ? theme.colors(isDark: false).accent.opacity(0.78) : Color.secondary.opacity(0.18),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .shadow(
                color: isSelected ? theme.colors(isDark: false).accent.opacity(0.16) : .clear,
                radius: 12,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityLabel("\(theme.title), light and dark theme")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

struct YouGlassThemePreview: View {
    let theme: YouGlassThemeFamily
    let isDark: Bool

    private var colors: YouGlassThemeColors { theme.colors(isDark: isDark) }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                colors.window

                RadialGradient(
                    colors: [colors.primary.opacity(0.74), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: max(geometry.size.width, geometry.size.height) * 0.90
                )
                RadialGradient(
                    colors: [colors.secondary.opacity(0.62), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: max(geometry.size.width, geometry.size.height) * 0.82
                )

                if theme == .neoCitrus {
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { index in
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: index.isMultiple(of: 2)
                                            ? [colors.primary, colors.secondary]
                                            : [colors.secondary, colors.tertiary],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(
                                    height: index == 1 || index == 4
                                        ? geometry.size.height * 0.68
                                        : geometry.size.height * 0.88
                                )
                        }
                    }
                    .padding(7)
                    .opacity(isDark ? 0.70 : 0.82)
                }

                VStack {
                    HStack {
                        Spacer()
                        Text(isDark ? "DARK" : "LIGHT")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(colors.text)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(colors.card.opacity(0.88), in: Capsule())
                    }
                    Spacer()
                }
                .padding(7)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(colors.stroke, lineWidth: 1)
            }
        }
    }
}
