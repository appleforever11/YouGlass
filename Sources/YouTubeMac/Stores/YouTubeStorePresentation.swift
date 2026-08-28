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
            videoResolutionTask?.cancel()
            videoResolutionTask = nil
            videoResolutionGeneration &+= 1

            stopCurrentPlayback()
            closeDesktopPIPWindow()
            guard video.isPlayableOnYouTube else {
                connectionMessage = "Resolving this card to a playable YouTube video..."
                let generation = videoResolutionGeneration
                videoResolutionTask = Task { @MainActor [weak self] in
                    guard let self else { return }
                    defer {
                        if self.videoResolutionGeneration == generation {
                            self.videoResolutionTask = nil
                        }
                    }

                    if await client.hasCredentials(),
                       let matches = try? await client.searchVideos(query: video.title, maxResults: 1),
                       let resolved = matches.first {
                        guard !Task.isCancelled, self.videoResolutionGeneration == generation else { return }
                        rememberRecommendationSeed(resolved)
                        rememberHistory(resolved)
                        preparePlaybackQueue(for: resolved)
                        selectedVideo = resolved
                        isPlayerCompact = false
                        syncNowPlaying(video: resolved)
                        connectionMessage = "Playing a YouTube result in the native player"
                        return
                    }

                    // Keep the offline catalog interactive when no API key/feed is
                    // available. This is the official IFrame API sample video.
                    if let fallback = VideoItem.fromYouTubeInput("M7lc1UVf-VE") {
                        guard !Task.isCancelled, self.videoResolutionGeneration == generation else { return }
                        let playableFallback = VideoItem(
                            id: fallback.id,
                            title: "YouTube player test video",
                            channel: "YouTube",
                            views: "Official player sample",
                            age: "",
                            duration: "",
                            imageURL: fallback.imageURL,
                            verified: true
                        )
                        preparePlaybackQueue(for: playableFallback)
                        isPlayerCompact = false
                        selectedVideo = playableFallback
                        syncNowPlaying(video: playableFallback)
                        connectionMessage = "Playing the offline YouTube player sample"
                        return
                    }

                    guard !Task.isCancelled, self.videoResolutionGeneration == generation else { return }
                    connectionMessage = "This card does not contain a valid YouTube video ID"
                }
                return
            }

            rememberRecommendationSeed(video)
            rememberHistory(video)
            preparePlaybackQueue(for: video)
            isPlayerCompact = false
            selectedVideo = video
            syncNowPlaying(video: video)
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
            videoResolutionTask?.cancel()
            videoResolutionTask = nil
            videoResolutionGeneration &+= 1
            stopCurrentPlayback()
            closeDesktopPIPWindow()
            selectedVideo = nil
            isPlayerCompact = false
            syncNowPlaying(video: nil)
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
            syncNowPlaying(video: nil)
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
            channelLoadTask?.cancel()
            channelLoadGeneration &+= 1
            let generation = channelLoadGeneration

            if selectedVideo != nil {
                isPlayerCompact = true
            }
            selectedChannelItem = item
            channelPage = nil
            channelError = nil
            channelLoading = true

            channelLoadTask = Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let page = try await client.channelPage(for: item)
                    guard canPublishChannelLoad(generation, channelID: item.id) else { return }
                    channelPage = page
                    selectedSection = page.channel.name
                } catch {
                    guard canPublishChannelLoad(generation, channelID: item.id) else { return }
                    if let page = await safariHomeFeed.loadChannelPage(for: item) {
                        guard canPublishChannelLoad(generation, channelID: item.id) else { return }
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
                        guard canPublishChannelLoad(generation, channelID: item.id) else { return }
                        channelPage = page
                        selectedSection = page.channel.name
                        connectionMessage = "Native channel view from your signed-in YouTube session"
                    } else {
                        channelError = error.localizedDescription
                    }
                }
                finishChannelLoad(generation)
            }
        }

        private func canPublishChannelLoad(_ generation: Int, channelID: String) -> Bool {
            !Task.isCancelled &&
                generation == channelLoadGeneration &&
                selectedChannelItem?.id == channelID
        }

        private func finishChannelLoad(_ generation: Int) {
            guard generation == channelLoadGeneration else { return }
            channelLoading = false
            channelLoadTask = nil
        }

        func closeChannel() {
            channelLoadTask?.cancel()
            channelLoadTask = nil
            channelLoadGeneration &+= 1
            selectedChannelItem = nil
            channelPage = nil
            channelError = nil
            channelLoading = false
            selectedSection = "Home"
        }
}
