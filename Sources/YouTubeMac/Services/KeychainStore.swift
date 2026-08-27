import Foundation
import Security

enum KeychainStore {
    private enum CachedValue {
        case value(String)
        case missing
    }

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cache: [String: CachedValue] = [:]
    private static let legacyMigrationPrefix = "YouGlass.KeychainMigration.v1"

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

        // The data-protection keychain uses the modern iOS-style access model on
        // macOS. It avoids binding a credential to the code hash of an ad-hoc or
        // frequently rebuilt development bundle.
        if let value = readValue(query(service: service, account: account, dataProtection: true)) {
            cache[cacheKey] = .value(value)
            return value
        }

        // Existing YouGlass releases used the legacy login keychain. Give each
        // old item one migration attempt so an update can preserve the account,
        // then never query that ACL again after the item has been copied.
        let migrationKey = legacyMigrationKey(service: service, account: account)
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            cache[cacheKey] = .missing
            return nil
        }
        UserDefaults.standard.set(true, forKey: migrationKey)

        guard let value = readValue(query(service: service, account: account, dataProtection: false)) else {
            cache[cacheKey] = .missing
            return nil
        }

        _ = upsert(
            Data(value.utf8),
            query: query(service: service, account: account, dataProtection: true)
        )
        cache[cacheKey] = .value(value)
        return value
    }

    static func write(_ value: String, service: String, account: String) {
        let cacheKey = "\(service)\u{0}\(account)"
        let data = Data(value.utf8)
        let query = query(service: service, account: account, dataProtection: true)

        cacheLock.lock()
        defer { cacheLock.unlock() }

        if upsert(data, query: query) == errSecSuccess {
            cache[cacheKey] = .value(value)
        }
    }

    static func remove(service: String, account: String) {
        let cacheKey = "\(service)\u{0}\(account)"
        let dataProtectionQuery = query(service: service, account: account, dataProtection: true)
        let legacyQuery = query(service: service, account: account, dataProtection: false)

        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache.removeValue(forKey: cacheKey)
        _ = SecItemDelete(dataProtectionQuery as CFDictionary)
        _ = SecItemDelete(legacyQuery as CFDictionary)
        UserDefaults.standard.removeObject(forKey: legacyMigrationKey(service: service, account: account))
    }

    private static func query(service: String, account: String, dataProtection: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if dataProtection {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }

    private static func readValue(_ baseQuery: [String: Any]) -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func upsert(_ data: Data, query: [String: Any]) -> OSStatus {
        let update: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        guard status == errSecItemNotFound else { return status }

        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(item as CFDictionary, nil)
    }

    private static func legacyMigrationKey(service: String, account: String) -> String {
        "\(legacyMigrationPrefix).\(service).\(account)"
    }
}
