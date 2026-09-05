import AppKit
import SwiftUI

/// Hosts SwiftUI content in a stock AppKit scroll view with a bounded viewport.
///
/// The watch page already has one outer page scroll owner. The comments
/// surface needs an independent viewport, but nested SwiftUI vertical
/// ScrollViews can recurse through the macOS 26 layout engine. Keeping the
/// scrolling primitive in AppKit avoids that private SwiftUI path while the
/// hosted rows remain ordinary SwiftUI content.
@MainActor
struct YouGlassBoundedScrollView<Content: View>: NSViewRepresentable {
    let content: Content
    let axis: Axis.Set
    let accessibilityIdentifier: String

    init(
        axis: Axis.Set = .vertical,
        accessibilityIdentifier: String,
        @ViewBuilder content: () -> Content
    ) {
        self.axis = axis
        self.accessibilityIdentifier = accessibilityIdentifier
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(content: content)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = axis.contains(.vertical)
        scrollView.hasHorizontalScroller = axis.contains(.horizontal)
        scrollView.verticalScrollElasticity = .none
        scrollView.horizontalScrollElasticity = .none
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.setAccessibilityIdentifier(accessibilityIdentifier)
        scrollView.documentView = context.coordinator.hostingController.view
        context.coordinator.resizeDocument(in: scrollView)
        context.coordinator.scheduleResize(in: scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.hostingController.rootView = content
        context.coordinator.scheduleResize(in: scrollView)
    }

    @MainActor
    final class Coordinator {
        let hostingController: NSHostingController<Content>
        private var resizeScheduled = false

        init(content: Content) {
            hostingController = NSHostingController(rootView: content)
            hostingController.view.autoresizingMask = [.width]
        }

        func resizeDocument(in scrollView: NSScrollView) {
            let viewportWidth = scrollView.contentView.bounds.width
            let viewportHeight = scrollView.contentView.bounds.height
            let isHorizontal = scrollView.hasHorizontalScroller && !scrollView.hasVerticalScroller
            guard (isHorizontal && viewportHeight > 0) || (!isHorizontal && viewportWidth > 0) else {
                return
            }

            let proposedSize = isHorizontal
                ? CGSize(width: .greatestFiniteMagnitude, height: max(viewportHeight, 1))
                : CGSize(width: viewportWidth, height: .greatestFiniteMagnitude)
            let measuredSize = hostingController.sizeThatFits(in: proposedSize)
            let width = isHorizontal
                ? (measuredSize.width.isFinite ? max(measuredSize.width, viewportWidth) : max(viewportWidth, 1))
                : viewportWidth
            let height = isHorizontal
                ? max(measuredSize.height.isFinite ? measuredSize.height : 1, viewportHeight)
                : (measuredSize.height.isFinite ? max(measuredSize.height, 1) : 1)

            let frame = NSRect(
                x: 0,
                y: 0,
                width: width,
                height: height
            )
            guard hostingController.view.frame != frame else { return }
            hostingController.view.frame = frame
        }

        func scheduleResize(in scrollView: NSScrollView) {
            guard !resizeScheduled else { return }
            resizeScheduled = true

            DispatchQueue.main.async { [weak self, weak scrollView] in
                guard let self, let scrollView else { return }
                self.resizeScheduled = false
                self.resizeDocument(in: scrollView)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }
    }
}

/// Reports the size offered by SwiftUI without adding a GeometryReader node to
/// the view graph. macOS 26 can crash while copying a GeometryReader child that
/// contains an AppKit-backed scroll view during a presentation transition.
@MainActor
struct YouGlassSizeReader: NSViewRepresentable {
    let onChange: (CGSize) -> Void

    func makeNSView(context: Context) -> SizeReportingView {
        let view = SizeReportingView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: SizeReportingView, context: Context) {
        view.onChange = onChange
        view.reportIfNeeded()
    }

    @MainActor
    final class SizeReportingView: NSView {
        var onChange: ((CGSize) -> Void)?
        private var lastReportedSize: CGSize = .zero

        override func layout() {
            super.layout()
            reportIfNeeded()
        }

        func reportIfNeeded() {
            let size = bounds.size
            guard size.width > 1,
                  size.height > 1,
                  size.width.isFinite,
                  size.height.isFinite,
                  size != lastReportedSize else { return }

            lastReportedSize = size
            let callback = onChange
            DispatchQueue.main.async {
                callback?(size)
            }
        }
    }
}
