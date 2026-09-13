import SwiftUI

extension YouTubeHomeView {
    func compactPlayer(video: VideoItem, in containerSize: CGSize) -> some View {
        // Keep the mini-player inside the visible content area at every
        // window size. Height is intentionally capped as well as width so a
        // short window cannot leave the PIP surface clipped below the edge.
        let shortestSide = min(containerSize.width, containerSize.height)
        let inset = min(
            CompactPlayerMetrics.edgeInset,
            max(8, shortestSide * 0.04)
        )
        let availableWidth = max(1, containerSize.width - inset * 2)
        let availableHeight = max(1, containerSize.height - inset * 2)
        let widthByHeight = availableHeight * 0.36 * CompactPlayerMetrics.aspectRatio
        let widthLimit = min(
            CompactPlayerMetrics.maxWidth,
            availableWidth,
            widthByHeight,
            max(180, containerSize.width * CompactPlayerMetrics.widthFraction)
        )
        let minimumWidth = min(
            CompactPlayerMetrics.minimumWidth,
            availableWidth,
            availableHeight * CompactPlayerMetrics.aspectRatio
        )
        let width = max(minimumWidth, widthLimit)
        let height = width / CompactPlayerMetrics.aspectRatio
        let outerHalfWidth = (width + inset * 2) / 2
        let outerHalfHeight = (height + inset * 2) / 2
        let baseCenter = compactPlayerCenter(
            corner: store.compactPlayerCorner,
            containerSize: containerSize,
            halfWidth: outerHalfWidth,
            halfHeight: outerHalfHeight
        )

        return YouTubePlayerOverlay(
            video: video,
            palette: palette,
            isCompact: true,
            initialAvailableSize: CGSize(width: width, height: height),
            onCompactDragChanged: { translation in
                let desiredCenter = CGPoint(
                    x: baseCenter.x + translation.width,
                    y: baseCenter.y + translation.height
                )
                let clampedCenter = clampedCompactPlayerCenter(
                    desiredCenter,
                    containerSize: containerSize,
                    halfWidth: outerHalfWidth,
                    halfHeight: outerHalfHeight
                )
                compactDragOffset = CGSize(
                    width: clampedCenter.x - baseCenter.x,
                    height: clampedCenter.y - baseCenter.y
                )
            },
            onCompactDragEnded: { translation in
                let desiredCenter = CGPoint(
                    x: baseCenter.x + translation.width,
                    y: baseCenter.y + translation.height
                )
                let clampedCenter = clampedCompactPlayerCenter(
                    desiredCenter,
                    containerSize: containerSize,
                    halfWidth: outerHalfWidth,
                    halfHeight: outerHalfHeight
                )
                let snappedCorner = nearestCompactPlayerCorner(
                    to: clampedCenter,
                    containerSize: containerSize,
                    halfWidth: outerHalfWidth,
                    halfHeight: outerHalfHeight
                )
                withAnimation(.snappy(duration: 0.24)) {
                    compactDragOffset = .zero
                    store.setCompactPlayerCorner(snappedCorner)
                }
            }
        )
        .frame(width: width, height: height)
        .clipped()
        .padding(inset)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: store.compactPlayerCorner.alignment
        )
        .offset(compactDragOffset)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .zIndex(2)
    }

    private func compactPlayerCenter(
        corner: CompactPlayerCorner,
        containerSize: CGSize,
        halfWidth: CGFloat,
        halfHeight: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: corner == .topLeading || corner == .bottomLeading
                ? halfWidth
                : containerSize.width - halfWidth,
            y: corner == .topLeading || corner == .topTrailing
                ? halfHeight
                : containerSize.height - halfHeight
        )
    }

    private func clampedCompactPlayerCenter(
        _ desired: CGPoint,
        containerSize: CGSize,
        halfWidth: CGFloat,
        halfHeight: CGFloat
    ) -> CGPoint {
        let minX = min(halfWidth, containerSize.width / 2)
        let maxX = max(minX, containerSize.width - halfWidth)
        let minY = min(halfHeight, containerSize.height / 2)
        let maxY = max(minY, containerSize.height - halfHeight)

        return CGPoint(
            x: min(max(desired.x, minX), maxX),
            y: min(max(desired.y, minY), maxY)
        )
    }

    private func nearestCompactPlayerCorner(
        to point: CGPoint,
        containerSize: CGSize,
        halfWidth: CGFloat,
        halfHeight: CGFloat
    ) -> CompactPlayerCorner {
        CompactPlayerCorner.allCases.min { lhs, rhs in
            distanceSquared(
                compactPlayerCenter(
                    corner: lhs,
                    containerSize: containerSize,
                    halfWidth: halfWidth,
                    halfHeight: halfHeight
                ),
                point
            ) < distanceSquared(
                compactPlayerCenter(
                    corner: rhs,
                    containerSize: containerSize,
                    halfWidth: halfWidth,
                    halfHeight: halfHeight
                ),
                point
            )
        } ?? .bottomTrailing
    }

    private func distanceSquared(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        let deltaX = lhs.x - rhs.x
        let deltaY = lhs.y - rhs.y
        return deltaX * deltaX + deltaY * deltaY
    }
}
