import Foundation
import OSLog

extension YouGlassDebugEngine {
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
            hiddenWebKitBridgesEnabled: hiddenWebKitBridgesEnabled,
            parallaxMode: YouGlassRuntimeStabilityPolicy.parallaxMode.rawValue,
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
}
