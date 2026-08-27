import AppKit
import SwiftUI

/// SwiftUI's private HostingScrollView crashes in its hit-test responder path
/// on the macOS 27 beta. Keep settings scrollable while routing the container
/// through AppKit's mature NSScrollView implementation.
@MainActor
final class YouGlassSettingsScrollViewHost: NSScrollView {
    var layoutHandler: (() -> Void)?

    override func layout() {
        super.layout()
        layoutHandler?()
    }
}

@MainActor
final class YouGlassSettingsDocumentView<Content: View>: NSView {
    let hostingView: NSHostingView<Content>
    private var contentHeight: CGFloat = 1

    override var isFlipped: Bool { true }

    init(rootView: Content) {
        hostingView = NSHostingView(rootView: rootView)
        super.init(frame: .zero)

        // The scroll view owns the document size. Letting the hosting view
        // publish an intrinsic height makes SwiftUI negotiate against the
        // viewport and can place the first page below the document origin.
        hostingView.sizingOptions = []
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.autoresizingMask = []
        addSubview(hostingView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(rootView: Content) {
        hostingView.rootView = rootView
        hostingView.invalidateIntrinsicContentSize()
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    func resize(to width: CGFloat, minimumHeight: CGFloat) {
        guard width > 0 else { return }

        // Give SwiftUI the real viewport width before asking for its natural
        // height. The document itself is at least as tall as the viewport;
        // the hosting view remains only as tall as the page content and is
        // pinned to the document's top edge.
        let probeHeight = max(contentHeight, minimumHeight, 1)
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: probeHeight)
        hostingView.needsLayout = true
        hostingView.layoutSubtreeIfNeeded()

        let measuredHeight = max(hostingView.fittingSize.height, 1)
        contentHeight = measuredHeight
        frame = NSRect(
            x: 0,
            y: 0,
            width: width,
            height: max(measuredHeight, minimumHeight, 1)
        )
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    override func layout() {
        super.layout()
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: contentHeight
        )
        hostingView.layoutSubtreeIfNeeded()
    }
}

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
        let scrollView = YouGlassSettingsScrollViewHost()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.verticalScrollElasticity = .none
        scrollView.horizontalScrollElasticity = .none
        scrollView.autohidesScrollers = true
        scrollView.documentView = context.coordinator.documentView
        scrollView.layoutHandler = { [weak scrollView, weak coordinator = context.coordinator] in
            guard let scrollView, let coordinator else { return }
            coordinator.resizeDocument(in: scrollView)
        }
        context.coordinator.resizeDocument(in: scrollView)
        context.coordinator.scheduleInitialScrollToTop(in: scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let pageChanged = context.coordinator.resetID != resetID
        context.coordinator.resetID = resetID
        context.coordinator.documentView.update(rootView: content)
        context.coordinator.resizeDocument(in: scrollView)

        if pageChanged {
            context.coordinator.resetForNewPage(in: scrollView)
        } else {
            context.coordinator.scheduleInitialScrollToTop(in: scrollView)
        }
    }

    @MainActor
    final class Coordinator {
        let documentView: YouGlassSettingsDocumentView<Content>
        var resetID: AnyHashable

        var hostingView: NSHostingView<Content> {
            documentView.hostingView
        }

        // The settings window can receive several layout updates while it is
        // becoming visible. Keep the first presentation at the top until the
        // document height has settled, then leave scrolling entirely to the user.
        private var initialScrollPassesRemaining = 3
        private var initialScrollScheduled = false
        private var layoutGeneration = 0
        private var isResizing = false

        init(content: Content, resetID: AnyHashable) {
            self.resetID = resetID
            documentView = YouGlassSettingsDocumentView(rootView: content)
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
            guard !isResizing else { return }

            let width = scrollView.contentView.bounds.width
            let viewportHeight = scrollView.contentView.bounds.height
            guard width > 0, viewportHeight > 0 else { return }

            isResizing = true
            documentView.resize(to: width, minimumHeight: viewportHeight)
            isResizing = false
        }

        func scheduleInitialScrollToTop(in scrollView: NSScrollView) {
            guard initialScrollPassesRemaining > 0, !initialScrollScheduled else { return }
            initialScrollScheduled = true
            let generation = layoutGeneration

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self, weak scrollView] in
                guard let self, let scrollView, self.layoutGeneration == generation else { return }
                self.initialScrollScheduled = false
                self.documentView.needsLayout = true
                self.hostingView.layoutSubtreeIfNeeded()
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

            // The document is flipped for SwiftUI, while the enclosing
            // NSClipView can remain unflipped on different macOS releases.
            // Resolve the visual top against the clip view's coordinate
            // system so page changes never reopen at the last visible row.
            let documentHeight = documentView.bounds.height
            let viewportHeight = scrollView.contentView.bounds.height
            let topY = scrollView.contentView.isFlipped
                ? documentView.bounds.minY
                : max(documentHeight - viewportHeight, documentView.bounds.minY)
            scrollView.contentView.scroll(to: NSPoint(x: documentView.bounds.minX, y: topY))
        }
    }
}
