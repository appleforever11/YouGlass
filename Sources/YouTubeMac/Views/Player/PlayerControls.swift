import SwiftUI

struct PlaybackScrubber: View {
    @Binding var value: Double
    let duration: Double
    let elapsedLabel: String
    let durationLabel: String
    let onEditingChanged: (Bool) -> Void
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geometry in
                let width = max(geometry.size.width, 1)
                let progress = min(max(value / max(duration, 1), 0), 1)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.24))
                        .frame(height: 7)

                    Capsule()
                        .fill(.white)
                        .frame(width: max(18, width * progress), height: 7)

                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                        .offset(x: max(0, min(width - 20, width * progress - 10)))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            if !isDragging {
                                isDragging = true
                                onEditingChanged(true)
                            }
                            value = value(at: gesture.location.x, width: width)
                        }
                        .onEnded { gesture in
                            value = value(at: gesture.location.x, width: width)
                            isDragging = false
                            onEditingChanged(false)
                        }
                )
            }
            .frame(height: 30)

            HStack {
                Text(elapsedLabel)
                Spacer()
                Text(durationLabel)
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.75))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Video progress")
        .accessibilityValue("\(elapsedLabel) of \(durationLabel)")
        .accessibilityAdjustableAction { direction in
            let step = max(5, duration / 100)
            onEditingChanged(true)
            switch direction {
            case .increment:
                value = min(duration, value + step)
            case .decrement:
                value = max(0, value - step)
            @unknown default:
                break
            }
            onEditingChanged(false)
        }
    }

    private func value(at x: CGFloat, width: CGFloat) -> Double {
        let progress = min(max(x / max(width, 1), 0), 1)
        return progress * max(duration, 1)
    }
}

struct PlayerControlButton: View {
    let symbol: String
    let help: String
    var isEnabled = true
    var controlSize: CGFloat = 38
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: controlSize < 36 ? 13 : 15, weight: .bold))
                .frame(width: controlSize, height: controlSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.42))
        .youGlassControlSurface()
        .overlay {
            // Keep the native transport legible over bright footage while
            // preserving the underlying Liquid Glass refraction.
            Circle()
                .fill(Color.black.opacity(0.28))
                .allowsHitTesting(false)
        }
        .overlay {
            Circle()
                .stroke(.white.opacity(0.52), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(.white.opacity(0.20))
                .frame(width: 16, height: 4)
                .blur(radius: 2)
                .offset(x: 8, y: 7)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.24), radius: 8, y: 3)
        .contentShape(Circle())
        .disabled(!isEnabled)
        .accessibilityIdentifier(
            "player-control-" + help
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
        )
        .accessibilityLabel(help)
        .help(help)
    }
}

/// The compact player controls sit directly over arbitrary YouTube imagery.
/// A generic thin material can disappear over dark footage, so the window
/// controls use a stable black-glass contrast layer while retaining a glossy
/// border and a generous pointer target.
struct PIPWindowControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .youGlassControlSurface()
            .overlay {
                Circle()
                    .fill(Color.black.opacity(0.28))
                    .allowsHitTesting(false)
            }
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.52), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) {
                Capsule()
                    .fill(.white.opacity(0.20))
                    .frame(width: 14, height: 4)
                    .blur(radius: 2)
                    .offset(x: 7, y: 6)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.24), radius: 8, y: 3)
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .contentShape(Circle())
    }
}

private extension View {
    func youGlassControlSurface() -> some View {
        background {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Circle()
                        .fill(.white.opacity(0.10))
                }
        }
    }
}
