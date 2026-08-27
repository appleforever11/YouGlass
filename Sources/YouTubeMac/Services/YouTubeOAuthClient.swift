import AppKit
import CryptoKit
import Foundation
import Network

struct YouTubeOAuthToken: Codable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date

    var isExpired: Bool {
        Date() >= expiresAt.addingTimeInterval(-60)
    }
}

final class YouTubeOAuthClient: @unchecked Sendable {
    static let shared = YouTubeOAuthClient()

    private let service = "com.kevinhowe.YouGlass"
    private let clientIDAccount = "GOOGLE_OAUTH_CLIENT_ID"
    private let clientSecretAccount = "GOOGLE_OAUTH_CLIENT_SECRET"
    private let tokenAccount = "GOOGLE_OAUTH_TOKEN"
    private let session = URLSession.shared

    var hasClientID: Bool {
        clientID != nil
    }

    var hasClientSecret: Bool {
        clientSecret != nil
    }

    func saveClientID(_ value: String) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        KeychainStore.write(clean, service: service, account: clientIDAccount)
    }

    func saveClientSecret(_ value: String) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        KeychainStore.write(clean, service: service, account: clientSecretAccount)
    }

    func clearStoredCredentials() {
        KeychainStore.remove(service: service, account: clientIDAccount)
        KeychainStore.remove(service: service, account: clientSecretAccount)
        KeychainStore.remove(service: service, account: tokenAccount)
    }

    private var clientID: String? {
        if let value = ProcessInfo.processInfo.environment["GOOGLE_OAUTH_CLIENT_ID"], !value.isEmpty {
            return value
        }
        return KeychainStore.read(service: service, account: clientIDAccount)
    }

    private var clientSecret: String? {
        if let value = ProcessInfo.processInfo.environment["GOOGLE_OAUTH_CLIENT_SECRET"], !value.isEmpty {
            return value
        }
        return KeychainStore.read(service: service, account: clientSecretAccount)
    }

    func validAccessToken() async throws -> String? {
        guard var token = storedToken() else { return nil }
        if token.isExpired {
            guard let refreshToken = token.refreshToken else { return nil }
            token = try await refresh(refreshToken: refreshToken)
            store(token)
        }
        return token.accessToken
    }

    func signIn() async throws -> YouTubeOAuthToken {
        guard let clientID else {
            throw OAuthError.missingClientID
        }

        let state = Self.randomVerifier()
        let receiver = try OAuthLoopbackReceiver(expectedState: state)
        let verifier = Self.randomVerifier()
        let challenge = Self.challenge(for: verifier)
        let redirectURI = receiver.redirectURI
        let scopes = [
            "https://www.googleapis.com/auth/youtube.readonly",
            "https://www.googleapis.com/auth/youtube.force-ssl"
        ].joined(separator: " ")

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "access_type", value: "offline"),
            // Reuse the existing Google grant when possible. Forcing consent
            // on every sign-in causes unnecessary account prompts and can
            // rotate the refresh token on repeated launches.
            URLQueryItem(name: "prompt", value: "select_account"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        _ = await MainActor.run {
            NSWorkspace.shared.open(components.url!)
        }

        let code = try await receiver.waitForCode()
        var token = try await exchange(code: code, redirectURI: redirectURI, verifier: verifier, clientID: clientID)
        // Google may omit refresh_token when the user has already granted the
        // scopes. Preserve the existing refresh token so relaunches can still
        // refresh without another interactive authorization.
        if token.refreshToken == nil {
            token.refreshToken = storedToken()?.refreshToken
        }
        store(token)
        return token
    }

    private func exchange(code: String, redirectURI: String, verifier: String, clientID: String) async throws -> YouTubeOAuthToken {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var values = [
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ]
        if let clientSecret { values["client_secret"] = clientSecret }
        request.httpBody = Self.formBody(values)

        let (data, urlResponse) = try await session.data(for: request)
        let response = try Self.decodeTokenResponse(data: data, response: urlResponse)
        return YouTubeOAuthToken(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn))
        )
    }

    private func refresh(refreshToken: String) async throws -> YouTubeOAuthToken {
        guard let clientID else {
            throw OAuthError.missingClientID
        }

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var values = [
            "client_id": clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        if let clientSecret { values["client_secret"] = clientSecret }
        request.httpBody = Self.formBody(values)

        let existing = storedToken()
        let (data, urlResponse) = try await session.data(for: request)
        let response = try Self.decodeTokenResponse(data: data, response: urlResponse)
        return YouTubeOAuthToken(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? existing?.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn))
        )
    }

    private func storedToken() -> YouTubeOAuthToken? {
        guard let raw = KeychainStore.read(service: service, account: tokenAccount),
              let data = raw.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(YouTubeOAuthToken.self, from: data)
    }

    private func store(_ token: YouTubeOAuthToken) {
        guard let data = try? JSONEncoder().encode(token),
              let raw = String(data: data, encoding: .utf8) else {
            return
        }
        KeychainStore.write(raw, service: service, account: tokenAccount)
    }

    private static func formBody(_ values: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return values
            .map { key, value in
                "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value)"
            }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }

    private static func randomVerifier() -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<96).map { _ in characters[Int.random(in: 0..<characters.count)] })
    }

    private static func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func decodeTokenResponse(data: Data, response: URLResponse) throws -> TokenResponse {
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let details = (try? JSONDecoder().decode(OAuthServerError.self, from: data))?.errorDescription
                ?? (try? JSONDecoder().decode(OAuthServerError.self, from: data))?.error
                ?? "Google rejected the OAuth token request."
            throw OAuthError.tokenExchange(details)
        }
        do {
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw OAuthError.tokenExchange("Google returned an invalid token response.")
        }
    }

    enum OAuthError: LocalizedError {
        case missingClientID
        case accessDenied(String)
        case invalidCallback
        case invalidState
        case timeout
        case tokenExchange(String)

        var errorDescription: String? {
            switch self {
            case .missingClientID:
                "Google OAuth client ID is not configured for YouGlass."
            case .accessDenied(let details):
                "Google authorization was denied: \(details)"
            case .invalidCallback:
                "Google returned an invalid authorization callback."
            case .invalidState:
                "Google authorization could not be verified. Please retry."
            case .timeout:
                "Google authorization timed out. Please retry."
            case .tokenExchange(let details):
                "Google authorization failed: \(details)"
            }
        }
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

private struct OAuthServerError: Decodable {
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

private final class OAuthLoopbackReceiver: @unchecked Sendable {
    let redirectURI: String

    private let listener: NWListener
    private let expectedState: String
    private var continuation: CheckedContinuation<String, Error>?

    init(expectedState: String) throws {
        self.expectedState = expectedState
        let port = NWEndpoint.Port(integerLiteral: UInt16.random(in: 49152...62000))
        listener = try NWListener(using: .tcp, on: port)
        redirectURI = "http://127.0.0.1:\(port.rawValue)/oauth2redirect"
    }

    func waitForCode() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener.start(queue: .main)
            DispatchQueue.main.asyncAfter(deadline: .now() + 180) { [weak self] in
                self?.finish(.failure(YouTubeOAuthClient.OAuthError.timeout), connection: nil)
            }
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, error in
            guard let self else { return }

            if let error {
                self.finish(.failure(error), connection: connection)
                return
            }

            guard let data,
                  let request = String(data: data, encoding: .utf8),
                  let firstLine = request.components(separatedBy: "\r\n").first,
                  let path = firstLine.split(separator: " ").dropFirst().first,
                  let components = URLComponents(string: "http://127.0.0.1\(path)") else {
                self.finish(.failure(YouTubeOAuthClient.OAuthError.invalidCallback), connection: connection)
                return
            }

            let query = components.queryItems ?? []
            if let error = query.first(where: { $0.name == "error" })?.value {
                let details = query.first(where: { $0.name == "error_description" })?.value ?? error
                self.finish(.failure(YouTubeOAuthClient.OAuthError.accessDenied(details)), connection: connection)
                return
            }
            guard query.first(where: { $0.name == "state" })?.value == self.expectedState else {
                self.finish(.failure(YouTubeOAuthClient.OAuthError.invalidState), connection: connection)
                return
            }
            guard let code = query.first(where: { $0.name == "code" })?.value else {
                self.finish(.failure(YouTubeOAuthClient.OAuthError.invalidCallback), connection: connection)
                return
            }

            self.finish(.success(code), connection: connection)
        }
    }

    private func finish(_ result: Result<String, Error>, connection: NWConnection?) {
        guard let continuation else {
            connection?.cancel()
            return
        }
        let succeeded = (try? result.get()) != nil
        let title = succeeded ? "YouGlass is connected." : "YouGlass could not connect."
        let body = "<html><body style='font-family:-apple-system;margin:48px'><h2>\(title)</h2><p>You can close this window and return to YouGlass.</p></body></html>"
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection?.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection?.cancel()
        })
        listener.cancel()

        switch result {
        case .success(let code):
            continuation.resume(returning: code)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
        self.continuation = nil
    }
}
