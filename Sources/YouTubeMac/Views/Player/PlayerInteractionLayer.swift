import SwiftUI

/// Handles only the empty center of the player. Its frame is explicitly
/// bounded away from the top PIP chrome and bottom transport, so SwiftUI
/// buttons remain the direct hit-test owners instead of competing with a
/// transparent full-window gesture layer.
struct PlayerInteractionLayer: View {
    let isCompact: Bool
    let reservedTop: CGFloat
    let reservedBottom: CGFloat
    let onTap: () -> Void
    let onCompactDragChanged: ((CGSize) -> Void)?
    let onCompactDragEnded: ((CGSize) -> Void)?
    @State private var didDrag = false

    var body: some View {
        GeometryReader { geometry in
            let bands = interactiveBands(for: geometry.size.height)
            let centerHeight = max(24, geometry.size.height - bands.top - bands.bottom)

            if isCompact {
                interactionRegion(
                    width: geometry.size.width,
                    height: centerHeight,
                    top: bands.top
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let distance = hypot(value.translation.width, value.translation.height)
                            guard didDrag || distance >= 6 else { return }
                            didDrag = true
                            onCompactDragChanged?(value.translation)
                        }
                        .onEnded { value in
                            defer { didDrag = false }
                            if didDrag {
                                onCompactDragEnded?(value.translation)
                            } else {
                                onTap()
                            }
                        }
                )
            } else {
                // A zero-distance drag gesture prevents the enclosing watch
                // screen from receiving trackpad and mouse-wheel scrolling.
                // The full player only needs a tap target; compact PIP keeps
                // the drag recognizer above for window movement.
                interactionRegion(
                    width: geometry.size.width,
                    height: centerHeight,
                    top: bands.top
                )
                .onTapGesture(perform: onTap)
            }
        }
    }

    private func interactionRegion(width: CGFloat, height: CGFloat, top: CGFloat) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(width: width, height: height)
            .position(
                x: width / 2,
                y: top + height / 2
            )
    }

    private func interactiveBands(for height: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        let top = max(0, reservedTop)
        let bottom = max(0, reservedBottom)
        let minimumCenter: CGFloat = isCompact ? 44 : 24
        let availableForBands = max(0, height - minimumCenter)
        let total = top + bottom

        guard total > availableForBands, total > 0 else {
            return (top, bottom)
        }

        // A small desktop PIP can be shorter than the combined visual chrome
        // bands. Scale both reservations together while preserving a usable
        // center strip for tap-to-pause and drag-to-move.
        let scale = availableForBands / total
        return (top * scale, bottom * scale)
    }
}

enum PlayerTransportLayout {
    static let normalButtonSize: CGFloat = 38
    static let normalSpacing: CGFloat = 10
    static let normalStatusWidth: CGFloat = 120
    static let normalCaptionControlInset: CGFloat = 178
    static let normalCaptionRestingInset: CGFloat = 30
    static let normalControlExitGracePeriod: Double = 0.04
    static let normalControlTransitionDuration: Double = 0.08
    // Keep the full-player row inside the clipped media surface. The
    // scrubber remains at the media edge while the circular controls sit
    // one visual shelf above it. Arctic Glass has a lighter, taller-looking
    // media surface, so its row needs a smaller lift to avoid floating too
    // far above the title boundary.
    static func normalControlLift(for palette: Palette) -> CGFloat {
        palette.theme == .arcticGlass ? -12 : -28
    }

    static func compactButtonSize(for width: CGFloat) -> CGFloat {
        min(34, max(22, (width - 15) / 6))
    }
}
