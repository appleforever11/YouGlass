import AppKit
import Foundation
import SwiftUI

extension YouTubeStore {
        func loadComments(for video: VideoItem) async -> [VideoComment] {
            await loadCommentPage(for: video).comments
        }

        func loadCommentPage(for video: VideoItem, pageToken: String? = nil) async -> CommentPage {
            guard video.isPlayableOnYouTube else {
                return CommentPage(comments: [], totalCount: 0, isAvailable: false, message: "This item is not a live YouTube video.")
            }

            if let pageToken, pageToken.hasPrefix("bridge-offset:") {
                let offset = Int(pageToken.dropFirst("bridge-offset:".count)) ?? 0
                return await commentsBridge.load(videoID: video.id, maxResults: 50, offset: offset)
            }

            if let pageToken, !pageToken.isEmpty {
                do {
                    return try await client.commentsPage(videoID: video.id, pageToken: pageToken)
                } catch {
                    // A Data API page token is opaque and cannot be translated
                    // into a web-session offset. Falling back to offset zero here
                    // duplicates the first page and makes the list look truncated.
                    YouGlassDiagnostics.record(
                        .warning,
                        category: "comments",
                        message: "Comment page request failed",
                        metadata: ["videoID": video.id, "error": error.localizedDescription]
                    )
                    return CommentPage(
                        comments: [],
                        totalCount: 0,
                        isAvailable: false,
                        message: error.localizedDescription,
                        nextPageToken: pageToken
                    )
                }
            }

            do {
                let page = try await client.commentsPage(videoID: video.id, pageToken: nil)
                if page.isAvailable || page.message?.localizedCaseInsensitiveContains("disabled") == true {
                    return page
                }
                let bridgePage = await commentsBridge.load(videoID: video.id, maxResults: 50, offset: 0)
                return bridgePage.isAvailable ? bridgePage : page
            } catch {
                YouGlassDiagnostics.record(
                    .warning,
                    category: "comments",
                    message: "Comment request failed and web fallback was unavailable",
                    metadata: ["videoID": video.id, "error": error.localizedDescription]
                )
                let bridgePage = await commentsBridge.load(videoID: video.id, maxResults: 50, offset: 0)
                if bridgePage.isAvailable || bridgePage.message?.localizedCaseInsensitiveContains("disabled") == true {
                    return bridgePage
                }
                return CommentPage(
                    comments: [],
                    totalCount: 0,
                    isAvailable: false,
                    message: "\(error.localizedDescription) Add API access in Settings to load public comments safely."
                )
            }
        }

        func loadVideoDetails(for video: VideoItem) async -> VideoDetails? {
            guard video.isPlayableOnYouTube else { return nil }
            do {
                return try await client.videoDetails(videoID: video.id)
            } catch {
                connectionMessage = error.localizedDescription
                return nil
            }
        }

        func loadLiveChat(for video: VideoItem, liveChatID: String? = nil, pageToken: String? = nil) async -> LiveChatPage {
            var resolvedLiveChatID = liveChatID
            if resolvedLiveChatID?.isEmpty != false,
               let details = try? await client.videoDetails(videoID: video.id) {
                resolvedLiveChatID = details.liveChatID
            }

            if let resolvedLiveChatID, !resolvedLiveChatID.isEmpty {
                do {
                    return try await client.liveChatPage(liveChatID: resolvedLiveChatID, pageToken: pageToken)
                } catch {
                    YouGlassDiagnostics.record(
                        .warning,
                        category: "live-chat",
                        message: "OAuth/API live chat request failed",
                        metadata: ["videoID": video.id, "error": error.localizedDescription]
                    )
                }
            }

            let bridgePage = await liveChatBridge.load(videoID: video.id)
            if bridgePage.isAvailable || bridgePage.isLive {
                return bridgePage
            }
            return LiveChatPage(
                messages: [],
                nextPageToken: pageToken,
                pollingInterval: 6_000_000_000,
                isLive: true,
                isAvailable: false,
                message: bridgePage.message ?? "YouTube did not expose a live-chat ID for this stream."
            )
        }

        func sendLiveChatMessage(for video: VideoItem, liveChatID: String?, text: String) async -> LiveChatMessage? {
            guard let liveChatID, !liveChatID.isEmpty else {
                connectionMessage = "YouTube did not expose a writable live-chat ID for this stream."
                return nil
            }

            do {
                let message = try await client.sendLiveChatMessage(liveChatID: liveChatID, text: text)
                YouGlassDiagnostics.record(
                    .info,
                    category: "live-chat",
                    message: "Live chat message sent",
                    metadata: ["videoID": video.id]
                )
                return message
            } catch {
                connectionMessage = error.localizedDescription
                YouGlassDiagnostics.record(
                    .warning,
                    category: "live-chat",
                    message: "Live chat message failed",
                    metadata: ["videoID": video.id, "error": error.localizedDescription]
                )
                return nil
            }
        }

        func rate(video: VideoItem, as rating: String) async -> Bool {
            do {
                try await client.rate(videoID: video.id, rating: rating)
                return true
            } catch {
                connectionMessage = error.localizedDescription
                return false
            }
        }

        func subscribe(
            to channelID: String,
            channelName: String? = nil,
            avatarURL: URL? = nil,
            channelURL: URL? = nil
        ) async -> Bool {
            do {
                try await client.subscribe(to: channelID)
                if let channelName, !channelName.isEmpty {
                    let resolvedChannelURL = channelURL
                        ?? (channelID.hasPrefix("UC")
                            ? URL(string: "https://www.youtube.com/channel/\(channelID)")
                            : nil)
                    let item = SubscriptionItem(
                        id: channelID,
                        name: channelName,
                        avatarURL: avatarURL,
                        channelURL: resolvedChannelURL,
                        isLive: false
                    )
                    subscriptions = mergeSubscriptions([item] + subscriptions)
                    subscriptionsLoaded = true
                    persistSubscriptions(subscriptions)
                }
                return true
            } catch {
                connectionMessage = error.localizedDescription
                return false
            }
        }

        func addComment(to video: VideoItem, channelID: String?, text: String) async -> VideoComment? {
            guard let channelID, !channelID.isEmpty else {
                commentAuthorizationRequired = false
                connectionMessage = "Connect a YouTube Data API key or Google OAuth in YouGlass Settings before posting comments."
                return nil
            }

            do {
                let comment = try await client.addComment(videoID: video.id, channelID: channelID, text: text)
                commentAuthorizationRequired = false
                connectionMessage = "Comment posted to YouTube"
                return comment
            } catch {
                commentAuthorizationRequired = isAuthenticationError(error)
                connectionMessage = error.localizedDescription
                return nil
            }
        }

        func authorizeYouTubeComments() async -> Bool {
            guard oauth.hasClientID else {
                commentAuthorizationRequired = true
                connectionMessage = "Add the Google OAuth client ID before authorizing comments."
                return false
            }
            guard oauth.hasClientSecret else {
                commentAuthorizationRequired = true
                connectionMessage = "Add the Google OAuth client secret before authorizing comments."
                return false
            }

            do {
                if try await oauth.validAccessToken() == nil {
                    _ = try await oauth.signIn()
                }
                isSignedIn = true
                defaults.set(true, forKey: DefaultsKey.isSignedIn)
                commentAuthorizationRequired = false
                connectionMessage = "Connected with YouTube OAuth"
                scheduleSubscriptionsLoad(force: true)
                scheduleHomeReload(force: true)
                return true
            } catch {
                connectionMessage = error.localizedDescription
                return false
            }
        }
}
