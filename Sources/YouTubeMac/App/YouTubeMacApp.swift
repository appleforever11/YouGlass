import AppKit
import Sparkle
import SwiftUI

@main
struct YouTubeMacApp: App {
    @NSApplicationDelegateAdaptor(YouGlassAppDelegate.self) private var appDelegate
    @StateObject private var store = YouTubeStore()

    var body: some Scene {
        WindowGroup("YouGlass", id: "main") {
            YouGlassAppRoot()
                .environmentObject(store)
                // The shell switches to its compact navigation mode below
                // this size, so the window remains usable on small displays
                // instead of forcing a clipped default minimum.
                .frame(minWidth: 560, minHeight: 400)
                .preferredColorScheme(store.colorScheme)
                .background(YouGlassWindowSizingView())
                .task {
                    await store.loadHome()
                    store.startAutomaticFeedRefresh()
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
                Button("Command Palette") {
                    store.toggleCommandPalette()
                }
                .keyboardShortcut("k", modifiers: [.command])

                Divider()

                Button("Refresh YouTube Account") {
                    store.refreshAccount()
                }

                Button(store.autoMuteOnStart ? "Allow Audio on Start" : "Start Videos Muted") {
                    store.setAutoMuteOnStart(!store.autoMuteOnStart)
                }

                Divider()

                Button("Play or Pause") {
                    store.sendPlaybackCommand(.togglePlayback)
                }
                .disabled(store.selectedVideo == nil)

                Button("Back 10 Seconds") {
                    store.sendPlaybackCommand(.seek(-10))
                }
                .disabled(store.selectedVideo == nil)

                Button("Forward 10 Seconds") {
                    store.sendPlaybackCommand(.seek(10))
                }
                .disabled(store.selectedVideo == nil)

                Button("Play Next in Queue") {
                    store.playNextInQueue()
                }
                .keyboardShortcut("n")
                .disabled(store.nextQueuedVideo == nil)

                Button("Play Previous in Queue") {
                    store.playPreviousInQueue()
                }
                .keyboardShortcut("p")
                .disabled(store.previousQueuedVideo == nil)

                Button("Mute or Unmute") {
                    store.sendPlaybackCommand(.toggleMute)
                }
                .disabled(store.selectedVideo == nil)

                Button("Toggle Captions") {
                    store.sendPlaybackCommand(.toggleCaptions)
                }
                .disabled(store.selectedVideo == nil)

                Divider()

                Button("Open Picture in Picture") {
                    store.presentDesktopPIP()
                }
                .disabled(store.selectedVideo == nil)

                Button("Minimize Player") {
                    store.minimizePlayer()
                }
                .keyboardShortcut("m", modifiers: [.command, .option])
                .disabled(store.selectedVideo == nil)

                Button("Toggle Full Screen") {
                    store.toggleMainWindowFullScreen()
                }
                .keyboardShortcut("f", modifiers: [.command, .control])

                Menu("Playback Speed") {
                    ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                        Button(rate == 1 ? "Normal" : "\(rate)x") {
                            store.sendPlaybackCommand(.setPlaybackRate(rate))
                        }
                    }
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
                .environment(\.colorScheme, store.colorScheme)
                .preferredColorScheme(store.colorScheme)
        }
        .defaultSize(width: 1040, height: 700)
        .windowResizability(.contentMinSize)
    }
}
