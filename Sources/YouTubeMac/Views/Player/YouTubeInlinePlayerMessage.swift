import AppKit
import Foundation
import SwiftUI
@preconcurrency import WebKit

extension YouTubeInlinePlayerView {
        struct PlaybackMessage: Sendable {
            let videoID: String?
            let muted: Bool?
            let captionsEnabled: Bool?
            let playing: Bool?
            let currentTime: Double?
            let duration: Double?
            let frameReady: Bool?
            let pipAvailable: Bool?
            let pipActive: Bool?
            let status: String?

            init?(body: Any) {
                guard let payload = body as? [String: Any] else { return nil }

                videoID = payload["videoID"] as? String
                muted = payload["muted"] as? Bool
                captionsEnabled = payload["captionsEnabled"] as? Bool
                playing = payload["playing"] as? Bool
                currentTime = (payload["currentTime"] as? NSNumber)?.doubleValue
                duration = (payload["duration"] as? NSNumber)?.doubleValue
                frameReady = payload["frameReady"] as? Bool
                pipAvailable = payload["pipAvailable"] as? Bool
                pipActive = payload["pipActive"] as? Bool
                status = payload["status"] as? String

                guard videoID != nil || muted != nil || captionsEnabled != nil || playing != nil || currentTime != nil || duration != nil || frameReady != nil || pipAvailable != nil || pipActive != nil || status != nil else {
                    return nil
                }
            }

            var dictionary: [String: Any] {
                var result: [String: Any] = [:]
                if let videoID { result["videoID"] = videoID }
                if let muted { result["muted"] = muted }
                if let captionsEnabled { result["captionsEnabled"] = captionsEnabled }
                if let playing { result["playing"] = playing }
                if let currentTime { result["currentTime"] = currentTime }
                if let duration { result["duration"] = duration }
                if let frameReady { result["frameReady"] = frameReady }
                if let pipAvailable { result["pipAvailable"] = pipAvailable }
                if let pipActive { result["pipActive"] = pipActive }
                if let status { result["status"] = status }
                return result
            }
        }
}
