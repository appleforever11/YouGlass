import Foundation
import OSLog

enum YouGlassDebugLevel: String, Codable, CaseIterable, Sendable {
    case trace
    case debug
    case info
    case notice
    case warning
    case error
}

struct YouGlassDiagnosticEvent: Codable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let uptime: TimeInterval
    let level: YouGlassDebugLevel
    let category: String
    let message: String
    let sessionID: String
}

struct YouGlassDebugSnapshot: Codable, Sendable {
    let schemaVersion: Int
    let generatedAt: Date
    let appVersion: String
    let buildVersion: String
    let operatingSystem: String
    let architecture: String
    let processName: String
    let sessionID: String
    let sessionStartedAt: Date
    let diagnosticsEnabled: Bool
    let verboseLoggingEnabled: Bool
    let webKitBreadcrumbsEnabled: Bool
    let hiddenWebKitBridgesEnabled: Bool
    let previousSessionWasUnclean: Bool
    let recentEvents: [YouGlassDiagnosticEvent]
}

private struct YouGlassDebugSessionState: Codable {
    let sessionID: String
    let startedAt: Date
    let endedAt: Date?
    let cleanTermination: Bool
    let appVersion: String
    let buildVersion: String
}

private struct YouGlassDebugCrashReport: Codable {
    let schemaVersion: Int
    let capturedAt: Date
    let appVersion: String
    let buildVersion: String
    let operatingSystem: String
    let architecture: String
    let processName: String
    let sessionID: String
    let exceptionName: String
    let exceptionReason: String
    let callStack: [String]
    let recentEvents: [YouGlassDiagnosticEvent]
}

/// A small, privacy-safe diagnostic layer that complements native macOS crash
/// reports with the last known YouGlass lifecycle and feature breadcrumbs.
///
/// It intentionally stores only bounded, redacted metadata. It cannot replace
/// a macOS crash report for memory faults, framework crashes, or aborts that
/// happen before the application delegate is initialized.
final class YouGlassDebugEngine: @unchecked Sendable {
    static let shared = YouGlassDebugEngine()

    static let diagnosticsEnabledKey = "YouGlass.debug.diagnosticsEnabled"
    static let verboseLoggingKey = "YouGlass.debug.verboseLogging"
    static let webKitBreadcrumbsKey = "YouGlass.debug.webKitBreadcrumbs"

    private static let maximumEventCount = 240
    private static let schemaVersion = 2

    private let lock = NSLock()
    private let fileManager: FileManager
    private let userDefaults: UserDefaults
    private let logger = Logger(subsystem: "com.kevinhowe.YouGlass", category: "debug-engine")
    private let diagnosticsDirectory: URL

    private var events: [YouGlassDiagnosticEvent] = []
    private var sessionID = UUID().uuidString
    private var sessionStartedAt = Date()
    private var sessionLogURL: URL?
    private var didStartSession = false
    private var previousSessionWasUnclean = false

    init(
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard,
        directoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.userDefaults = userDefaults
        self.diagnosticsDirectory = directoryURL ?? Self.defaultDiagnosticsDirectory(fileManager: fileManager)
    }

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

    func makeSnapshot() -> YouGlassDebugSnapshot {
        ensureSessionStarted()

        lock.lock()
        let snapshot = YouGlassDebugSnapshot(
            schemaVersion: Self.schemaVersion,
            generatedAt: Date(),
            appVersion: appVersion,
            buildVersion: buildVersion,
            operatingSystem: operatingSystem,
            architecture: architecture,
            processName: ProcessInfo.processInfo.processName,
            sessionID: sessionID,
            sessionStartedAt: sessionStartedAt,
            diagnosticsEnabled: diagnosticsEnabled,
            verboseLoggingEnabled: verboseLoggingEnabled,
            webKitBreadcrumbsEnabled: webKitBreadcrumbsEnabled,
            hiddenWebKitBridgesEnabled: hiddenWebKitBridgesEnabled,
            previousSessionWasUnclean: previousSessionWasUnclean,
            recentEvents: events
        )
        lock.unlock()
        return snapshot
    }

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

