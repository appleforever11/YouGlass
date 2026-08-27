import Foundation

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
    let parallaxMode: String
    let previousSessionWasUnclean: Bool
    let recentEvents: [YouGlassDiagnosticEvent]
}

struct YouGlassDebugSessionState: Codable {
    let sessionID: String
    let startedAt: Date
    let endedAt: Date?
    let cleanTermination: Bool
    let appVersion: String
    let buildVersion: String
}

struct YouGlassDebugCrashReport: Codable {
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
    let hiddenWebKitBridgesEnabled: Bool
    let parallaxMode: String
    let callStack: [String]
    let recentEvents: [YouGlassDiagnosticEvent]
}
