import AppKit
import SwiftUI

/// SwiftUI's private HostingScrollView crashes in its hit-test responder path
/// on the macOS 27 beta. Keep settings scrolling on AppKit's stock
/// NSScrollView while letting the hosting view own its natural page height.
@MainActor
struct YouGlassSettingsScrollView<Content: View>: NSViewRepresentable {
    let content: Content
    let resetID: AnyHashable

    init<ID: Hashable>(resetID: ID, @ViewBuilder content: () -> Content) {
        self.resetID = AnyHashable(resetID)
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(content: content, resetID: resetID)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.verticalScrollElasticity = .none
        scrollView.horizontalScrollElasticity = .none
        scrollView.autohidesScrollers = true
        scrollView.documentView = context.coordinator.hostingController.view
        context.coordinator.resizeDocument(in: scrollView)
        context.coordinator.scheduleInitialScrollToTop(in: scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let pageChanged = context.coordinator.resetID != resetID
        context.coordinator.resetID = resetID
        context.coordinator.hostingController.rootView = content
        context.coordinator.hostingController.view.needsLayout = true
        context.coordinator.resizeDocument(in: scrollView)

        if pageChanged {
            context.coordinator.resetForNewPage(in: scrollView)
        } else {
            context.coordinator.scheduleInitialScrollToTop(in: scrollView)
        }
    }

    @MainActor
    final class Coordinator {
        let hostingController: NSHostingController<Content>
        var resetID: AnyHashable

        // Settings can receive several layout updates while the window is
        // becoming visible. Pin only that initial presentation to the top;
        // later movement belongs entirely to the user.
        private var initialScrollPassesRemaining = 3
        private var initialScrollScheduled = false
        private var layoutGeneration = 0

        init(content: Content, resetID: AnyHashable) {
            self.resetID = resetID
            hostingController = NSHostingController(rootView: content)
            hostingController.view.autoresizingMask = [.width]
        }

        func resetForNewPage(in scrollView: NSScrollView) {
            layoutGeneration += 1
            initialScrollPassesRemaining = 3
            initialScrollScheduled = false

            resizeDocument(in: scrollView)
            scrollToTop(in: scrollView)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            scheduleInitialScrollToTop(in: scrollView)
        }

        func resizeDocument(in scrollView: NSScrollView) {
            let width = scrollView.contentView.bounds.width
            guard width > 0 else { return }

            let proposedSize = CGSize(width: width, height: .greatestFiniteMagnitude)
            let measuredSize = hostingController.sizeThatFits(in: proposedSize)
            hostingController.view.frame = NSRect(
                x: 0,
                y: 0,
                width: width,
                height: max(measuredSize.height, 1)
            )
            hostingController.view.needsLayout = true
            hostingController.view.layoutSubtreeIfNeeded()
        }

        func scheduleInitialScrollToTop(in scrollView: NSScrollView) {
            guard initialScrollPassesRemaining > 0, !initialScrollScheduled else { return }
            initialScrollScheduled = true
            let generation = layoutGeneration

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self, weak scrollView] in
                guard let self, let scrollView, self.layoutGeneration == generation else { return }
                self.initialScrollScheduled = false
                self.hostingController.view.layoutSubtreeIfNeeded()
                self.resizeDocument(in: scrollView)
                self.scrollToTop(in: scrollView)
                scrollView.reflectScrolledClipView(scrollView.contentView)

                self.initialScrollPassesRemaining -= 1
                if self.initialScrollPassesRemaining > 0 {
                    self.scheduleInitialScrollToTop(in: scrollView)
                }
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
    }
}
