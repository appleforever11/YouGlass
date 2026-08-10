import Foundation
import Security

enum KeychainStore {
    private enum CachedValue {
        case value(String)
        case missing
    }

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cache: [String: CachedValue] = [:]

    static func read(service: String, account: String) -> String? {
        let cacheKey = "\(service)\u{0}\(account)"

        // SwiftUI can evaluate computed properties many times per frame. Keep the
        // Security query serialized and perform it at most once per credential.
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if let cached = cache[cacheKey] {
            switch cached {
            case .value(let value):
                return value
            case .missing:
                return nil
            }
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            cache[cacheKey] = .missing
            return nil
        }
        cache[cacheKey] = .value(value)
        return value
    }

    static func write(_ value: String, service: String, account: String) {
        let cacheKey = "\(service)\u{0}\(account)"
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let update: [String: Any] = [
            kSecValueData as String: data,
            // Keep credentials available after login so a signed, relaunched
            // build does not repeatedly ask for interactive keychain access.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        cacheLock.lock()
        defer { cacheLock.unlock() }

        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            if addStatus == errSecSuccess {
                cache[cacheKey] = .value(value)
            }
        } else if status == errSecSuccess {
            cache[cacheKey] = .value(value)
        }
    }

    static func remove(service: String, account: String) {
        let cacheKey = "\(service)\u{0}\(account)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache.removeValue(forKey: cacheKey)
        _ = SecItemDelete(query as CFDictionary)
    }
}
