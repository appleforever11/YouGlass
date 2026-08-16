import Foundation

enum YouGlassParallaxMode: String, Codable, Sendable {
    case pointerTilt = "pointer-tilt"
    case stableHover = "stable-hover"
}

/// Centralizes platform-specific safety decisions so the UI, WebKit bridges,
/// and diagnostic export describe the same runtime mode.
enum YouGlassRuntimeStabilityPolicy {
    static func isAffectedSystem(_ version: OperatingSystemVersion) -> Bool {
        version.majorVersion >= 26
    }

    static var isAffectedSystem: Bool {
        isAffectedSystem(ProcessInfo.processInfo.operatingSystemVersion)
    }

    static func parallaxMode(for version: OperatingSystemVersion) -> YouGlassParallaxMode {
        isAffectedSystem(version) ? .stableHover : .pointerTilt
    }

    static var parallaxMode: YouGlassParallaxMode {
        parallaxMode(for: ProcessInfo.processInfo.operatingSystemVersion)
    }
}
