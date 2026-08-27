import SwiftUI

struct NativeYouTubePlayer: View {
    @EnvironmentObject var store: YouTubeStore
    let video: VideoItem
    let palette: Palette
    @ObservedObject var playbackController: YouTubePlaybackController
    let autoMuteOnStart: Bool
    let isCompact: Bool
    let onCompactDragChanged: ((CGSize) -> Void)?
    let onCompactDragEnded: ((CGSize) -> Void)?
    let onPlayerHoverChanged: ((Bool) -> Void)?
    @State var controlsVisible = false
    @State var isPointerHovering = false
    @State var controlsHideTask: Task<Void, Never>?
    @State var scrubPosition = 0.0
    @State var isScrubbing = false
}
