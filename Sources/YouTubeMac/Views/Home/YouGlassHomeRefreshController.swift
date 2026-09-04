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
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.verticalScrollElasticity = .automatic
        scrollView.horizontalScrollElasticity = .none
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.documentView = context.coordinator.hostingController.view
        context.coordinator.updateRefresh(on: scrollView, enabled: isRefreshEnabled)
        context.coordinator.resizeDocument(in: scrollView)
        context.coordinator.scheduleResize(in: scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.refreshAction = refreshAction
        context.coordinator.hostingController.rootView = content
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
        let hostingController: NSHostingController<Content>
        var refreshAction: @MainActor () async -> Void
        weak var refreshScrollView: NSScrollView?
        private var refreshController: AnyObject?
        private var resizeScheduled = false

        init(
            content: Content,
            refreshAction: @escaping @MainActor () async -> Void
        ) {
            hostingController = NSHostingController(rootView: content)
            hostingController.view.autoresizingMask = [.width]
            self.refreshAction = refreshAction
        }

        func updateRefresh(on scrollView: NSScrollView, enabled: Bool) {
            guard enabled else {
                removeRefresh(from: scrollView)
                return
            }

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
        }

        func removeRefresh(from scrollView: NSScrollView) {
            if #available(macOS 27.0, *) {
                if refreshScrollView === scrollView {
                    scrollView.refreshController = nil
                }
            }
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
            hostingController.view.frame = NSRect(
                x: 0,
                y: 0,
                width: width,
                height: height
            )
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

        @objc
        private func handleRefresh(_ sender: AnyObject?) {
            Task { @MainActor [weak self] in
                guard let self else {
                    if #available(macOS 27.0, *), let controller = sender as? NSRefreshController {
                        controller.endRefreshing()
                    }
                    return
                }
                await self.refreshAction()
                if #available(macOS 27.0, *), let controller = sender as? NSRefreshController {
                    controller.endRefreshing()
                }
            }
        }
    }
}
