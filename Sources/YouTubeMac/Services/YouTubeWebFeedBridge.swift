import AppKit
import Foundation
import OSLog
@preconcurrency import WebKit

struct YouTubeWebFeedResult {
    let videos: [VideoItem]
    let isSignedIn: Bool
    let profileImageURL: URL?
    let diagnostics: String

    init(
        videos: [VideoItem],
        isSignedIn: Bool,
        profileImageURL: URL? = nil,
        diagnostics: String
    ) {
        self.videos = videos
        self.isSignedIn = isSignedIn
        self.profileImageURL = profileImageURL
        self.diagnostics = diagnostics
    }

    static let empty = YouTubeWebFeedResult(
        videos: [],
        isSignedIn: false,
        diagnostics: "No YouTube video cards were available"
    )
}

@MainActor
final class YouTubeWebFeedBridge: NSObject, WKNavigationDelegate {
    static let shared = YouTubeWebFeedBridge()

    let logger = Logger(subsystem: "com.kevinhowe.YouGlass", category: "YouTubeWebFeed")
    var webView: WKWebView?
    var hostWindow: NSWindow?
    var continuation: CheckedContinuation<YouTubeWebFeedResult, Never>?
    var extractionTask: Task<Void, Never>?
    var activeNavigation: WKNavigation?
    var requestGeneration = 0
    var requestActive = false
    var requestWaiters: [CheckedContinuation<Void, Never>] = []
    var maxResults = 20
    var sessionCookiePresent = false
    var requestLabel = "YouTube homepage"

    static let sessionCookieNames: Set<String> = [
        "APISID",
        "HSID",
        "LOGIN_INFO",
        "SAPISID",
        "SID",
        "SSID",
        "__Secure-1PAPISID",
        "__Secure-1PSID",
        "__Secure-1PSIDTS",
        "__Secure-3PAPISID",
        "__Secure-3PSID",
        "__Secure-3PSIDTS"
    ]
}
