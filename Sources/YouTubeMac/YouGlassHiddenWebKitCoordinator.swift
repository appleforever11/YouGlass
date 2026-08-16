import Foundation

/// Controls the legacy signed-in-session metadata path. A hidden WKWebView
/// still owns a remote layer tree even when it is offscreen, so this path is
/// opt-in while the native/API path is the stable default.
enum YouGlassHiddenWebKitPolicy {
    static let enabledKey = "YouGlass.debug.hiddenWebKitBridgesEnabled"

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: enabledKey)
    }

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: enabledKey)
    }
}

/// Serializes the opt-in offscreen YouTube metadata pages. A hidden WKWebView
/// still owns a remote layer tree, so concurrent bridges create avoidable
/// commit and teardown pressure even though none of the pages are visible.
@MainActor
final class YouGlassHiddenWebKitCoordinator {
    static let shared = YouGlassHiddenWebKitCoordinator()

    private var activeBridge: String?
    private var activeSince: Date?
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire(_ bridge: String) async {
        while activeBridge != nil {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }

        activeBridge = bridge
        activeSince = Date()
        YouGlassDiagnostics.record(
            .debug,
            category: "webkit",
            message: "Hidden WebKit bridge acquired",
            metadata: ["bridge": bridge]
        )
    }

    func release(_ bridge: String) {
        guard activeBridge == bridge else {
            YouGlassDiagnostics.record(
                .warning,
                category: "webkit",
                message: "Hidden WebKit bridge release ignored",
                metadata: ["bridge": bridge, "active": activeBridge ?? "none"]
            )
            return
        }

        let duration = activeSince.map { Date().timeIntervalSince($0) } ?? 0
        activeBridge = nil
        activeSince = nil
        YouGlassDiagnostics.record(
            .debug,
            category: "webkit",
            message: "Hidden WebKit bridge released",
            metadata: [
                "bridge": bridge,
                "durationMs": String(Int(duration * 1000))
            ]
        )

        guard !waiters.isEmpty else { return }
        let next = waiters.removeFirst()
        next.resume()
    }
}

actor YouGlassRateLimitState {
    private var blockedUntil = Date.distantPast

    func waitIfBlocked() async {
        let delay = blockedUntil.timeIntervalSinceNow
        guard delay > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    func markRateLimited(cooldown: TimeInterval = 30) {
        blockedUntil = max(blockedUntil, Date().addingTimeInterval(cooldown))
    }

    func reset() {
        blockedUntil = .distantPast
    }
}

let youGlassSharedRateLimitState = YouGlassRateLimitState()
