import Foundation
import OSLog

extension YouGlassDebugEngine {
    func ensureSessionStarted() {
        lock.lock()
        let needsStart = !didStartSession
        lock.unlock()
        if needsStart {
            startSession()
        }
    }

    func ensureDiagnosticsDirectory() {
        // This path is used by the uncaught-exception handler. Do not take
        // the normal recording lock here because another thread may hold it
        // at the moment the exception is raised.
        try? fileManager.createDirectory(
            at: diagnosticsDirectory,
            withIntermediateDirectories: true
        )
    }

    func ensureDiagnosticsDirectoryLocked() {
        try? fileManager.createDirectory(
            at: diagnosticsDirectory,
            withIntermediateDirectories: true
        )
    }

    func readSessionStateLocked() -> YouGlassDebugSessionState? {
        let url = diagnosticsDirectory.appendingPathComponent("last-session.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(YouGlassDebugSessionState.self, from: data)
    }

    func writeSessionStateLocked(cleanTermination: Bool) {
        let state = YouGlassDebugSessionState(
            sessionID: sessionID,
            startedAt: sessionStartedAt,
            endedAt: cleanTermination ? Date() : nil,
            cleanTermination: cleanTermination,
            appVersion: appVersion,
            buildVersion: buildVersion
        )
        guard let data = try? makeEncoder().encode(state) else { return }
        let url = diagnosticsDirectory.appendingPathComponent("last-session.json")
        try? data.write(to: url, options: .atomic)
    }

    func makeEventLocked(
        level: YouGlassDebugLevel,
        category: String,
        message: String,
        metadata: [String: String]
    ) -> YouGlassDiagnosticEvent {
        let safeCategory = Self.sanitize(category)
        let safeMessage = Self.messageWithMetadata(message, metadata: metadata)
        return YouGlassDiagnosticEvent(
            id: UUID(),
            timestamp: Date(),
            uptime: ProcessInfo.processInfo.systemUptime,
            level: level,
            category: safeCategory,
            message: safeMessage,
            sessionID: sessionID
        )
    }

    func appendEventLocked(_ event: YouGlassDiagnosticEvent, persist: Bool) {
        events.append(event)
        if events.count > Self.maximumEventCount {
            events.removeFirst(events.count - Self.maximumEventCount)
        }

        guard persist, let sessionLogURL else { return }
        guard let data = try? makeEncoder().encode(event) else { return }
        var line = data
        line.append(10)

        if fileManager.fileExists(atPath: sessionLogURL.path),
           let handle = try? FileHandle(forWritingTo: sessionLogURL) {
            handle.seekToEndOfFile()
            try? handle.write(contentsOf: line)
            try? handle.close()
        } else {
            fileManager.createFile(atPath: sessionLogURL.path, contents: line)
        }
    }

    func writeUnifiedLog(for event: YouGlassDiagnosticEvent) {
        let message = event.category + ": " + event.message
        switch event.level {
        case .trace, .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .notice:
            logger.notice("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }
    }

    func installUncaughtExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            YouGlassDebugEngine.shared.handleUncaughtException(exception)
        }
    }

    func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
