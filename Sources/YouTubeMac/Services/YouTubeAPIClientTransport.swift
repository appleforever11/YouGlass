import Foundation

extension YouTubeAPIClient {
    func data(
        from components: URLComponents,
        preferOAuth: Bool = true,
        cacheTTL: TimeInterval = 20
    ) async throws -> Data {
        guard let url = components.url else {
            throw YouTubeAPIError.invalidRequest("YouTube request URL could not be constructed.")
        }

        if preferOAuth, let token = try await oauth.validAccessToken() {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            // OAuth responses can be account-specific, so do not share them
            // through the public response cache.
            return try await requestData(request)
        }

        guard let apiKey else {
            throw YouTubeAPIError.authenticationRequired
        }
        var authenticated = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var queryItems = authenticated.queryItems ?? []
        queryItems.append(URLQueryItem(name: "key", value: apiKey))
        authenticated.queryItems = queryItems
        // Cache only API-key responses. The cache key intentionally excludes
        // the key itself so it never becomes part of the in-memory cache map.
        return try await requestData(
            URLRequest(url: authenticated.url!),
            cacheKey: url.absoluteString,
            cacheTTL: cacheTTL
        )
    }

    func authorizedData(from url: URL, token: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await requestData(request)
    }

    func requestData(
        _ request: URLRequest,
        cacheKey: String? = nil,
        cacheTTL: TimeInterval = 20
    ) async throws -> Data {
        if let cacheKey, let cached = await responseCache.data(forKey: cacheKey) {
            YouGlassDiagnostics.api.debug("Using cached YouTube response for \(request.url?.path ?? "/", privacy: .public)")
            return cached
        }

        let method = (request.httpMethod ?? "GET").uppercased()
        let canRetry = method == "GET" || method == "HEAD"
        var attempt = 0

        while true {
            let requestStartedAt = Date()
            do {
                // Keep bursts from the feed, search, comments, and channel
                // paths below the quota/rate-limit threshold.
                await youGlassSharedRateLimitState.waitIfBlocked()
                await requestGate.wait(minimumInterval: 0.35)
                let requestPath = request.url?.path ?? "/"
                YouGlassDiagnostics.api.debug("YouTube request \(requestPath, privacy: .public)")
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw YouTubeAPIError.invalidResponse("YouTube returned a non-HTTP response.")
                }

                guard (200..<300).contains(httpResponse.statusCode) else {
                    let apiError = YouTubeAPIError.httpStatus(
                        httpResponse.statusCode,
                        reason: Self.apiErrorReason(from: data),
                        message: Self.apiErrorMessage(from: data)
                    )
                    if httpResponse.statusCode == 429 {
                        await youGlassSharedRateLimitState.markRateLimited()
                        YouGlassDiagnostics.record(
                            .warning,
                            category: "api",
                            message: "YouTube API rate limit cooldown started",
                            metadata: ["cooldownSeconds": "30", "path": requestPath]
                        )
                    }
                    guard canRetry, apiError.isRetryable, attempt < 2 else {
                        YouGlassDiagnostics.api.error("YouTube request failed with HTTP \(httpResponse.statusCode, privacy: .public)")
                        YouGlassDiagnostics.record(
                            .error,
                            category: "api",
                            message: "YouTube request failed",
                            metadata: [
                                "path": requestPath,
                                "status": String(httpResponse.statusCode),
                                "attempt": String(attempt + 1),
                                "error": apiError.localizedDescription
                            ]
                        )
                        throw apiError
                    }
                    if YouGlassDebugEngine.shared.isVerboseLoggingEnabled {
                        YouGlassDiagnostics.record(
                            .notice,
                            category: "api",
                            message: "Retrying a transient YouTube request",
                            metadata: [
                                "path": requestPath,
                                "status": String(httpResponse.statusCode),
                                "attempt": String(attempt + 1)
                            ]
                        )
                    }
                    try await Self.waitBeforeRetry(attempt: attempt)
                    attempt += 1
                    continue
                }

                if YouGlassDebugEngine.shared.isVerboseLoggingEnabled {
                    YouGlassDiagnostics.record(
                        .debug,
                        category: "api",
                        message: "YouTube request completed",
                        metadata: [
                            "path": requestPath,
                            "status": String(httpResponse.statusCode),
                            "durationMs": String(Int(Date().timeIntervalSince(requestStartedAt) * 1000))
                        ]
                    )
                }

                if let cacheKey {
                    await responseCache.insert(data, forKey: cacheKey, ttl: cacheTTL)
                }
                return data
            } catch let error as YouTubeAPIError {
                if case .httpStatus = error {
                    // HTTP failures are recorded at the status check above.
                } else {
                    YouGlassDiagnostics.record(
                        .error,
                        category: "api",
                        message: "YouTube API request ended with an error",
                        metadata: [
                            "path": request.url?.path ?? "/",
                            "attempt": String(attempt + 1),
                            "error": error.localizedDescription
                        ]
                    )
                }
                throw error
            } catch {
                guard canRetry, attempt < 2 else {
                    YouGlassDiagnostics.record(
                        .error,
                        category: "api",
                        message: "YouTube request ended with a transport error",
                        metadata: [
                            "path": request.url?.path ?? "/",
                            "attempt": String(attempt + 1),
                            "error": error.localizedDescription
                        ]
                    )
                    throw error
                }
                if YouGlassDebugEngine.shared.isVerboseLoggingEnabled {
                    YouGlassDiagnostics.record(
                        .notice,
                        category: "api",
                        message: "Retrying a transport error",
                        metadata: [
                            "path": request.url?.path ?? "/",
                            "attempt": String(attempt + 1),
                            "error": error.localizedDescription
                        ]
                    )
                }
                try await Self.waitBeforeRetry(attempt: attempt)
                attempt += 1
            }
        }
    }

    private static func waitBeforeRetry(attempt: Int) async throws {
        let delays: [UInt64] = [250_000_000, 750_000_000]
        try await Task.sleep(nanoseconds: delays[min(attempt, delays.count - 1)])
    }

    private static func apiErrorReason(from data: Data) -> String? {
        (try? JSONDecoder().decode(YouTubeAPIErrorEnvelope.self, from: data))?.error?.errors?.first?.reason
    }

    private static func apiErrorMessage(from data: Data) -> String? {
        (try? JSONDecoder().decode(YouTubeAPIErrorEnvelope.self, from: data))?.error?.message
    }

}
