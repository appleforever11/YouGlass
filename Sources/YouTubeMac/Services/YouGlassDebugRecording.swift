import Foundation
import OSLog

extension YouGlassDebugEngine {
    var diagnosticsDirectoryURL: URL {
        diagnosticsDirectory
    }

    var currentSessionID: String {
        lock.lock()
        defer { lock.unlock() }
        return sessionID
    }

    var sessionSummary: String {
        lock.lock()
        let shortSessionID = String(sessionID.prefix(8))
        let count = events.count
        let wasUnclean = previousSessionWasUnclean
        lock.unlock()

        let termination = wasUnclean ? "previous session needs review" : "normal session"
        return shortSessionID + " · " + String(count) + " breadcrumbs · " + termination
    }

    var eventCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return events.count
    }

    var isVerboseLoggingEnabled: Bool {
        userDefaults.bool(forKey: Self.verboseLoggingKey)
    }

    func startSession() {
        var shouldRecordUnclean = false
        var previousSessionID: String?

        lock.lock()
        guard !didStartSession else {
            lock.unlock()
            return
        }

        didStartSession = true
        sessionID = UUID().uuidString
        sessionStartedAt = Date()
        events.removeAll(keepingCapacity: true)
        ensureDiagnosticsDirectoryLocked()

        if let previousState = readSessionStateLocked(), !previousState.cleanTermination {
            previousSessionWasUnclean = true
            shouldRecordUnclean = true
            previousSessionID = previousState.sessionID
        }

        sessionLogURL = diagnosticsDirectory.appendingPathComponent(
            "session-" + sessionID + ".jsonl",
            isDirectory: false
        )
        writeSessionStateLocked(cleanTermination: false)
        lock.unlock()

        installUncaughtExceptionHandler()
        record(
            .info,
            category: "lifecycle",
            message: "Debug session started",
            metadata: ["diagnostics": diagnosticsEnabled ? "enabled" : "errors-only"]
        )

        if shouldRecordUnclean {
            record(
                .warning,
                category: "lifecycle",
                message: "Previous session did not report a clean termination",
                metadata: ["previousSession": previousSessionID ?? "unknown"]
            )
        }
    }

    func finishSession() {
        lock.lock()
        guard didStartSession else {
            lock.unlock()
            return
        }

        let event = makeEventLocked(
            level: .info,
            category: "lifecycle",
            message: "Application terminating cleanly",
            metadata: [:]
        )
        appendEventLocked(event, persist: true)
        writeSessionStateLocked(cleanTermination: true)
        lock.unlock()
    }

    func record(
        _ level: YouGlassDebugLevel,
        category: String,
        message: String,
        metadata: [String: String] = [:]
    ) {
        ensureSessionStarted()

        lock.lock()
        let event = makeEventLocked(
            level: level,
            category: category,
            message: message,
            metadata: metadata
        )
        let shouldPersist = diagnosticsEnabled
            || isVerboseLoggingEnabled && (level == .trace || level == .debug)
            || level == .warning
            || level == .error
        appendEventLocked(event, persist: shouldPersist)
        lock.unlock()

        writeUnifiedLog(for: event)
    }

    func breadcrumb(_ category: String, _ message: String, metadata: [String: String] = [:]) {
        guard userDefaults.bool(forKey: Self.webKitBreadcrumbsKey) || category != "playback" else {
            return
        }
        record(.debug, category: category, message: message, metadata: metadata)
    }

    func recentEvents(limit: Int = 100) -> [YouGlassDiagnosticEvent] {
        lock.lock()
        defer { lock.unlock() }
        return Array(events.suffix(max(0, min(limit, events.count))))
    }
}
