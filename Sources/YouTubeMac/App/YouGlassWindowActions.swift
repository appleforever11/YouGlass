import AppKit

@MainActor
enum YouGlassWindowActions {
    static func resize(compact: Bool) {
        guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main-AppWindow-1" })
                ?? NSApp.mainWindow else { return }
        let size = compact
            ? NSSize(width: YouGlassLayout.minimumWindowWidth, height: YouGlassLayout.minimumWindowHeight)
            : NSSize(width: 1160, height: 740)
        window.setContentSize(size)
        window.makeKeyAndOrderFront(nil)
    }
}
