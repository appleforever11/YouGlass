import SwiftUI

private struct PlaybackSpeedOption: Identifiable {
    let id: String
    let rate: Double
    let title: String
    let detail: String

    var compactTitle: String {
        rate == 1 ? "1×" : title
    }
}

struct PlaybackSpeedMenu: View {
    let palette: Palette
    @ObservedObject var playbackController: YouTubePlaybackController
    let onSelect: (Double) -> Void

    @State private var isPresented = false

    private static let options = [
        PlaybackSpeedOption(id: "0.75", rate: 0.75, title: "0.75×", detail: "Slower pace"),
        PlaybackSpeedOption(id: "1", rate: 1, title: "Normal", detail: "Default speed"),
        PlaybackSpeedOption(id: "1.25", rate: 1.25, title: "1.25×", detail: "A little faster"),
        PlaybackSpeedOption(id: "1.5", rate: 1.5, title: "1.5×", detail: "Faster pace"),
        PlaybackSpeedOption(id: "2", rate: 2, title: "2×", detail: "Double speed")
    ]

    private var selectedOption: PlaybackSpeedOption {
        Self.options.first(where: { abs($0.rate - playbackController.playbackRate) < 0.01 }) ?? Self.options[1]
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "speedometer")
                Text(selectedOption.compactTitle)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .frame(minWidth: 70)
        }
        .buttonStyle(PlayerHeaderControlButtonStyle(palette: palette, minimumWidth: 70))
        .accessibilityIdentifier("playback-speed-button")
        .accessibilityLabel("Playback speed")
        .accessibilityValue(selectedOption.title)
        .help("Playback speed: \(selectedOption.title)")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            playbackSpeedPopover
        }
    }

    private var playbackSpeedPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "speedometer")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Playback speed")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.text)
                    Text("Adjust the video tempo")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer(minLength: 8)

                Text(selectedOption.title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.accent)
            }

            Divider()
                .overlay(palette.stroke.opacity(0.45))

            VStack(spacing: 4) {
                ForEach(Self.options) { option in
                    speedOptionButton(option)
                }
            }
        }
        .padding(12)
        .frame(width: 238)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.stroke.opacity(0.78), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 20, y: 8)
    }

    private func speedOptionButton(_ option: PlaybackSpeedOption) -> some View {
        let isSelected = option.rate == selectedOption.rate

        return Button {
            onSelect(option.rate)
            isPresented = false
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? palette.accent : palette.secondaryText)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.text)
                    Text(option.detail)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer(minLength: 4)

                if isSelected {
                    Text("Active")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.accent)
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(isSelected ? palette.accent.opacity(0.16) : .clear)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("playback-speed-option-\(option.id)")
        .accessibilityLabel(option.title)
        .accessibilityHint(option.detail)
    }
}
