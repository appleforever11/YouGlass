import AppKit

/// Best-effort native trackpad feedback; other pointing devices remain usable.
@MainActor
enum YouGlassHoverHaptics {
    private static var lastPulse = Date.distantPast

    static func thumbnailEntered() {
        guard UserDefaults.standard.object(forKey: "YouGlass.thumbnailHaptics") as? Bool ?? true else { return }
        let now = Date()
        guard now.timeIntervalSince(lastPulse) >= 0.08 else { return }
        lastPulse = now
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}
