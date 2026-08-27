import AppKit
import SwiftUI

/// Prevents the Settings scene from briefly resolving through a transparent
/// AppKit window while SwiftUI installs the selected theme.
@MainActor
struct YouGlassSettingsWindowConfigurator: NSViewRepresentable {
    let isDark: Bool

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ view: NSView, context: Context) {
        configure(window: view.window)

        DispatchQueue.main.async { [weak view] in
            configure(window: view?.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        window.isOpaque = true
        window.backgroundColor = NSColor(
            calibratedWhite: isDark ? 0.075 : 0.965,
            alpha: 1
        )
        window.hasShadow = true
    }
}
