import AppKit
import Sparkle

/// Owns Sparkle for the process lifetime and exposes the one imperative action
/// used by the SwiftUI YouGlass menu.
@MainActor
final class YouGlassAppDelegate: NSObject, NSApplicationDelegate {
    private let updaterController: SPUStandardUpdaterController

    override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
