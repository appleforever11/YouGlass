import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension YouGlassSettingsView {
        func authorizeComments() {
            guard !authorizing else { return }
            authorizing = true
            status = "Opening Google authorization..."
            Task { @MainActor in
                let authorized = await store.authorizeYouTubeComments()
                authorizing = false
                status = authorized
                    ? "Google account actions are ready."
                    : store.connectionMessage
            }
        }

        func exportDiagnostics() {
            let panel = NSSavePanel()
            panel.title = "Export YouGlass Diagnostics"
            panel.nameFieldStringValue = "YouGlass-Diagnostics-\(Self.debugFilenameTimestamp()).json"
            panel.allowedContentTypes = [.json]
            panel.canCreateDirectories = true

            guard panel.runModal() == .OK, let url = panel.url else { return }

            do {
                try YouGlassDebugEngine.shared.exportDiagnostics(to: url)
                debugStatus = "Diagnostics exported to \(url.lastPathComponent)."
            } catch {
                debugStatus = "Diagnostics export failed: \(error.localizedDescription)"
                YouGlassDiagnostics.record(
                    .error,
                    category: "debug-engine",
                    message: "Diagnostics export failed",
                    metadata: ["error": error.localizedDescription]
                )
            }
        }

        func copyDiagnostics() {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(
                YouGlassDebugEngine.shared.makeTextReport(),
                forType: .string
            )
            debugStatus = "Diagnostics copied to the clipboard."
        }

        func revealDiagnosticsFolder() {
            NSWorkspace.shared.activateFileViewerSelecting([
                YouGlassDebugEngine.shared.diagnosticsDirectoryURL
            ])
            debugStatus = "Opened the local diagnostics folder."
        }

        static func debugFilenameTimestamp() -> String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            return formatter.string(from: Date())
        }
}
