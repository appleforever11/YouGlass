import Foundation

struct VideoAmbientPalette: Equatable, Sendable {
    let primary: VideoAmbientColor
    let secondary: VideoAmbientColor
    let accent: VideoAmbientColor
    let energy: Double

    static let neutral = VideoAmbientPalette(
        primary: VideoAmbientColor(red: 0.20, green: 0.55, blue: 1.0),
        secondary: VideoAmbientColor(red: 1.0, green: 0.18, blue: 0.52),
        accent: VideoAmbientColor(red: 0.56, green: 0.25, blue: 1.0),
        energy: 0.42
    )
}

struct VideoItem: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let channel: String
    let views: String
    let age: String
    let duration: String
    let imageURL: URL?
    let verified: Bool
    let channelID: String?

    init(
        id: String,
        title: String,
        channel: String,
        views: String,
        age: String,
        duration: String,
        imageURL: URL?,
        verified: Bool,
        channelID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.channel = channel
        self.views = views
        self.age = age
        self.duration = duration
        self.imageURL = imageURL
        self.verified = verified
        self.channelID = channelID
    }

    var playbackURL: URL {
        if id.count == 11, id.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil {
            return URL(string: "https://www.youtube.com/watch?v=\(id)")!
        }

        let query = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        return URL(string: "https://www.youtube.com/results?search_query=\(query)")!
    }

    var isPlayableOnYouTube: Bool {
        id.count == 11 && id.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
    }

    /// Web homepage cards can arrive before their lazy thumbnail has been
    /// attached. A YouTube-hosted fallback keeps the card useful and, more
    /// importantly, prevents an empty async-image phase from becoming the
    /// visual state of an otherwise playable video.
    var thumbnailURL: URL? {
        if let imageURL {
            return imageURL
        }
        guard isPlayableOnYouTube else {
            return nil
        }
        return URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")
    }

    /// The title-based fallback is needed for Data API responses, which do not
    /// expose whether a video was presented as a YouTube Short.
    var isShortForm: Bool {
        YouGlassContentPolicy.isShortsText(title)
    }

    var embedURL: URL? {
        guard isPlayableOnYouTube else {
            return nil
        }
        return URL(string: "https://www.youtube.com/embed/\(id)?autoplay=1&playsinline=1&rel=0&modestbranding=1&enablejsapi=1&origin=https%3A%2F%2Fwww.youtube.com&mute=1")
    }
}
