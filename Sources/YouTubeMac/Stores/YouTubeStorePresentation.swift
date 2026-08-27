import AppKit
import Foundation
import SwiftUI

extension YouTubeStore {
        /// Accessibility presses on macOS 26 can still be inside SwiftUI's
        /// AttributeGraph transaction when a button mutates the selected video.
        /// Defer the mutation one main-actor turn so the current view graph can
        /// finish copying its title and geometry values first.
        func openFromUserInteraction(_ video: VideoItem) {
            Task { @MainActor [weak self] in
                await Task.yield()
                self?.open(video)
            }
        }

        func open(_ video: VideoItem) {
            stopCurrentPlayback()
            closeDesktopPIPWindow()
            guard video.isPlayableOnYouTube else {
                connectionMessage = "Resolving this card to a playable YouTube video..."
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    if await client.hasCredentials(),
                       let matches = try? await client.searchVideos(query: video.title, maxResults: 1),
                       let resolved = matches.first {
                        rememberRecommendationSeed(resolved)
                        rememberHistory(resolved)
                        selectedVideo = resolved
                        isPlayerCompact = false
                        connectionMessage = "Playing a YouTube result in the native player"
                        return
                    }

                    // Keep the offline catalog interactive when no API key/feed is
                    // available. This is the official IFrame API sample video.
                    if let fallback = VideoItem.fromYouTubeInput("M7lc1UVf-VE") {
                        selectedVideo = VideoItem(
                            id: fallback.id,
                            title: "YouTube player test video",
                            channel: "YouTube",
                            views: "Official player sample",
                            age: "",
                            duration: "",
                            imageURL: fallback.imageURL,
                            verified: true
                        )
                        isPlayerCompact = false
                        connectionMessage = "Playing the offline YouTube player sample"
                        return
                    }

                    connectionMessage = "This card does not contain a valid YouTube video ID"
                }
                return
            }

            rememberRecommendationSeed(video)
            rememberHistory(video)
            isPlayerCompact = false
            selectedVideo = video
        }

        func openURL(_ url: URL, title: String = "YouTube") {
            YouTubeBrowserWindow.shared.open(url, title: title)
        }

        func openYouTube(_ path: String = "") {
            openURL(URL(string: "https://www.youtube.com\(path)")!)
        }

        func closePlayer() {
            presentDesktopPIP()
        }

        func expandPlayer() {
            guard selectedVideo != nil else { return }
            stopCurrentPlayback()
            closeDesktopPIPWindow()
            isPlayerCompact = false
        }

        func dismissPlayer() {
            stopCurrentPlayback()
            closeDesktopPIPWindow()
            selectedVideo = nil
            isPlayerCompact = false
        }

        /// Called by AppKit when the user closes the floating PIP window directly
        /// with the window chrome or a system close command.
        func desktopPIPDidClose() {
            guard isDesktopPIPActive || isDesktopPIPTransitioning else { return }
            pipTransitionTask?.cancel()
            pipTransitionTask = nil
            isDesktopPIPActive = false
            pipTransitionState = .idle
            stopCurrentPlayback()
            selectedVideo = nil
            isPlayerCompact = false
            connectionMessage = "Picture in Picture closed"
            YouGlassDesktopPIPWindowController.shared.close()
        }

        func presentDesktopPIP() {
            guard let video = selectedVideo else {
                connectionMessage = "Choose a video before opening Picture in Picture"
                return
            }

            guard !isDesktopPIPActive, !isDesktopPIPTransitioning else { return }

            pipTransitionTask?.cancel()
            pipTransitionTask = nil

            // Stop the source player and remove it from the SwiftUI tree before
            // creating the floating player. WebKit can crash while committing a
            // remote layer tree if the source and PIP WebViews are mounted or
            // detached in the same transaction.
            stopCurrentPlayback()
            isPlayerCompact = false
            pipTransitionState = .presenting(videoID: video.id)
            isDesktopPIPActive = true
            connectionMessage = "Opening Picture in Picture..."
            playbackLogger.notice("Starting PIP handoff for video=\(video.id, privacy: .public)")

            pipTransitionTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: PIPTransitionPolicy.sourceTeardownDelayNanoseconds)
                guard !Task.isCancelled, let self,
                      self.pipTransitionState.matches(videoID: video.id),
                      self.pipTransitionState.isTransitioning,
                      self.selectedVideo?.id == video.id else { return }

                let presented = YouGlassDesktopPIPWindowController.shared.present(video: video, store: self)
                guard presented else {
                    self.isDesktopPIPActive = false
                    self.pipTransitionState = .idle
                    self.pipTransitionTask = nil
                    self.connectionMessage = "Picture in Picture could not be presented"
                    self.playbackLogger.error("PIP handoff failed to present for video=\(video.id, privacy: .public)")
                    return
                }

                self.pipTransitionState = .active(videoID: video.id)
                self.pipTransitionTask = nil
                self.connectionMessage = "Picture in Picture active"
                self.playbackLogger.notice("Completed PIP handoff for video=\(video.id, privacy: .public)")
            }
        }

        func closeDesktopPIPWindow() {
            guard isDesktopPIPActive || isDesktopPIPTransitioning else { return }
            pipTransitionTask?.cancel()
            pipTransitionTask = nil
            isDesktopPIPActive = false
            pipTransitionState = .idle
            YouGlassDesktopPIPWindowController.shared.close()
        }

        func stopCurrentPlayback() {
            let handler = playbackStopHandler
            playbackStopHandler = nil
            playbackStopHandlerToken = nil
            playbackCommandHandler = nil
            playbackCommandHandlerToken = nil
            handler?()
        }

        func openChannel(_ item: SubscriptionItem) {
            if selectedVideo != nil {
                isPlayerCompact = true
            }
            selectedChannelItem = item
            channelPage = nil
            channelError = nil
            channelLoading = true

            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let page = try await client.channelPage(for: item)
                    guard selectedChannelItem?.id == item.id else { return }
                    channelPage = page
                    selectedSection = page.channel.name
                } catch {
                    guard selectedChannelItem?.id == item.id else { return }
                    if let page = await safariHomeFeed.loadChannelPage(for: item) {
                        channelPage = page
                        selectedSection = page.channel.name
                        connectionMessage = "Native channel view from your YouTube subscription feed"
                        YouGlassDiagnostics.record(
                            .info,
                            category: "channel",
                            message: "Loaded native channel subscription feed",
                            metadata: ["channel": item.name]
                        )
                    } else if let page = await channelBridge.loadChannel(item) {
                        channelPage = page
                        selectedSection = page.channel.name
                        connectionMessage = "Native channel view from your signed-in YouTube session"
                    } else {
                        channelError = error.localizedDescription
                    }
                }
                channelLoading = false
            }
        }

        func closeChannel() {
            selectedChannelItem = nil
            channelPage = nil
            channelError = nil
            channelLoading = false
            selectedSection = "Home"
        }
}
