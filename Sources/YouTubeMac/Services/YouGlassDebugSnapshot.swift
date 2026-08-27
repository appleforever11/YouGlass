import Foundation
import OSLog

extension YouGlassDebugEngine {
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
            parallaxMode: YouGlassRuntimeStabilityPolicy.parallaxMode.rawValue,
            previousSessionWasUnclean: previousSessionWasUnclean,
            recentEvents: events
        )
        lock.unlock()
        return snapshot
    }
}
