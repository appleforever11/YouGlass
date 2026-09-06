import SwiftUI
import AppKit
import Foundation

enum CompactPlayerMetrics {
    static let maxWidth: CGFloat = 380
    static let minimumWidth: CGFloat = 160
    static let aspectRatio: CGFloat = 16 / 9
    static let widthFraction: CGFloat = 0.38
    static let edgeInset: CGFloat = 16
}

struct YouTubePlayerOverlay: View {
    @EnvironmentObject private var store: YouTubeStore
    @State private var cornerMenuPresented = false
    @State private var compactChromeVisible = false
    @State private var compactChromePointerHovering = false
    @State private var compactChromeHideTask: Task<Void, Never>?
    let video: VideoItem
    let palette: Palette
    let isCompact: Bool
    var initialAvailableSize: CGSize? = nil
    let onCompactDragChanged: ((CGSize) -> Void)?
    let onCompactDragEnded: ((CGSize) -> Void)?

    var body: some View {
        ZStack {
            PlayerAmbientSurface(
                palette: palette,
                ambientPalette: store.ambientPalette,
                intensity: isCompact ? 0.82 : 1.15
            )

            NativeWatchScreen(
                watchAvailableSize: initialAvailableSize ?? CGSize(width: 900, height: 680),
                video: video,
                palette: palette,
                isCompact: isCompact,
                onCompactDragChanged: onCompactDragChanged,
                onCompactDragEnded: onCompactDragEnded,
                onPlayerHoverChanged: isCompact ? { isHovering in
                    handleCompactPlayerHover(isHovering)
                } : nil
            )
                .environmentObject(store)
                .id(video.id)
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // The full watch surface already owns the ambient backdrop. An
            // additional full-rect material here creates the dark rectangular
            // cap above the custom header when the window extends under its
            // hidden title bar. Keep the material only for compact PIP.
            .background {
                if isCompact {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: isCompact ? 18 : 0, style: .continuous))
            .overlay(alignment: .topLeading) {
                if isCompact {
                    HStack(spacing: 8) {
                        Button {
                            withAnimation(.easeOut(duration: 0.16)) {
                                cornerMenuPresented.toggle()
                            }
                        } label: {
                            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .buttonStyle(PIPWindowControlButtonStyle())
                        .contentShape(Circle())
                        .accessibilityIdentifier("pip-position-button")
                        .help("Move Picture in Picture")

                        Button(action: store.expandPlayer) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .buttonStyle(PIPWindowControlButtonStyle())
                        .accessibilityIdentifier("pip-expand-button")
                        .help("Expand player")

                        Button(action: store.dismissPlayer) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .buttonStyle(PIPWindowControlButtonStyle())
                        .accessibilityIdentifier("pip-close-button")
                        .help("Stop playback")
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .opacity(compactChromeVisible ? 1 : 0)
                    .allowsHitTesting(compactChromeVisible || cornerMenuPresented)
                    .accessibilityHidden(!compactChromeVisible && !cornerMenuPresented)
                    .animation(.easeOut(duration: 0.18), value: compactChromeVisible)
                    .zIndex(20)
                }
            }
            .overlay(alignment: .topLeading) {
                if isCompact, cornerMenuPresented {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Move player")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.text)

                        ForEach(CompactPlayerCorner.allCases) { corner in
                            Button {
                                store.setCompactPlayerCorner(corner)
                                withAnimation(.easeOut(duration: 0.16)) {
                                    cornerMenuPresented = false
                                }
                            } label: {
                                Label(
                                    corner.title,
                                    systemImage: corner == store.compactPlayerCorner
                                        ? "checkmark"
                                        : "rectangle"
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(palette.text)
                        }
                    }
                    .padding(10)
                    .frame(width: 150)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(palette.stroke, lineWidth: 1)
                            .allowsHitTesting(false)
                    }
                    .padding(.top, 54)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .zIndex(21)
                }
            }
            .overlay {
                if isCompact {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.stroke, lineWidth: 1)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard isCompact else { return }
                showCompactChrome()
            }
            .onDisappear {
                compactChromeHideTask?.cancel()
            }
            .contextMenu {
                if isCompact {
                    Button("Expand player", systemImage: "arrow.up.left.and.arrow.down.right", action: store.expandPlayer)
                    Button("Picture in Picture", systemImage: "pip.enter", action: store.presentDesktopPIP)
                    Divider()
                    Button("Stop playback", systemImage: "xmark", action: store.dismissPlayer)
                }
            }
    }

    private func handleCompactPlayerHover(_ isHovering: Bool) {
        compactChromePointerHovering = isHovering
        if isHovering {
            showCompactChrome()
        } else {
            scheduleCompactChromeHide(after: PlayerTransportLayout.compactControlExitGracePeriod)
        }
    }

    private func showCompactChrome() {
        compactChromeHideTask?.cancel()
        compactChromeVisible = true
        scheduleCompactChromeHide(after: 2.2)
    }

    private func scheduleCompactChromeHide(after seconds: Double) {
        compactChromeHideTask?.cancel()
        compactChromeHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled,
                  !compactChromePointerHovering,
                  !cornerMenuPresented else { return }
            compactChromeVisible = false
            compactChromeHideTask = nil
        }
    }
}

enum YouGlassVideoTitlePlacement {
    case header
    case detail

    var titleSize: CGFloat {
        switch self {
        case .header: 23
        case .detail: 25
        }
    }

    var titleWeight: Font.Weight {
        switch self {
        case .header: .black
        case .detail: .semibold
        }
    }

    var titleLineLimit: Int {
        switch self {
        case .header: 2
        case .detail: 3
        }
    }

    var eyebrowSize: CGFloat {
        switch self {
        case .header: 10
        case .detail: 12
        }
    }

    var channelSize: CGFloat {
        switch self {
        case .header: 12
        case .detail: 14
        }
    }
}

/// Shared title hierarchy for the fixed watch header and the detail title.
/// Keeping the foregrounds in the active palette avoids the default macOS
/// label color fighting a custom light/dark theme.
struct YouGlassVideoTitleBlock: View {
    let title: String
    let channel: String
    let eyebrow: String?
    let palette: Palette
    let placement: YouGlassVideoTitlePlacement

    var body: some View {
        VStack(alignment: .leading, spacing: placement == .header ? 3 : 7) {
            if placement == .header {
                titleLabel
                eyebrowLabel
                channelLabel
            } else {
                eyebrowLabel
                titleLabel
                channelLabel
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var titleLabel: some View {
        if placement == .header {
            titleBase
                .foregroundStyle(palette.accent)
                .shadow(
                    color: palette.accent.opacity(palette.isDark ? 0.18 : 0.10),
                    radius: 3,
                    y: 1
                )
        } else {
            titleBase
                .foregroundStyle(palette.text)
        }
    }

    private var titleBase: some View {
        Text(title)
            .font(.system(size: placement.titleSize, weight: placement.titleWeight, design: .rounded))
            .lineLimit(placement.titleLineLimit)
            .lineSpacing(placement == .header ? -2 : 2)
            .minimumScaleFactor(placement == .header ? 0.84 : 0.76)
            .allowsTightening(placement == .header)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
    }

    @ViewBuilder
    private var eyebrowLabel: some View {
        if let eyebrow {
            Text(eyebrow.uppercased())
                .font(.system(size: placement.eyebrowSize, weight: .bold, design: .rounded))
                .foregroundStyle(
                    placement == .header
                        ? palette.accent.opacity(0.82)
                        : palette.secondaryText
                )
                .tracking(placement == .header ? 1.4 : 0)
        }
    }

    private var channelLabel: some View {
        Text(channel)
            .font(.system(size: placement.channelSize, weight: .medium, design: .rounded))
            .foregroundStyle(palette.secondaryText.opacity(0.86))
            .lineLimit(1)
            .truncationMode(.tail)
    }

}
