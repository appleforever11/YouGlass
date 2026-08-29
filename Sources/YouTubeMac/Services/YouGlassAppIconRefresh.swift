import AppKit
import Foundation

/// Prompts macOS to re-register the icon for the bundle that is currently
/// running. This is intentionally best-effort: external docks may maintain a
/// separate in-memory preview cache that only they can invalidate.
@MainActor
enum YouGlassAppIconRefresh {
    static func refresh() {
        let bundlePath = Bundle.main.bundlePath
        guard !bundlePath.isEmpty else {
            YouGlassDiagnostics.record(
                .warning,
                category: "lifecycle",
                message: "Could not refresh application icon because the bundle path was empty"
            )
            return
        }

        let workspace = NSWorkspace.shared
        workspace.noteFileSystemChanged(bundlePath)
        _ = workspace.icon(forFile: bundlePath)

        YouGlassDiagnostics.record(
            .info,
            category: "lifecycle",
            message: "Refreshed application icon registration",
            metadata: [
                "bundleVersion": Bundle.main.object(
                    forInfoDictionaryKey: "CFBundleVersion"
                ) as? String ?? "unknown",
                "iconName": Bundle.main.object(
                    forInfoDictionaryKey: "CFBundleIconName"
                ) as? String ?? "unknown"
            ]
        )
    }
}
