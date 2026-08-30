import Foundation
import Security

enum KeychainStore {
    enum StorageMode: CaseIterable, Equatable {
        case dataProtection
        case login

        var usesDataProtectionKeychain: Bool {
            self == .dataProtection
        }
    }

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

        // Prefer the data-protection keychain, but always retain the login
        // keychain compatibility path. Some SwiftPM/ad-hoc macOS bundles can
        // reject one storage class after a rebuild while still allowing the
        // other. Both paths remain protected by Keychain.
        for mode in StorageMode.allCases {
            guard let value = readValue(
                query(
                    service: service,
                    account: account,
                    dataProtection: mode.usesDataProtectionKeychain
                )
            ) else {
                continue
            }

            cache[cacheKey] = .value(value)
            return value
        }

        cache[cacheKey] = .missing
        return nil
    }

    @discardableResult
    static func write(_ value: String, service: String, account: String) -> Bool {
        let cacheKey = "\(service)\u{0}\(account)"
        let data = Data(value.utf8)

        cacheLock.lock()
        defer { cacheLock.unlock() }

        let statuses = StorageMode.allCases.map { mode in
            upsert(
                data,
                query: query(
                    service: service,
                    account: account,
                    dataProtection: mode.usesDataProtectionKeychain
                )
            )
        }
        let didPersist = statuses.contains(errSecSuccess)

        if didPersist {
            cache[cacheKey] = .value(value)
        }
        return didPersist
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

}
