import Foundation
import WebKit

extension WKWebViewConfiguration {
    /// macOS 27 beta can crash in WKMaterialHostingSupport while committing a
    /// remote layer tree containing CSS backdrop effects. YouGlass does not
    /// depend on those effects, so suppress them before page styles are
    /// painted while leaving ordinary compositing and video layers intact.
    @MainActor
    func youGlassDisableWebMaterialsOnAffectedSystems() {
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 else { return }
        let source = #"""
        (() => {
          const style = document.createElement('style');
          style.id = 'youglass-disable-web-materials';
          style.textContent = `
            *, *::before, *::after {
              -webkit-backdrop-filter: none !important;
              backdrop-filter: none !important;
            }
          `;
          (document.documentElement || document).appendChild(style);
        })();
        """#
        userContentController.addUserScript(
            WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
    }
}

extension WKWebView {
    /// WebKit's Swift async importer declares the JavaScript result as
    /// non-optional even though the Objective-C callback can return nil (for
    /// example, for `undefined` or when evaluation fails). On macOS 27 that
    /// mismatch traps in the generated continuation thunk before callers can
    /// catch the error. Preserve the callback API's true optionality here.
    @MainActor
    func youGlassEvaluateJavaScript(_ script: String) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            evaluateJavaScript(script) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result as? String)
                }
            }
        }
    }
}

actor YouGlassRequestGate {
    private var nextAllowedDate = Date.distantPast

    func wait(minimumInterval: TimeInterval) async {
        let now = Date()
        let scheduledDate = max(now, nextAllowedDate)
        let delay = scheduledDate.timeIntervalSince(now)
        // Reserve this request's slot before the suspension point. Actors are
        // re-entrant while sleeping, so advancing afterward would allow
        // concurrent callers to reserve the same slot.
        nextAllowedDate = scheduledDate.addingTimeInterval(max(0, minimumInterval))
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }

    func reset() {
        nextAllowedDate = .distantPast
    }
}

actor YouGlassResponseCache {
    private struct Entry {
        let data: Data
        let expiresAt: Date
        let createdAt: Date
    }

    private var entries: [String: Entry] = [:]
    private let maxEntries: Int

    init(maxEntries: Int = 32) {
        self.maxEntries = max(1, maxEntries)
    }

    func data(forKey key: String, now: Date = Date()) -> Data? {
        guard let entry = entries[key] else { return nil }
        guard entry.expiresAt > now else {
            entries.removeValue(forKey: key)
            return nil
        }
        return entry.data
    }

    func insert(_ data: Data, forKey key: String, ttl: TimeInterval, now: Date = Date()) {
        guard ttl > 0 else { return }
        entries[key] = Entry(
            data: data,
            expiresAt: now.addingTimeInterval(ttl),
            createdAt: now
        )
        trimIfNeeded()
    }

    func removeAll() {
        entries.removeAll(keepingCapacity: true)
    }

    private func trimIfNeeded() {
        guard entries.count > maxEntries else { return }
        let overflow = entries.count - maxEntries
        let oldestKeys = entries
            .sorted { $0.value.createdAt < $1.value.createdAt }
            .prefix(overflow)
            .map(\.key)
        oldestKeys.forEach { entries.removeValue(forKey: $0) }
    }
}

enum YouGlassCachePolicy {
    static func isFresh(
        lastUpdated: Date?,
        now: Date = Date(),
        maxAge: TimeInterval
    ) -> Bool {
        guard let lastUpdated, maxAge >= 0 else { return false }
        let age = now.timeIntervalSince(lastUpdated)
        return age >= 0 && age <= maxAge
    }

    static func age(of lastUpdated: Date?, now: Date = Date()) -> TimeInterval? {
        guard let lastUpdated else { return nil }
        return max(0, now.timeIntervalSince(lastUpdated))
    }
}

let youGlassSharedRequestGate = YouGlassRequestGate()
let youGlassSharedResponseCache = YouGlassResponseCache()
