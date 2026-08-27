import SwiftUI
@preconcurrency import WebKit

struct YouTubeInlinePlayerView: NSViewRepresentable {
    let video: VideoItem
    let controller: YouTubePlaybackController
    let autoMuteOnStart: Bool
}
