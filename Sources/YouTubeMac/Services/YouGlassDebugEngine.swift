import Foundation
import OSLog

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

    static let maximumEventCount = 240
    static let schemaVersion = 3

    let lock = NSLock()
    let fileManager: FileManager
    let userDefaults: UserDefaults
    let logger = Logger(subsystem: "com.kevinhowe.YouGlass", category: "debug-engine")
    let diagnosticsDirectory: URL

    var events: [YouGlassDiagnosticEvent] = []
    var sessionID = UUID().uuidString
    var sessionStartedAt = Date()
    var sessionLogURL: URL?
    var didStartSession = false
    var previousSessionWasUnclean = false

    init(
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard,
        directoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.userDefaults = userDefaults
        self.diagnosticsDirectory = directoryURL ?? Self.defaultDiagnosticsDirectory(fileManager: fileManager)
    }
    var diagnosticsEnabled: Bool {
        userDefaults.bool(forKey: Self.diagnosticsEnabledKey)
    }

    var verboseLoggingEnabled: Bool {
        userDefaults.bool(forKey: Self.verboseLoggingKey)
    }

    var webKitBreadcrumbsEnabled: Bool {
        userDefaults.bool(forKey: Self.webKitBreadcrumbsKey)
    }

    var hiddenWebKitBridgesEnabled: Bool {
        YouGlassHiddenWebKitPolicy.isEnabled(defaults: userDefaults)
    }

    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
    }

    var buildVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "development"
    }

    var operatingSystem: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}
