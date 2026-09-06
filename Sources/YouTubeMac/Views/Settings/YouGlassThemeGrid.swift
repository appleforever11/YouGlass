import SwiftUI

/// The bounded 24-theme catalog needs exact height in its AppKit document.
/// LazyVGrid can report an estimated height that cuts off the final row.
struct YouGlassThemeGrid: Layout {
    var spacing: CGFloat = 16

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let metrics = metrics(width: proposal.width ?? 520, subviews: subviews)
        return CGSize(width: metrics.width, height: metrics.heights.reduce(0, +) + CGFloat(max(0, metrics.heights.count - 1)) * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let metrics = metrics(width: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in metrics.heights.indices {
            for column in 0..<metrics.columns {
                let index = row * metrics.columns + column
                guard index < subviews.count else { break }
                subviews[index].place(
                    at: CGPoint(x: bounds.minX + CGFloat(column) * (metrics.cellWidth + spacing), y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: metrics.cellWidth, height: metrics.heights[row])
                )
            }
            y += metrics.heights[row] + spacing
        }
    }

    private func metrics(width: CGFloat, subviews: Subviews) -> Metrics {
        let width = max(width, 1)
        let columns = max(1, Int((width + spacing) / (240 + spacing)))
        let cellWidth = min(360, max(1, (width - CGFloat(columns - 1) * spacing) / CGFloat(columns)))
        var heights: [CGFloat] = []
        for start in stride(from: 0, to: subviews.count, by: columns) {
            let height = (start..<min(start + columns, subviews.count)).map {
                subviews[$0].sizeThatFits(ProposedViewSize(width: cellWidth, height: nil)).height
            }.max() ?? 0
            heights.append(height)
        }
        return Metrics(width: width, columns: columns, cellWidth: cellWidth, heights: heights)
    }

    private struct Metrics {
        let width: CGFloat
        let columns: Int
        let cellWidth: CGFloat
        let heights: [CGFloat]
    }
}