    func handleUncaughtException(_ exception: NSException) {
        let capturedAt = Date()
        let fallbackSessionID = UUID().uuidString

        // An exception can arrive while another thread is recording. Never
        // block the crash handler on a potentially held lock.
        let acquiredLock = lock.try()
        let reportSessionID: String
        let reportEvents: [YouGlassDiagnosticEvent]
        if acquiredLock {
            reportSessionID = sessionID
            reportEvents = events
            lock.unlock()
        } else {
            reportSessionID = fallbackSessionID
            reportEvents = []
        }

        let report = YouGlassDebugCrashReport(
            schemaVersion: Self.schemaVersion,
            capturedAt: capturedAt,
            appVersion: appVersion,
            buildVersion: buildVersion,
            operatingSystem: operatingSystem,
            architecture: architecture,
            processName: ProcessInfo.processInfo.processName,
            sessionID: reportSessionID,
            exceptionName: Self.sanitize(exception.name.rawValue),
            exceptionReason: Self.sanitize(exception.reason ?? "No exception reason provided"),
            callStack: exception.callStackSymbols.map(Self.sanitize),
            recentEvents: reportEvents
        )

        let crashURL = diagnosticsDirectory.appendingPathComponent(
            "exception-" + Self.filenameTimestamp(capturedAt) + "-" + String(reportSessionID.prefix(8)) + ".json",
            isDirectory: false
        )
        ensureDiagnosticsDirectory()
        if let data = try? makeEncoder().encode(report) {
            try? data.write(to: crashURL, options: .atomic)
        }
    }

    private var diagnosticsEnabled: Bool {
        userDefaults.bool(forKey: Self.diagnosticsEnabledKey)
    }

    private var verboseLoggingEnabled: Bool {
        userDefaults.bool(forKey: Self.verboseLoggingKey)
    }

    private var webKitBreadcrumbsEnabled: Bool {
        userDefaults.bool(forKey: Self.webKitBreadcrumbsKey)
    }

    private var hiddenWebKitBridgesEnabled: Bool {
        YouGlassHiddenWebKitPolicy.isEnabled(defaults: userDefaults)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
    }

    private var buildVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "development"
    }

    private var operatingSystem: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    private var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    private func ensureSessionStarted() {
        lock.lock()
        let needsStart = !didStartSession
        lock.unlock()
        if needsStart {
            startSession()
        }
    }

    private func ensureDiagnosticsDirectory() {
        // This path is used by the uncaught-exception handler. Do not take
        // the normal recording lock here because another thread may hold it
        // at the moment the exception is raised.
        try? fileManager.createDirectory(
            at: diagnosticsDirectory,
            withIntermediateDirectories: true
        )
    }

    private func ensureDiagnosticsDirectoryLocked() {
        try? fileManager.createDirectory(
            at: diagnosticsDirectory,
            withIntermediateDirectories: true
        )
    }

    private func readSessionStateLocked() -> YouGlassDebugSessionState? {
        let url = diagnosticsDirectory.appendingPathComponent("last-session.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(YouGlassDebugSessionState.self, from: data)
    }

    private func writeSessionStateLocked(cleanTermination: Bool) {
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

    private func makeEventLocked(
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

    private func appendEventLocked(_ event: YouGlassDiagnosticEvent, persist: Bool) {
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

    private func writeUnifiedLog(for event: YouGlassDiagnosticEvent) {
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

    private func installUncaughtExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            YouGlassDebugEngine.shared.handleUncaughtException(exception)
        }
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func defaultDiagnosticsDirectory(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseURL
            .appendingPathComponent("YouGlass", isDirectory: true)
            .appendingPathComponent("Diagnostics", isDirectory: true)
    }

    private static func messageWithMetadata(_ message: String, metadata: [String: String]) -> String {
        let safeMessage = sanitize(message)
        guard !metadata.isEmpty else { return safeMessage }

        let details = metadata.keys.sorted().compactMap { key -> String? in
            guard let value = metadata[key] else { return nil }
            return "\(sanitize(key))=\(sanitize(value))"
        }.joined(separator: ", ")
        guard !details.isEmpty else { return safeMessage }
        return sanitize("\(safeMessage) [\(details)]")
    }

    private static func sanitize(_ value: String) -> String {
        let compact = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        let redacted = compact.replacingOccurrences(
            of: #"(?i)(?:authorization|cookie|set-cookie)\s*[:=]\s*[^,;\]]+|(?:api[_-]?key|key|access[_-]?token|refresh[_-]?token|client[_-]?secret)\s*[:=]\s*[^\s,;]+"#,
            with: "<redacted>",
            options: .regularExpression
        )
        return String(redacted.prefix(700))
    }

    private static func filenameTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
