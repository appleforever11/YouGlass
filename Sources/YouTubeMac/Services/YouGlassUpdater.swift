import AppKit
import Sparkle

/// The monitor may capture mouse-up before the main-actor mouse-down task runs.
/// Keep that pair together so AppKit's synchronous tracking loop can consume it.
final class YouGlassPointerEventBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [NSEvent] = []

    func append(_ event: NSEvent) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let needsReplay = events.isEmpty
        events.append(event)
        return needsReplay
    }

    func takeAll() -> [NSEvent] {
        lock.lock()
        defer { lock.unlock() }
        let pending = events
        events.removeAll(keepingCapacity: true)
        return pending
    }
}

/// Owns Sparkle for the process lifetime and exposes the one imperative action
/// used by the SwiftUI YouGlass menu.
@MainActor
final class YouGlassAppDelegate: NSObject, NSApplicationDelegate {
    private static weak var shared: YouGlassAppDelegate?
    nonisolated private static let deferredMouseEvents = YouGlassPointerEventBuffer()

    private let updaterController: SPUStandardUpdaterController
    private var mouseMovedMonitor: Any?
    private var mouseButtonMonitor: Any?

    override init() {
        // Start diagnostics before Sparkle or AppKit setup so a failure during
        // dependency initialization still leaves an unclean-session marker.
        YouGlassDebugEngine.shared.startSession()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftUI's delegate adaptor may install a proxy as NSApp.delegate on
        // newer systems. Keep the instance that owns the event monitor as the
        // replay target regardless of that adaptor implementation detail.
        Self.shared = self
        YouGlassDiagnostics.record(
            .info,
            category: "lifecycle",
            message: "Application did finish launching",
            metadata: ["os": ProcessInfo.processInfo.operatingSystemVersionString]
        )
        // Sparkle relaunches the updated bundle after installation. Prompt
        // LaunchServices to re-read its icon before external dock apps ask
        // for the new preview.
        YouGlassAppIconRefresh.refresh()
        guard YouGlassRuntimeStabilityPolicy.isAffectedSystem else { return }
        // macOS 26+ routes pointer-motion events through SwiftUI's
        // HoverEventDispatcher without a valid main-executor context, causing
        // a framework assertion or bad access before app code runs. YouGlass
        // does not require passive pointer motion; clicks and scrolling use
        // separate event types and remain fully functional.
        mouseMovedMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved],
            handler: Self.discardMouseMovedEvent
        )
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 else { return }
        // SwiftUI 8's AppKit hit-test bridge can be entered by AppKit's
        // synchronous event route without the main-actor executor installed.
        // On macOS 27 that path calls MainActor.assumeIsolated and can crash
        // before a button or WebView receives the click. Defer pointer events
        // to a main-actor task, then replay each event with this monitor
        // temporarily removed so normal SwiftUI routing still occurs.
        mouseButtonMonitor = NSEvent.addLocalMonitorForEvents(
            matching: Self.mouseEventsNeedingMainActorReplay,
            handler: Self.deferMouseEventToMainActor
        )
        YouGlassDiagnostics.record(
            .info,
            category: "input",
            message: "Installed beta input monitors",
            metadata: [
                "osMajor": String(ProcessInfo.processInfo.operatingSystemVersion.majorVersion),
                "mouseMoved": mouseMovedMonitor == nil ? "missing" : "installed",
                "mouseButton": mouseButtonMonitor == nil ? "missing" : "installed"
            ]
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        YouGlassDiagnostics.record(.info, category: "lifecycle", message: "Application will terminate")
        YouGlassDebugEngine.shared.finishSession()
        if let mouseMovedMonitor {
            NSEvent.removeMonitor(mouseMovedMonitor)
        }
        if let mouseButtonMonitor {
            NSEvent.removeMonitor(mouseButtonMonitor)
        }
        mouseMovedMonitor = nil
        mouseButtonMonitor = nil
        Self.shared = nil
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        YouGlassDockMenuController.shared.menu()
    }

    nonisolated private static func discardMouseMovedEvent(_ event: NSEvent) -> NSEvent? {
        nil
    }

    private static let mouseEventsNeedingMainActorReplay: NSEvent.EventTypeMask = [
        .leftMouseDown,
        .leftMouseUp,
        .rightMouseDown,
        .rightMouseUp,
        .otherMouseDown,
        .otherMouseUp,
        .leftMouseDragged,
        .rightMouseDragged,
        .otherMouseDragged,
        .scrollWheel
    ]

    nonisolated private static func deferMouseEventToMainActor(_ event: NSEvent) -> NSEvent? {
        YouGlassDiagnostics.record(
            .debug,
            category: "input",
            message: "Deferred pointer event",
            metadata: ["type": String(event.type.rawValue)]
        )
        guard deferredMouseEvents.append(event) else { return nil }
        Task { @MainActor in
            let pending = Self.deferredMouseEvents.takeAll()
            guard let first = pending.first else { return }
            guard let delegate = Self.shared else {
                YouGlassDiagnostics.record(
                    .warning,
                    category: "input",
                    message: "Could not find app delegate for deferred pointer event",
                    metadata: ["type": String(first.type.rawValue)]
                )
                return
            }
            YouGlassDiagnostics.record(
                .debug,
                category: "input",
                message: "Replaying deferred pointer event",
                metadata: ["type": String(first.type.rawValue)]
            )
            delegate.replayMouseEvent(first, pending: Array(pending.dropFirst()))
        }
        return nil
    }

    private func replayMouseEvent(_ event: NSEvent, pending: [NSEvent]) {
        guard let monitor = mouseButtonMonitor else {
            YouGlassDiagnostics.record(
                .warning,
                category: "input",
                message: "Dropped deferred pointer event because monitor was unavailable",
                metadata: ["type": String(event.type.rawValue)]
            )
            return
        }
        NSEvent.removeMonitor(monitor)
        self.mouseButtonMonitor = nil
        // Posting queued successors before mouseDown lets an NSTableView or
        // native control finish tracking without waiting on the task it owns.
        for successor in pending.reversed() {
            NSApp.postEvent(successor, atStart: true)
        }
        NSApp.sendEvent(event)
        mouseButtonMonitor = NSEvent.addLocalMonitorForEvents(
            matching: Self.mouseEventsNeedingMainActorReplay,
            handler: Self.deferMouseEventToMainActor
        )
        YouGlassDiagnostics.record(
            .debug,
            category: "input",
            message: "Replayed pointer event",
            metadata: [
                "type": String(event.type.rawValue),
                "monitor": mouseButtonMonitor == nil ? "missing" : "reinstalled"
            ]
        )
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
