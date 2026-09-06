import AppKit
import SwiftUI

/// Hosts the Home document in one stock AppKit scroll view so macOS 27's
/// native pull-to-refresh controller can attach directly to that scroll owner.
@MainActor
struct YouGlassHomeScrollView<Content: View>: NSViewRepresentable {
    let content: Content
    let isRefreshEnabled: Bool
    let refreshAction: @MainActor () async -> Void

    init(
        isRefreshEnabled: Bool,
        refreshAction: @escaping @MainActor () async -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.isRefreshEnabled = isRefreshEnabled
        self.refreshAction = refreshAction
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(content: content, refreshAction: refreshAction)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.contentView = YouGlassHomeClipView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.verticalScrollElasticity = .automatic
        scrollView.horizontalScrollElasticity = .none
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.documentView = context.coordinator.hostingController.view
        context.coordinator.scrollView = scrollView
        context.coordinator.updateRefresh(on: scrollView, enabled: isRefreshEnabled)
        context.coordinator.resizeDocument(in: scrollView)
        context.coordinator.scheduleResize(in: scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.refreshAction = refreshAction
        context.coordinator.setContent(content)
        context.coordinator.hostingController.view.needsLayout = true
        context.coordinator.updateRefresh(on: scrollView, enabled: isRefreshEnabled)
        context.coordinator.resizeDocument(in: scrollView)
        context.coordinator.scheduleResize(in: scrollView)
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        coordinator.removeRefresh(from: scrollView)
    }

    @MainActor
    final class Coordinator: NSObject {
        let hostingController: NSHostingController<Document>
        weak var scrollView: NSScrollView?
        var refreshAction: @MainActor () async -> Void
        weak var refreshScrollView: NSScrollView?
        private var refreshController: AnyObject?
        private var resizeScheduled = false

        init(
            content: Content,
            refreshAction: @escaping @MainActor () async -> Void
        ) {
            hostingController = NSHostingController(rootView: Document(content: content, sizeChanged: {}))
            hostingController.view.autoresizingMask = [.width]
            self.refreshAction = refreshAction
            super.init()
            setContent(content)
        }

        func setContent(_ content: Content) {
            hostingController.rootView = Document(content: content) { [weak self] in
                guard let self, let scrollView = self.scrollView else { return }
                self.scheduleResize(in: scrollView)
            }
        }

        func updateRefresh(on scrollView: NSScrollView, enabled: Bool) {
            guard enabled else {
                removeRefresh(from: scrollView)
                return
            }

            // Xcode 26 cannot name the macOS 27 refresh API, even inside an
            // availability check. Its builds retain the toolbar refresh action.
            #if compiler(>=6.4)
            guard #available(macOS 27.0, *) else { return }
            if refreshScrollView === scrollView, refreshController != nil {
                return
            }

            removeRefresh(from: scrollView)
            let controller = NSRefreshController()
            controller.target = self
            controller.action = #selector(handleRefresh(_:))
            controller.tintColor = .controlAccentColor
            scrollView.refreshController = controller
            // Reset the controller after attaching it. The macOS 27 beta can
            // inherit an initial pulled state while the hosted document is
            // still being measured; the indicator should only remain visible
            // after the user crosses the refresh threshold.
            controller.endRefreshing()
            refreshScrollView = scrollView
            refreshController = controller
            #endif
        }

        func removeRefresh(from scrollView: NSScrollView) {
            #if compiler(>=6.4)
            if #available(macOS 27.0, *) {
                if refreshScrollView === scrollView {
                    scrollView.refreshController = nil
                }
            }
            #endif
            if refreshScrollView === scrollView {
                refreshScrollView = nil
                refreshController = nil
            }
        }

        func resizeDocument(in scrollView: NSScrollView) {
            let width = scrollView.contentView.bounds.width
            guard width > 0 else { return }

            let proposedSize = CGSize(width: width, height: .greatestFiniteMagnitude)
            let measuredSize = hostingController.sizeThatFits(in: proposedSize)
            let height = measuredSize.height.isFinite ? max(measuredSize.height, 1) : 1
            let frame = NSRect(
                x: 0,
                y: 0,
                width: width,
                height: height
            )
            if hostingController.view.frame != frame {
                hostingController.view.frame = frame
            }
            hostingController.view.needsLayout = true
            hostingController.view.layoutSubtreeIfNeeded()
        }

        func scheduleResize(in scrollView: NSScrollView) {
            guard !resizeScheduled else { return }
            resizeScheduled = true

            DispatchQueue.main.async { [weak self, weak scrollView] in
                guard let self, let scrollView else { return }
                self.resizeScheduled = false
                self.hostingController.view.layoutSubtreeIfNeeded()
                self.resizeDocument(in: scrollView)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }

        private func scrollToTop(in scrollView: NSScrollView) {
            guard let documentView = scrollView.documentView else { return }

            let topY: CGFloat
            if documentView.isFlipped {
                topY = 0
            } else {
                topY = max(
                    0,
                    documentView.bounds.height - scrollView.contentView.bounds.height
                )
            }

            scrollView.contentView.scroll(to: NSPoint(x: 0, y: topY))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        private func finishRefresh() {
            guard let scrollView = refreshScrollView else { return }

            #if compiler(>=6.4)
            if #available(macOS 27.0, *), let controller = refreshController as? NSRefreshController {
                controller.endRefreshing()
            }
            #endif
            scrollToTop(in: scrollView)

            // AppKit finishes its refresh animation on the next run loop. A
            // second top anchor prevents that animation from leaving the
            // document in the pulled state, which otherwise keeps the
            // indicator visible until the next user scroll.
            DispatchQueue.main.async { [weak self, weak scrollView] in
                guard let self, let scrollView else { return }
                self.scrollToTop(in: scrollView)
            }
        }

        @objc
        private func handleRefresh(_ sender: AnyObject?) {
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                await self.refreshAction()
                self.finishRefresh()
            }
        }
    }

    struct Document: View {
        let content: Content
        let sizeChanged: () -> Void

        var body: some View {
            content
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { _ in
                    sizeChanged()
                }
        }
    }
}

/// AppKit otherwise bottom-aligns a short, unflipped hosting document. Keep
/// empty Library tabs and search states anchored to the same top edge as feeds.
final class YouGlassHomeClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var bounds = super.constrainBoundsRect(proposedBounds)
        if let documentView, documentView.frame.height < bounds.height {
            bounds.origin.y = documentView.isFlipped
                ? 0 : documentView.frame.height - bounds.height
        }
        return bounds
    }
}
