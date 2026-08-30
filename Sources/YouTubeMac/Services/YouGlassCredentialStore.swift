import Foundation

/// Stable Keychain identities for credentials that must survive app updates.
///
/// The API key is deliberately kept separate from UserDefaults, diagnostics,
/// release artifacts, and the source tree. The legacy service is read once so
/// older YouGlass builds can carry the key forward to the current identity.
enum YouGlassCredentialStore {
    static let service = "com.kevinhowe.YouGlass"
    static let legacyService = "com.kevinhowe.YouTubeMac"
    static let dataAPIKeyAccount = "YOUTUBE_API_KEY"

    static func readDataAPIKey() -> String? {
        if let value = KeychainStore.read(service: service, account: dataAPIKeyAccount) {
            return value
        }

        guard let legacyValue = KeychainStore.read(service: legacyService, account: dataAPIKeyAccount) else {
            return nil
        }

        // Preserve the key under the stable current service so future builds
        // no longer depend on the pre-2.0 bundle identity.
        KeychainStore.write(legacyValue, service: service, account: dataAPIKeyAccount)
        return legacyValue
    }

    @discardableResult
    static func writeDataAPIKey(_ value: String) -> Bool {
        KeychainStore.write(value, service: service, account: dataAPIKeyAccount)
    }

    static func removeDataAPIKey() {
        KeychainStore.remove(service: service, account: dataAPIKeyAccount)
        KeychainStore.remove(service: legacyService, account: dataAPIKeyAccount)
    }
}
