import Foundation

struct SafariHomeFeedClient: Sendable {
    struct Channel: Sendable {
        let name: String
        let source: URL
        let category: String
        let channelID: String?

        init(name: String, source: URL, category: String, channelID: String? = nil) {
            self.name = name
            self.source = source
            self.category = category
            self.channelID = channelID
        }
    }

    private struct FetchedVideo: Sendable {
        let video: VideoItem
        let publishedAt: Date
    }

    private let session: URLSession

    static let defaultChannels: [Channel] = [
        Channel(name: "Jail", source: URL(string: "https://www.youtube.com/@JailTVShow")!, category: "True Crime"),
        Channel(name: "Rotten Mango", source: URL(string: "https://www.youtube.com/@rottenmangopod")!, category: "True Crime"),
        Channel(name: "Crime Weekly", source: URL(string: "https://www.youtube.com/@CrimeWeeklyPodcast")!, category: "True Crime"),
        Channel(name: "Call Her Daddy", source: URL(string: "https://www.youtube.com/@callherdaddy")!, category: "Podcasts"),
        Channel(name: "Peach PRC", source: URL(string: "https://www.youtube.com/@PeachPRC")!, category: "Music"),
        Channel(name: "MELLY", source: URL(string: "https://www.youtube.com/@ThatOneGirlMELLY")!, category: "Music"),
        Channel(name: "AG Tactical", source: URL(string: "https://www.youtube.com/@AGTactical")!, category: "Commentary"),
        Channel(name: "Ryans REAL Reactions", source: URL(string: "https://www.youtube.com/@RyansRealReactions")!, category: "Commentary")
    ]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func loadFeed(maxResultsPerChannel: Int = 5) async -> [VideoItem] {
        await loadFeed(channels: Self.defaultChannels, maxResultsPerChannel: maxResultsPerChannel)
    }

    func loadFeed(channels: [Channel], maxResultsPerChannel: Int = 5) async -> [VideoItem] {
        let limit = max(1, min(maxResultsPerChannel, 12))
        guard !channels.isEmpty else { return [] }

        return await withTaskGroup(of: [FetchedVideo].self, returning: [VideoItem].self) { group in
            for channel in channels {
                group.addTask {
                    await fetch(channel: channel, limit: limit)
                }
            }

            var fetched: [FetchedVideo] = []
            for await batch in group {
                fetched.append(contentsOf: batch)
            }

            var seen = Set<String>()
            return fetched
                .sorted { $0.publishedAt > $1.publishedAt }
                .compactMap { entry in
                    guard seen.insert(entry.video.id).inserted else { return nil }
                    return entry.video
                }
        }
    }

    private func fetch(channel: Channel, limit: Int) async -> [FetchedVideo] {
        do {
            let resolvedChannelID: String
            if let channelID = channel.channelID, !channelID.isEmpty {
                resolvedChannelID = channelID
            } else {
                let page = try await get(channel.source)
                guard let channelID = Self.channelID(in: page) else { return [] }
                resolvedChannelID = channelID
            }

            let feedURL = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(resolvedChannelID)")!
            let xml = try await get(feedURL)
            let parser = AtomFeedParser(data: xml)
            guard parser.parse() else { return [] }

            return parser.entries.prefix(limit).compactMap { entry in
                guard let videoID = entry.videoID, !videoID.isEmpty,
                      let publishedAt = Self.date(from: entry.published) else {
                    return nil
                }

                let title = entry.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !title.isEmpty else { return nil }

                let video = VideoItem(
                    id: videoID,
                    title: title,
                    channel: entry.channelTitle?.isEmpty == false ? entry.channelTitle! : channel.name,
                    views: "Fresh upload",
                    age: Self.relativeDate(publishedAt),
                    duration: "",
                    imageURL: URL(string: entry.thumbnail ?? "https://i.ytimg.com/vi/\(videoID)/hqdefault.jpg"),
                    verified: false,
                    channelID: resolvedChannelID
                )
                return FetchedVideo(video: video, publishedAt: publishedAt)
            }
        } catch {
            return []
        }
    }

    private func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 9
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 Safari/605.1.15 YouGlass/0.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private static func channelID(in data: Data) -> String? {
        guard let html = String(data: data, encoding: .utf8) else { return nil }
        return channelID(in: html)
    }

    private static func channelID(in html: String) -> String? {
        let patterns = [
            #""channelId":"(UC[A-Za-z0-9_-]{22})""#,
            #""externalId":"(UC[A-Za-z0-9_-]{22})""#,
            #"<meta\s+itemprop="channelId"\s+content="(UC[A-Za-z0-9_-]{22})""#
        ]
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            guard let match = expression.firstMatch(in: html, range: range), match.numberOfRanges > 1,
                  let capture = Range(match.range(at: 1), in: html) else { continue }
            return String(html[capture])
        }
        return nil
    }

    private static func date(from string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        return ISO8601DateFormatter().date(from: string)
    }

    private static func relativeDate(_ date: Date) -> String {
        let seconds = max(1, Date().timeIntervalSince(date))
        if seconds < 3600 { return "\(max(1, Int(seconds / 60)))m ago" }
        if seconds < 86400 { return "\(max(1, Int(seconds / 3600)))h ago" }
        if seconds < 604800 { return "\(max(1, Int(seconds / 86400)))d ago" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

private final class AtomFeedParser: NSObject, XMLParserDelegate {
    struct Entry {
        var videoID: String?
        var title: String?
        var published: String?
        var channelTitle: String?
        var thumbnail: String?
    }

    private let data: Data
    private var currentEntry: Entry?
    private var currentElement = ""
    private var text = ""
    private(set) var entries: [Entry] = []

    init(data: Data) {
        self.data = data
    }

    func parse() -> Bool {
        let parser = XMLParser(data: data)
        parser.delegate = self
        return parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "entry" {
            currentEntry = Entry()
        }

        if elementName == "link", currentEntry != nil, attributeDict["rel"] == "alternate" {
            currentElement = "alternate-link"
        } else if elementName.hasSuffix(":thumbnail") || elementName == "thumbnail" {
            if currentEntry != nil, let url = attributeDict["url"] {
                currentEntry?.thumbnail = url
            }
            currentElement = ""
        } else {
            currentElement = elementName
        }
        text = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text.append(string)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if elementName == "entry" {
            if let currentEntry { entries.append(currentEntry) }
            currentEntry = nil
        } else if elementName == "videoId" || elementName.hasSuffix(":videoId") {
            currentEntry?.videoID = value
        } else if elementName == "title" {
            currentEntry?.title = value
            if currentEntry == nil { currentElement = "channel-title" }
        } else if elementName == "published" {
            currentEntry?.published = value
        } else if elementName == "name" {
            currentEntry?.channelTitle = value
        }
        text = ""
        currentElement = ""
    }
}
