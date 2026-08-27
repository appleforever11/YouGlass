import Foundation

struct YouGlassPlaybackQueueState: Codable, Equatable {
    var videos: [VideoItem]
    var autoplay = true
}
