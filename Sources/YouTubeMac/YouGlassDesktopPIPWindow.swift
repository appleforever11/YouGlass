import AppKit
import OSLog
import SwiftUI

/// Owns the floating desktop PIP surface. SwiftUI still owns the player UI;
/// AppKit only supplies the always-on-top window and screen-coordinate math.
@MainActor
final class YouGlassDesktopPIPWindowController: NSObject, NSWindowDelegate {
    static let shared = YouGlassDesktopPIPWindowController()

    private let defaultSize = NSSize(width: 380, height: 214)
    private let minimumSize = NSSize(width: 240, height: 135)
    private let screenInset: CGFloat = 18
    // AppKit's visibleFrame can include the area occupied by a floating Dock
    // while the Dock is visible. Keep a desktop PIP window above that area,
    // while still allowing the window to use the full screen width and height.
    private let dockClearance: CGFloat = 96
    private let dockGap: CGFloat = 12
    private var panel: NSWindow?
    private var windowController: NSWindowController?
    private var contentContainer: NSView?
    private var hostingView: NSHostingView<AnyView>?
    private var dragOriginFrame: NSRect?
    private var applyingFrame = false
    private var suppressWindowCloseCallback = false
    private var closeCallback: (() -> Void)?
    private let logger = Logger(subsystem: "com.kevinhowe.YouGlass", category: "desktop-pip")

