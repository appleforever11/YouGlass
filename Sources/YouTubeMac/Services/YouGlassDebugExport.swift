import Foundation
import OSLog

extension YouGlassDebugEngine {
    func exportDiagnostics(to url: URL) throws {
        let encoder = makeEncoder()
        let data = try encoder.encode(makeSnapshot())
        try data.write(to: url, options: .atomic)
    }

    func makeTextReport() -> String {
        let snapshot = makeSnapshot()
        var lines: [String] = []
        lines.append("YouGlass diagnostics")
        lines.append("Schema: " + String(snapshot.schemaVersion))
        lines.append("App: " + snapshot.appVersion + " (" + snapshot.buildVersion + ")")
        lines.append("Platform: " + snapshot.operatingSystem + " · " + snapshot.architecture)
        lines.append("Session: " + snapshot.sessionID)
        lines.append("Session started: " + snapshot.sessionStartedAt.formatted(.iso8601))
        lines.append("Diagnostics enabled: " + String(snapshot.diagnosticsEnabled))
        lines.append("Verbose logging enabled: " + String(snapshot.verboseLoggingEnabled))
        lines.append("WebKit breadcrumbs enabled: " + String(snapshot.webKitBreadcrumbsEnabled))
        lines.append("Hidden WebKit bridges enabled: " + String(snapshot.hiddenWebKitBridgesEnabled))
        lines.append("Thumbnail parallax mode: " + snapshot.parallaxMode)
        lines.append("Previous session unclean: " + String(snapshot.previousSessionWasUnclean))
        lines.append("")
        lines.append("Recent events")
        lines.append("-------------")

        for event in snapshot.recentEvents {
            let timestamp = event.timestamp.formatted(.iso8601)
            lines.append("[" + timestamp + "] " + event.level.rawValue.uppercased() + " " + event.category + ": " + event.message)
        }

        return lines.joined(separator: "\n") + "\n"
    }

    func clearPersistedDiagnostics() {
        lock.lock()
        ensureDiagnosticsDirectoryLocked()
        if let contents = try? fileManager.contentsOfDirectory(
            at: diagnosticsDirectory,
            includingPropertiesForKeys: nil
        ) {
            for url in contents {
                try? fileManager.removeItem(at: url)
            }
        }
        events.removeAll(keepingCapacity: true)
        if didStartSession {
            sessionLogURL = diagnosticsDirectory.appendingPathComponent(
                "session-" + sessionID + ".jsonl",
                isDirectory: false
            )
            writeSessionStateLocked(cleanTermination: false)
        }
        lock.unlock()
    }
}
