import AppKit
import Foundation
import SwiftUI
@preconcurrency import WebKit

extension YouTubeInlinePlayerView {
        func makeCoordinator() -> Coordinator {
            Coordinator(controller: controller)
        }

        func makeNSView(context: Context) -> YouTubeInlinePlayerHostView {
            let configuration = WKWebViewConfiguration()
            configuration.youGlassDisableWebMaterialsOnAffectedSystems()
            configuration.websiteDataStore = .default()
            configuration.allowsAirPlayForMediaPlayback = true
            configuration.mediaTypesRequiringUserActionForPlayback = []
            configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
            configuration.userContentController.addUserScript(
                WKUserScript(
                    source: Self.initialSurfaceScript,
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: true
                )
            )
            var playerScript = Self.playerChromeScript.replacingOccurrences(
                of: "__YOUGLASS_AUTO_MUTE__",
                with: autoMuteOnStart ? "true" : "false"
            )
            playerScript = playerScript.replacingOccurrences(
                of: "__YOUGLASS_VIDEO_ID__",
                with: video.id
            )
            configuration.userContentController.addUserScript(
                WKUserScript(
                    source: playerScript,
                    injectionTime: .atDocumentEnd,
                    forMainFrameOnly: true
                )
            )
            // WebKit invokes WKScriptMessageHandler through Objective-C. Keep the
            // forwarding object scoped to this WebKit configuration.
            configuration.userContentController.add(
                ScriptMessageHandlerProxy(coordinator: context.coordinator),
                name: "youglassPlayback"
            )

            let webView = YouGlassPlaybackWebView(frame: .zero, configuration: configuration)
            webView.navigationDelegate = context.coordinator
            webView.uiDelegate = context.coordinator
            webView.wantsLayer = true
            webView.layer?.backgroundColor = NSColor.black.cgColor
            webView.underPageBackgroundColor = .black
            controller.attach(to: webView, video: video)
            context.coordinator.autoMuteOnStart = autoMuteOnStart
            context.coordinator.load(video: video, in: webView)
            return YouTubeInlinePlayerHostView(webView: webView)
        }

        func updateNSView(_ hostView: YouTubeInlinePlayerHostView, context: Context) {
            let webView = hostView.webView
            controller.prepareAmbientPalette(for: video)
            let audioPreferenceChanged = context.coordinator.autoMuteOnStart != autoMuteOnStart
            context.coordinator.autoMuteOnStart = autoMuteOnStart
            if audioPreferenceChanged {
                context.coordinator.applyAudioPolicy(in: webView)
            }
            context.coordinator.load(video: video, in: webView)
        }

        static func dismantleNSView(_ hostView: YouTubeInlinePlayerHostView, coordinator: Coordinator) {
            let webView = hostView.webView
            coordinator.controller.stopAndDetachDeferred(from: webView)
        }
}
