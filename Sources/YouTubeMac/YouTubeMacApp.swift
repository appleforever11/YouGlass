import AppKit
import Sparkle
import SwiftUI

@main
struct YouTubeMacApp: App {
    @NSApplicationDelegateAdaptor(YouGlassAppDelegate.self) private var appDelegate
    @StateObject private var store = YouTubeStore()

    var body: some Scene {
        WindowGroup("YouGlass", id: "main") {
            YouTubeHomeView()
                .environmentObject(store)
                // The shell switches to its compact navigation mode below
                // this size, so the window remains usable on small displays
                // instead of forcing a clipped default minimum.
                .frame(minWidth: 560, minHeight: 400)
                .preferredColorScheme(store.colorScheme)
                .background(YouGlassWindowSizingView())
                .task {
                    await store.loadHome()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1160, height: 740)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Check for Updates...") {
                    appDelegate.checkForUpdates()
                }
            }

            CommandMenu("YouGlass") {
                Button("Refresh YouTube Account") {
                    store.refreshAccount()
                }

                Button(store.autoMuteOnStart ? "Allow Audio on Start" : "Start Videos Muted") {
                    store.setAutoMuteOnStart(!store.autoMuteOnStart)
                }

                Divider()

                Button("Open Picture in Picture") {
                    store.presentDesktopPIP()
                }
                .disabled(store.selectedVideo == nil)

                Button("Stop Playback") {
                    store.dismissPlayer()
                }
                .disabled(store.selectedVideo == nil)

                Divider()

                Button("Reset YouTube Sign-In Data") {
                    store.resetYouTubeCredentials()
                }
            }
        }

        Settings {
            YouGlassSettingsView()
                .environmentObject(store)
        }
        .defaultSize(width: 1040, height: 700)
        .windowResizability(.contentMinSize)
    }
}

/// Keeps the restored SwiftUI window inside the active display's visible
/// frame. SwiftUI's default size is only a preference; a restored iCloud
/// window can otherwise be larger than a smaller MacBook display.
private struct YouGlassWindowSizingView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.configure(window: view.window)
        DispatchQueue.main.async {
            context.coordinator.configure(window: view.window)
        }
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator: NSObject {
        private weak var view: NSView?
        private weak var window: NSWindow?
        private var screenObserver: NSObjectProtocol?
        private var configuredScreen: NSScreen?

        func attach(to view: NSView) {
            self.view = view
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeScreenNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let window = notification.object as? NSWindow else { return }
                Task { @MainActor [weak self, weak window] in
                    guard let self, let window, window === self.window else { return }
                    self.configure(window: window)
                }
            }
        }

        func detach() {
            if let screenObserver {
                NotificationCenter.default.removeObserver(screenObserver)
            }
            screenObserver = nil
            view = nil
            window = nil
            configuredScreen = nil
        }

        func configure(window: NSWindow?) {
            guard let window,
                  let screen = window.screen ?? NSScreen.main else { return }

            if self.window !== window {
                self.window = window
                configuredScreen = nil
            }

            let visible = screen.visibleFrame.insetBy(dx: 12, dy: 12)
            guard visible.width > 1, visible.height > 1 else { return }

            let minimumWidth = min(560, max(520, visible.width))
            let minimumHeight = min(400, max(360, visible.height))
            window.minSize = NSSize(width: minimumWidth, height: minimumHeight)

            let screenChanged = configuredScreen !== screen
            let frame = window.frame
            let fitsDisplay = visible.contains(frame) &&
                frame.width <= visible.width && frame.height <= visible.height
            guard screenChanged || !fitsDisplay else { return }

            let targetWidth = min(max(980, visible.width * 0.86), visible.width)
            let targetHeight = min(max(620, visible.height * 0.82), visible.height)
            let size = NSSize(
                width: max(minimumWidth, targetWidth),
                height: max(minimumHeight, targetHeight)
            )
            let origin = NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.midY - size.height / 2
            )

            configuredScreen = screen
            window.setFrame(NSRect(origin: origin, size: size), display: true)
        }
    }
}
