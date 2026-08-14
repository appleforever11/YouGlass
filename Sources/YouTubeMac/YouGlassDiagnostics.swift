import OSLog

enum YouGlassDiagnostics {
    static let app = Logger(subsystem: "com.kevinhowe.YouGlass", category: "app")
    static let api = Logger(subsystem: "com.kevinhowe.YouGlass", category: "api")
    static let feed = Logger(subsystem: "com.kevinhowe.YouGlass", category: "feed")
    static let auth = Logger(subsystem: "com.kevinhowe.YouGlass", category: "auth")
    static let playback = Logger(subsystem: "com.kevinhowe.YouGlass", category: "playback")
    static let pip = Logger(subsystem: "com.kevinhowe.YouGlass", category: "pip")
    static let layout = Logger(subsystem: "com.kevinhowe.YouGlass", category: "layout")

    static func record(
        _ level: YouGlassDebugLevel,
        category: String,
        message: String,
        metadata: [String: String] = [:]
    ) {
        YouGlassDebugEngine.shared.record(
            level,
            category: category,
            message: message,
            metadata: metadata
        )
    }

    static func breadcrumb(
        _ category: String,
        _ message: String,
        metadata: [String: String] = [:]
    ) {
        YouGlassDebugEngine.shared.breadcrumb(category, message, metadata: metadata)
    }
}