    @discardableResult
    func present(video: VideoItem, store: YouTubeStore) -> Bool {
        let panel = makePanelIfNeeded(corner: store.compactPlayerCorner)
        suppressWindowCloseCallback = false
        closeCallback = { [weak store] in
            store?.desktopPIPDidClose()
        }
        let content = DesktopPIPContent(video: video, controller: self)
            .environmentObject(store)
            .preferredColorScheme(store.colorScheme)

        if let hostingView {
            hostingView.rootView = AnyView(content)
        } else {
            let contentContainer = NSView(frame: NSRect(origin: .zero, size: panel.frame.size))
            contentContainer.translatesAutoresizingMaskIntoConstraints = true
            contentContainer.autoresizingMask = [.width, .height]

            let hostingView = NSHostingView(rootView: AnyView(content))
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            contentContainer.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
            ])
            panel.contentView = contentContainer
            self.contentContainer = contentContainer
            self.hostingView = hostingView
        }

        let visibleFrame = visibleFrame(for: panel)
        let fittedFrameSize = fittedFrameSize(for: panel.frame.size, in: visibleFrame, window: panel)
        if panel.frame.size != fittedFrameSize {
            setFrame(NSRect(origin: panel.frame.origin, size: fittedFrameSize), on: panel)
        }

        panel.alphaValue = 1
        panel.ignoresMouseEvents = false
        windowController?.showWindow(nil)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        // `showWindow` and activation are intentionally repeated in this
        // order. SwiftUI can create the panel during an update transaction,
        // and a single order call can otherwise be consumed before the host
        // view has completed attachment.
        windowController?.showWindow(nil)
        panel.orderFrontRegardless()
        panel.makeKey()
        // Ordering a newly-created floating window can restore its initial
        // origin. Snap after it is visible so the desktop coordinates win.
        move(to: store.compactPlayerCorner, animated: false)
        let corner = store.compactPlayerCorner
        schedulePlacement(of: corner, after: 0)
        schedulePlacement(of: corner, after: 0.12)
        schedulePlacement(of: corner, after: 0.35)
        // A newly-created floating window can report windowNumber == 0 for
        // the first instant after ordering. Visibility is verified after the
        // delayed placement callbacks; the caller must not treat that
        // transient value as a failed presentation.
        let presented = panel.isVisible || panel.windowNumber != 0
        logger.notice("Presented desktop PIP frame=\(String(describing: panel.frame), privacy: .public) visible=\(panel.isVisible, privacy: .public) windowNumber=\(panel.windowNumber, privacy: .public)")
        return presented
    }

    func close() {
        dragOriginFrame = nil
        suppressWindowCloseCallback = true
        closeCallback = nil
        // Do not detach the hosting hierarchy synchronously from a button or
        // window event. AppKit may still be hit-testing that hierarchy on the
        // same run-loop turn, which can crash SwiftUI's platform responder.
        // Order out immediately, then detach the old host on the next turn.
        let oldContainer = contentContainer
        let panel = panel
        contentContainer = nil
        hostingView = nil
        panel?.orderOut(nil)
        DispatchQueue.main.async { [weak panel] in
            guard let panel, let oldContainer,
                  panel.contentView === oldContainer else { return }
            panel.contentView = nil
        }
        logger.notice("Closed desktop PIP")
    }

    func move(to corner: CompactPlayerCorner, animated: Bool = true) {
        guard let panel else { return }
        let target = frame(for: corner, window: panel)
        setFrame(target, on: panel, animated: animated)
    }

    func handleDragChanged(_ translation: CGSize) {
        guard let panel else { return }
        if dragOriginFrame == nil {
            dragOriginFrame = panel.frame
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
        }

        guard let origin = dragOriginFrame else { return }
        var frame = origin
        frame.origin.x += translation.width
        frame.origin.y -= translation.height
        setFrame(clamped(frame, for: panel), on: panel)
    }

    @discardableResult
    func handleDragEnded(_ translation: CGSize) -> CompactPlayerCorner? {
        handleDragChanged(translation)
        defer { dragOriginFrame = nil }
        guard let panel else { return nil }
        let corner = nearestCorner(for: panel)
        move(to: corner)
        return corner
    }

    private func makePanelIfNeeded(corner: CompactPlayerCorner) -> NSWindow {
        if let panel {
            return panel
        }

        // Use a regular floating NSWindow here. NSPanel adds activation and
        // deactivation rules that can leave a borderless window ordered out
        // when the main SwiftUI window changes state during presentation.
        let panel = NSWindow(
            contentRect: initialFrame(for: corner),
            // Keep the titled content window as the AppKit lifecycle anchor.
            // A borderless NSWindow can be closed during the SwiftUI handoff
            // when the main player is removed, which leaves the app reporting
            // PIP active without a visible floating host. The transparent
            // titlebar is still visually hidden below, while the content
            // view's full-bleed constraints keep the player and controls
            // inside the actual window bounds.
            styleMask: [.titled, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "YouGlass Picture in Picture"
        panel.level = .floating
        panel.isMovable = true
        panel.isMovableByWindowBackground = true
        panel.minSize = frameSize(forContentSize: minimumSize, window: panel)
        panel.contentAspectRatio = NSSize(width: 16, height: 9)
        panel.resizeIncrements = NSSize(width: 16, height: 9)
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.delegate = self

        self.panel = panel
        self.windowController = NSWindowController(window: panel)
        return panel
    }

    private func initialFrame(for corner: CompactPlayerCorner) -> NSRect {
        let visibleFrame = NSScreen.main.map(usableFrame(for:))
            ?? NSScreen.screens.first.map(usableFrame(for:))
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = corner == .topLeading || corner == .bottomLeading
            ? visibleFrame.minX + screenInset
            : visibleFrame.maxX - defaultSize.width - screenInset
        let y = corner == .topLeading || corner == .topTrailing
            ? visibleFrame.maxY - defaultSize.height - screenInset
            : visibleFrame.minY + screenInset
        return NSRect(x: x, y: y, width: defaultSize.width, height: defaultSize.height)
    }

    private func frame(for corner: CompactPlayerCorner, window: NSWindow) -> NSRect {
        let visibleFrame = visibleFrame(for: window)
        let size = fittedFrameSize(for: window.frame.size, in: visibleFrame, window: window)
        let x = corner == .topLeading || corner == .bottomLeading
            ? visibleFrame.minX + screenInset
            : visibleFrame.maxX - size.width - screenInset
        let y = corner == .topLeading || corner == .topTrailing
            ? visibleFrame.maxY - size.height - screenInset
            : visibleFrame.minY + screenInset

        return NSRect(
            x: x,
            y: y,
            width: size.width,
            height: size.height
        )
    }

    private func clamped(_ frame: NSRect, for window: NSWindow) -> NSRect {
        let visibleFrame = visibleFrame(for: window, proposedFrame: frame)
        let size = fittedFrameSize(for: frame.size, in: visibleFrame, window: window)
        var result = frame
        result.size = size
        result.origin.x = min(
            max(result.minX, visibleFrame.minX + screenInset),
            visibleFrame.maxX - result.width - screenInset
        )
        result.origin.y = min(
            max(result.minY, visibleFrame.minY + screenInset),
            visibleFrame.maxY - result.height - screenInset
        )
        return result
    }

    private func fittedFrameSize(
        for proposedFrameSize: NSSize,
        in visibleFrame: NSRect,
        window: NSWindow
    ) -> NSSize {
        // `NSWindow.frame` includes the titlebar even with a transparent,
        // full-size content view. Keep the aspect-ratio math in content
        // coordinates, then convert the result back to a frame size. Treating
        // the frame height as content height is what clipped the PIP toolbar
        // below the window's visible bottom edge.
        let availableFrameSize = NSSize(
            width: max(1, visibleFrame.width - screenInset * 2),
            height: max(1, visibleFrame.height - screenInset * 2)
        )
        let availableContentSize = contentSize(forFrameSize: availableFrameSize, window: window)
        let proposedContentSize = contentSize(forFrameSize: proposedFrameSize, window: window)
        let availableWidth = max(1, availableContentSize.width)
        let availableHeight = max(1, availableContentSize.height)
        let minimumWidth = min(minimumSize.width, availableWidth)
        let minimumHeight = min(minimumSize.height, availableHeight)
        let aspectRatio = CGFloat(16.0 / 9.0)

        var width = min(max(proposedContentSize.width, minimumWidth), availableWidth)
        var height = width / aspectRatio
        if height > availableHeight {
            height = availableHeight
            width = height * aspectRatio
        }

        width = max(minimumWidth, width)
        height = max(minimumHeight, min(availableHeight, width / aspectRatio))
        return frameSize(forContentSize: NSSize(width: width, height: height), window: window)
    }

    private func contentSize(forFrameSize size: NSSize, window: NSWindow) -> NSSize {
        let frameRect = NSRect(origin: .zero, size: size)
        return window.contentRect(forFrameRect: frameRect).size
    }

    private func frameSize(forContentSize size: NSSize, window: NSWindow) -> NSSize {
        let contentRect = NSRect(origin: .zero, size: size)
        return window.frameRect(forContentRect: contentRect).size
    }

    private func setFrame(_ frame: NSRect, on window: NSWindow, animated: Bool = false) {
        guard !applyingFrame else { return }
        applyingFrame = true
        window.setFrame(frame, display: true, animate: animated)
        // Floating windows can retain the launch origin when their hosting
        // view finishes its first layout pass. Set the origin directly as a
        // second step so the desktop corner is applied in AppKit coordinates.
        if !animated {
            window.setFrameOrigin(frame.origin)
        }
        applyingFrame = false
    }

    private func schedulePlacement(of corner: CompactPlayerCorner, after delay: TimeInterval) {
        Task { @MainActor [weak self, weak panel] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } else {
                await Task.yield()
            }
            guard let self, let panel else { return }
            // A newly-created floating window may report isVisible == false
            // for the first run-loop turns even though it has been ordered.
            // Ordering it here makes the delayed placement deterministic.
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
            self.move(to: corner, animated: false)
        }
    }

    private func nearestCorner(for window: NSWindow) -> CompactPlayerCorner {
        let visibleFrame = visibleFrame(for: window)
        let size = window.frame.size
        let centers: [(CompactPlayerCorner, CGPoint)] = [
            (.topLeading, CGPoint(
                x: visibleFrame.minX + screenInset + size.width / 2,
                y: visibleFrame.maxY - screenInset - size.height / 2
            )),
            (.topTrailing, CGPoint(
                x: visibleFrame.maxX - screenInset - size.width / 2,
                y: visibleFrame.maxY - screenInset - size.height / 2
            )),
            (.bottomLeading, CGPoint(
                x: visibleFrame.minX + screenInset + size.width / 2,
                y: visibleFrame.minY + screenInset + size.height / 2
            )),
            (.bottomTrailing, CGPoint(
                x: visibleFrame.maxX - screenInset - size.width / 2,
                y: visibleFrame.minY + screenInset + size.height / 2
            ))
        ]
        let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
        return centers.min { lhs, rhs in
            distanceSquared(center, lhs.1) < distanceSquared(center, rhs.1)
        }?.0 ?? .bottomTrailing
    }

    private func visibleFrame(for window: NSWindow, proposedFrame: NSRect? = nil) -> NSRect {
        let frame = proposedFrame ?? window.frame
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) }
            ?? window.screen
            ?? NSScreen.main
            ?? NSScreen.screens.first
        return screen.map(usableFrame(for:))
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }

    private func usableFrame(for screen: NSScreen) -> NSRect {
        let screenFrame = screen.frame
        var frame = screen.visibleFrame.intersection(screenFrame)
        guard frame.width > 1, frame.height > 1 else { return screenFrame }

        // On macOS the Dock can be a floating overlay, so visibleFrame may
        // still report minY == screen.minY. Reserving this adaptive bottom
        // band keeps bottom-corner PIP above the Dock on every display size.
        let dockTop = screenFrame.minY + dockClearance
        if frame.minY < dockTop {
            let top = frame.maxY
            frame.origin.y = min(dockTop + dockGap, top - 1)
            frame.size.height = max(1, top - frame.origin.y)
        }
        return frame
    }

    private func distanceSquared(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }

    func windowWillClose(_ notification: Notification) {
        panel?.orderOut(nil)
        guard !suppressWindowCloseCallback else {
            suppressWindowCloseCallback = false
            return
        }

        let callback = closeCallback
        closeCallback = nil
        callback?()
    }

    func windowDidResize(_ notification: Notification) {
        guard !applyingFrame, let panel else { return }
        let corrected = clamped(panel.frame, for: panel)
        if corrected != panel.frame {
            setFrame(corrected, on: panel)
        }
    }
}

private struct DesktopPIPContent: View {
    @EnvironmentObject private var store: YouTubeStore
    @Environment(\.colorScheme) private var colorScheme
    let video: VideoItem
    weak var controller: YouGlassDesktopPIPWindowController?

    var body: some View {
        YouTubePlayerOverlay(
            video: video,
            palette: Palette(colorScheme),
            isCompact: true,
            onCompactDragChanged: { [weak controller] translation in
                controller?.handleDragChanged(translation)
            },
            onCompactDragEnded: { [weak controller] translation in
                guard let controller,
                      let corner = controller.handleDragEnded(translation) else { return }
                store.setCompactPlayerCorner(corner)
            }
        )
        .environmentObject(store)
        .frame(minWidth: 240, minHeight: 135)
        // The floating panel is a full-bleed player surface. Without this,
        // the titled-window safe area can push the compact transport row
        // below the visible bounds at smaller PIP sizes.
        .ignoresSafeArea()
        .onChange(of: store.compactPlayerCorner) { _, corner in
            controller?.move(to: corner)
        }
    }
}
