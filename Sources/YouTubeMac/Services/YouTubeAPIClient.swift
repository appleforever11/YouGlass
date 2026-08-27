import Foundation
import Security

struct YouTubeAPIClient: Sendable {
    let apiKey: String?
    let oauth: YouTubeOAuthClient
    let session: URLSession
    let requestGate: YouGlassRequestGate
    let responseCache: YouGlassResponseCache

    init(
        apiKey: String? = YouTubeAPIClient.resolveAPIKey(),
        oauth: YouTubeOAuthClient = .shared,
        session: URLSession = .shared,
        requestGate: YouGlassRequestGate = youGlassSharedRequestGate,
        responseCache: YouGlassResponseCache = youGlassSharedResponseCache
    ) {
        self.apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? apiKey : nil
        self.oauth = oauth
        self.session = session
        self.requestGate = requestGate
        self.responseCache = responseCache
    }

    var canConnect: Bool {
        apiKey != nil
    }

    func hasCredentials() async -> Bool {
        if apiKey != nil { return true }
        return (try? await oauth.validAccessToken()) != nil
    }

    static func resolveAPIKey() -> String? {
        if let key = ProcessInfo.processInfo.environment["YOUTUBE_API_KEY"], !key.isEmpty {
            return key
        }

        return KeychainStore.read(service: "com.kevinhowe.YouGlass", account: "YOUTUBE_API_KEY")
            ?? KeychainStore.read(service: "com.kevinhowe.YouTubeMac", account: "YOUTUBE_API_KEY")
    }
}
