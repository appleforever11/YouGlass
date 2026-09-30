import Foundation

/// A feature owns one replaceable task and rejects responses from retired tasks.
@MainActor
final class YouGlassRequestLifecycle {
    private(set) var generation = 0
    var task: Task<Void, Never>?

    @discardableResult
    func invalidate() -> Int {
        task?.cancel()
        task = nil
        generation &+= 1
        return generation
    }

    func accepts(_ token: Int?) -> Bool {
        !Task.isCancelled && (token == nil || token == generation)
    }

    func finish(_ token: Int) {
        guard token == generation else { return }
        task = nil
    }
}
