import SwiftUI

struct NativeWatchScreen: View {
    @EnvironmentObject var store: YouTubeStore
    @State var commentPage = CommentPage(comments: [], totalCount: 0, isAvailable: false, message: nil)
    @State var commentsLoading = true
    @State var recommendations: [VideoItem] = []
    @State var details: VideoDetails?
    @State var chatMessages: [LiveChatMessage] = []
    @State var liveChatPage = LiveChatPage.unavailable
    @State var liked = false
    @State var disliked = false
    @State var saved = false
    @State var subscribed = false
    @State var subscriptionStatusResolved = false
    @State var actionBusy = false
    @State var commentsLoadingMore = false
    @State var commentLoadRetryToken: String?
    @State var commentText = ""
    @State var commentStatus: String?
    @State var commentSubmitting = false
    @State var authorizingComments = false
    @State var commentAuthorizationRequired = false
    @State var commentChannelID: String?
    @State var playbackStopHandlerToken: UUID?
    @State var playbackCommandHandlerToken: UUID?
    @State var queuePresented = false
    @State var didAutoAdvance = false
    @StateObject var playbackController = YouTubePlaybackController()
    @FocusState var commentFieldFocused: Bool
    let video: VideoItem
    let palette: Palette
    let isCompact: Bool
    let onCompactDragChanged: ((CGSize) -> Void)?
    let onCompactDragEnded: ((CGSize) -> Void)?
    let onPlayerHoverChanged: ((Bool) -> Void)?
}

extension NativeWatchScreen {
    func syncNativeNowPlaying() {
        store.syncNowPlaying(
            video: video,
            currentTime: playbackController.currentTime,
            duration: playbackController.duration,
            isPlaying: playbackController.isPlaying,
            playbackRate: playbackController.playbackRate
        )
    }
}
