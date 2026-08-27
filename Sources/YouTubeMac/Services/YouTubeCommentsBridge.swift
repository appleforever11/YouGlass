import AppKit
import Foundation
import OSLog
@preconcurrency import WebKit

// The Data API remains the authoritative path when an API key or OAuth token
// is configured. This offscreen bridge makes public comments available from
// the user's existing YouTube web session when those API credentials are not.
@MainActor
final class YouTubeCommentsBridge: NSObject, WKNavigationDelegate, WKUIDelegate {
    static let shared = YouTubeCommentsBridge()

    let logger = Logger(subsystem: "com.kevinhowe.YouGlass", category: "YouTubeComments")
    var webView: WKWebView?
    var hostWindow: NSWindow?
    var requestedVideoID: String?
    var loadedVideoID: String?
    var navigationContinuation: CheckedContinuation<Bool, Never>?
    var navigationTimeout: Task<Void, Never>?
    var activeNavigation: WKNavigation?
    var requestGeneration = 0
    var maxResults = 24
    var commentOffset = 0
    var continuationTokens: [String: [Int: String]] = [:]
    var activeContinuationToken: String?
    var extractedNextContinuationToken: String?
}
