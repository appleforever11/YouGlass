import Foundation
@preconcurrency import WebKit

/// Reads homepage metadata with the app's web session without creating a
/// hidden WebKit rendering surface or calling a private recommendation API.
@MainActor
final class YouTubeHomepageClient {
    func load(maxResults: Int = 40) async -> YouTubeWebFeedResult {
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        let now = Date()
        let homeCookies = cookies.filter {
            let domain = $0.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            return (domain == "youtube.com" || domain == "www.youtube.com")
                && $0.path == "/" && ($0.expiresDate == nil || $0.expiresDate! > now)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 6
        configuration.timeoutIntervalForResource = 8
        let session = URLSession(configuration: configuration, delegate: HomepageRedirectPolicy(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: URL(string: "https://www.youtube.com/")!, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpShouldHandleCookies = false
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        for (key, value) in HTTPCookie.requestHeaderFields(with: homeCookies) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard !Task.isCancelled, (response as? HTTPURLResponse)?.statusCode == 200,
                  data.count <= 8_000_000, let html = String(data: data, encoding: .utf8) else { return .empty }
            return await Task.detached(priority: .userInitiated) {
                YouTubeHomepageParser.parse(html, limit: maxResults)
            }.value
        } catch {
            return .empty
        }
    }
}

private final class HomepageRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        // Never forward a manually supplied session header to another host.
        completionHandler(request.url?.host == "www.youtube.com" && request.url?.scheme == "https" ? request : nil)
    }
}

private extension WKHTTPCookieStore {
    func allCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            getAllCookies { continuation.resume(returning: $0) }
        }
    }
}
