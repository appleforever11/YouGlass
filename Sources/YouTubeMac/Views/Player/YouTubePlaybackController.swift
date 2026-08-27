import AppKit
import Foundation
import OSLog
import SwiftUI
@preconcurrency import WebKit

@MainActor
final class YouTubePlaybackController: ObservableObject {
    @Published var isMuted = false
    @Published var isCaptionsEnabled = false
    @Published var isPlaying = false
    @Published var didFinish = false
    @Published var isPictureInPictureAvailable = false
    @Published var isPictureInPictureActive = false
    @Published var isSurfaceReady = false
    @Published var status = "Loading player..."
    @Published var canRetry = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var playbackRate = 1.0
    @Published var ambientPalette = VideoAmbientPalette.neutral

    weak var webView: WKWebView?
    var visualPaletteTask: Task<Void, Never>?
    var activeVideoID: String?
    var pendingResumeVideoID: String?
    var pendingResumePosition: Double?
    var pictureInPictureFallback: (() -> Void)?
    var pictureInPictureFallbackTask: Task<Void, Never>?
    var loadWatchdogTask: Task<Void, Never>?
    var playbackBootstrapTask: Task<Void, Never>?
    var loadGeneration = 0
    let logger = Logger(subsystem: "com.kevinhowe.YouGlass", category: "playback")
}
