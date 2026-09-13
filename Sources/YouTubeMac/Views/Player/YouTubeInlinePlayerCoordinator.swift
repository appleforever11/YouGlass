import AppKit
import Foundation
import SwiftUI
@preconcurrency import WebKit

extension YouTubeInlinePlayerView {
        final class ScriptMessageHandlerProxy: NSObject, WKScriptMessageHandler {
            // WKScriptMessageHandler is entered through an Objective-C thunk. On
            // macOS 27 beta, applying the enclosing SwiftUI type's inferred main
            // actor isolation to that thunk can pass an invalid executor reference
            // into Swift's precondition before this method even begins. Keep only
            // this bridge nonisolated; the parsed Sendable value is handed back to
            // the main actor below.
            nonisolated(unsafe) weak var coordinator: Coordinator?

            init(coordinator: Coordinator) {
                self.coordinator = coordinator
            }

            nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
                let coordinator = self.coordinator
                Task { @MainActor in
                    guard message.name == "youglassPlayback",
                          let source = message.webView,
                          coordinator?.controller.isAttached(to: source) == true,
                          let payload = PlaybackMessage(body: message.body) else { return }
                    coordinator?.handlePlaybackMessage(payload)
                }
            }
        }

        final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
            let controller: YouTubePlaybackController
            var autoMuteOnStart = false
            private var loadedVideoID: String?

            init(controller: YouTubePlaybackController) {
                self.controller = controller
            }

            @MainActor
            fileprivate func handlePlaybackMessage(_ payload: PlaybackMessage) {
                controller.update(from: payload.dictionary)
            }

            func load(video: VideoItem, in webView: WKWebView) {
                guard video.isPlayableOnYouTube, loadedVideoID != video.id else { return }
                // Use YouTube's first-party watch surface. Direct /embed URLs are
                // rejected for a subset of videos with YouTube error 152-4 even
                // when the same signed-in account can play the video on youtube.com.
                // The injected chrome script hides the page UI while preserving
                // YouTube's account, age, live, and playback eligibility checks.
                var components = URLComponents(url: video.playbackURL, resolvingAgainstBaseURL: false)
                var queryItems = components?.queryItems ?? []
                if !queryItems.contains(where: { $0.name == "autoplay" }) {
                    queryItems.append(URLQueryItem(name: "autoplay", value: "1"))
                }
                queryItems.removeAll { $0.name == "mute" }
                if autoMuteOnStart {
                    queryItems.append(URLQueryItem(name: "mute", value: "1"))
                }
                if !queryItems.contains(where: { $0.name == "playsinline" }) {
                    queryItems.append(URLQueryItem(name: "playsinline", value: "1"))
                }
                if !queryItems.contains(where: { $0.name == "app" }) {
                    queryItems.append(URLQueryItem(name: "app", value: "desktop"))
                }
                if !queryItems.contains(where: { $0.name == "hl" }) {
                    queryItems.append(URLQueryItem(name: "hl", value: "en"))
                }
                components?.queryItems = queryItems
                guard let url = components?.url else { return }
                loadedVideoID = video.id

                webView.load(URLRequest(
                    url: url,
                    // Reuse WebKit's normal page and connection cache so the next
                    // first click can reach YouTube's media element sooner. The
                    // watch surface still performs its own account/session checks.
                    cachePolicy: .useProtocolCachePolicy,
                    timeoutInterval: 30
                ))
            }

            func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
                // YouTube is a client-rendered application. Reapply the player
                // surface and muted-start logic after its initial navigation too.
                let playerScript = YouTubeInlinePlayerView.playerChromeScript.replacingOccurrences(
                    of: "__YOUGLASS_AUTO_MUTE__",
                    with: autoMuteOnStart ? "true" : "false"
                )
                .replacingOccurrences(
                    of: "__YOUGLASS_VIDEO_ID__",
                    with: loadedVideoID ?? ""
                )
                Task { @MainActor [weak controller, weak webView] in
                    guard let controller, let webView,
                          controller.isAttached(to: webView) else { return }
                    _ = try? await webView.evaluateJavaScript(playerScript)
                    controller.didFinishNavigation(for: webView)
                }
            }

            func applyAudioPolicy(in webView: WKWebView) {
                webView.evaluateJavaScript(
                    "window.__youglassControls?.applyAudioPolicy(\(autoMuteOnStart ? "true" : "false"))",
                    completionHandler: nil
                )
            }

            func webView(
                _ webView: WKWebView,
                decidePolicyFor navigationAction: WKNavigationAction,
                decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
            ) {
                // Keep navigation in the existing player surface; never create a browser window.
                if navigationAction.targetFrame == nil {
                    decisionHandler(.cancel)
                } else {
                    decisionHandler(.allow)
                }
            }

            func webView(
                _ webView: WKWebView,
                createWebViewWith configuration: WKWebViewConfiguration,
                for navigationAction: WKNavigationAction,
                windowFeatures: WKWindowFeatures
            ) -> WKWebView? {
                nil
            }

            func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
                Task { @MainActor [weak controller, weak webView] in
                    guard let controller, let webView else { return }
                    controller.handleNavigationFailure(error, for: webView)
                }
            }

            func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
                Task { @MainActor [weak controller, weak webView] in
                    guard let controller, let webView else { return }
                    controller.handleNavigationFailure(error, for: webView)
                }
            }

            func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
                let error = NSError(
                    domain: "YouGlassPlayback",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "The YouTube player process stopped."]
                )
                Task { @MainActor [weak controller, weak webView] in
                    guard let controller, let webView else { return }
                    controller.handleNavigationFailure(error, for: webView)
                }
                // Do not automatically reload a terminated WebKit process. A
                // reload can overlap a SwiftUI/AppKit detach or PIP handoff and
                // trigger another remote layer-tree commit. The native retry UI
                // now gives the user an explicit, isolated recovery action.
            }
        }
}
