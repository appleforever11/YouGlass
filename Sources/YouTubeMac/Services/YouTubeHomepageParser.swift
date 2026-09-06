import Foundation

enum YouTubeHomepageParser {
    static func parse(_ html: String, limit: Int) -> YouTubeWebFeedResult {
        guard let data = initialData(in: html),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return .empty }
        let responseContext = root["responseContext"] as? [String: Any]
        let webContext = responseContext?["mainAppWebResponseContext"] as? [String: Any]
        let signedIn = (webContext?["loggedOut"] as? Bool) == false
            || html.range(of: #""LOGGED_IN"\s*:\s*true"#, options: .regularExpression) != nil
        let contents = root["contents"] as? [String: Any] ?? [:]
        let browse = contents["twoColumnBrowseResultsRenderer"] as? [String: Any]
        let tabs = browse?["tabs"] as? [[String: Any]] ?? []
        let selected = tabs.compactMap { $0["tabRenderer"] as? [String: Any] }
            .first { ($0["selected"] as? Bool) == true }
        var videos: [VideoItem] = []
        var seen = Set<String>()
        let bound = min(80, max(1, limit))

        func visit(_ value: Any, depth: Int = 0) {
            guard depth < 24, videos.count < bound else { return }
            if let array = value as? [Any] {
                for entry in array { visit(entry, depth: depth + 1) }
                return
            }
            guard let node = value as? [String: Any] else { return }
            if let renderer = node["videoRenderer"] as? [String: Any] ?? node["gridVideoRenderer"] as? [String: Any] {
                if let video = video(renderer), YouGlassContentPolicy.allows(video), seen.insert(video.id).inserted {
                    videos.append(video)
                }
                return
            }
            if let renderer = node["lockupViewModel"] as? [String: Any] {
                if let video = lockupVideo(renderer), YouGlassContentPolicy.allows(video), seen.insert(video.id).inserted {
                    videos.append(video)
                }
                return
            }
            // Traverse only feed containers, preserving array order. Ads,
            // Shorts shelves, sidebar links and unrelated endpoint data never
            // become candidates, even if they contain video IDs.
            for key in ["richGridRenderer", "richItemRenderer", "richSectionRenderer", "richShelfRenderer",
                        "sectionListRenderer", "itemSectionRenderer", "gridRenderer", "gridVideoRenderer",
                        "contents", "content", "items"] {
                if let child = node[key] { visit(child, depth: depth + 1) }
            }
        }
        visit(selected?["content"] ?? contents)
        return YouTubeWebFeedResult(videos: videos, isSignedIn: signedIn,
                                    diagnostics: "YouTube homepage order: \(videos.count) videos")
    }

    static func initialData(in html: String) -> Data? {
        for marker in ["var ytInitialData =", "window[\"ytInitialData\"] =", "ytInitialData ="] {
            guard let markerRange = html.range(of: marker),
                  let start = html[markerRange.upperBound...].firstIndex(of: "{") else { continue }
            var depth = 0
            var inString = false
            var escaped = false
            for index in html[start...].indices {
                let char = html[index]
                if inString {
                    if escaped { escaped = false }
                    else if char == "\\" { escaped = true }
                    else if char == "\"" { inString = false }
                } else if char == "\"" { inString = true }
                else if char == "{" { depth += 1 }
                else if char == "}" {
                    depth -= 1
                    if depth == 0 { return String(html[start...index]).data(using: .utf8) }
                }
            }
        }
        return nil
    }

    private static func text(_ value: Any?) -> String {
        if let string = value as? String { return string }
        let node = value as? [String: Any] ?? [:]
        if let value = node["simpleText"] as? String ?? node["content"] as? String { return value }
        return (node["runs"] as? [[String: Any]] ?? []).compactMap { $0["text"] as? String }.joined()
    }

    private static func imageURL(_ node: Any?) -> URL? {
        let node = node as? [String: Any] ?? [:]
        let sources = node["thumbnails"] as? [[String: Any]] ?? node["sources"] as? [[String: Any]] ?? []
        return (sources.last?["url"] as? String).flatMap(URL.init(string:))
    }

    private static func video(_ node: [String: Any]) -> VideoItem? {
        guard let id = node["videoId"] as? String, id.count == 11,
              !containsShortsRoute(node) else { return nil }
        let title = text(node["title"])
        guard !title.isEmpty else { return nil }
        let byline = node["ownerText"] ?? node["shortBylineText"] ?? node["longBylineText"]
        let runs = (byline as? [String: Any])?["runs"] as? [[String: Any]]
        let endpoint = runs?.first?["navigationEndpoint"] as? [String: Any]
        let browse = endpoint?["browseEndpoint"] as? [String: Any]
        let duration = text(node["lengthText"])
        let endpointData = node["navigationEndpoint"] as? [String: Any]
        if endpointData?["reelWatchEndpoint"] != nil { return nil }
        return VideoItem(id: id, title: title, channel: text(byline),
                         views: text(node["viewCountText"]), age: text(node["publishedTimeText"]),
                         duration: duration, imageURL: imageURL(node["thumbnail"]), verified: false,
                         channelID: browse?["browseId"] as? String)
    }

    private static func lockupVideo(_ node: [String: Any]) -> VideoItem? {
        guard let id = node["contentId"] as? String, id.count == 11,
              node["contentType"] as? String == "LOCKUP_CONTENT_TYPE_VIDEO",
              !containsShortsRoute(node) else { return nil }
        let metadata = (node["metadata"] as? [String: Any])?["lockupMetadataViewModel"] as? [String: Any] ?? [:]
        let title = text(metadata["title"])
        guard !title.isEmpty else { return nil }
        let contentMetadata = (metadata["metadata"] as? [String: Any])?["contentMetadataViewModel"] as? [String: Any]
        let rows = contentMetadata?["metadataRows"] as? [[String: Any]] ?? []
        let parts = rows.map { ($0["metadataParts"] as? [[String: Any]] ?? []).map { text($0["text"]) } }
        let thumbnail = (node["contentImage"] as? [String: Any])?["thumbnailViewModel"] as? [String: Any] ?? [:]
        let overlays = thumbnail["overlays"] as? [[String: Any]] ?? []
        let badges = overlays.compactMap { $0["thumbnailOverlayBadgeViewModel"] as? [String: Any] }
            .flatMap { $0["thumbnailBadges"] as? [[String: Any]] ?? [] }
        let duration = badges.compactMap { ($0["thumbnailBadgeViewModel"] as? [String: Any])?["text"] as? String }.first ?? ""
        return VideoItem(id: id, title: title, channel: parts.first?.first ?? "YouTube",
                         views: parts.dropFirst().first?.first ?? "Recommended",
                         age: parts.dropFirst().first?.dropFirst().first ?? "", duration: duration,
                         imageURL: imageURL(thumbnail["image"]), verified: false)
    }

    private static func containsShortsRoute(_ value: Any, depth: Int = 0) -> Bool {
        guard depth < 16 else { return false }
        if let nodes = value as? [Any] { return nodes.contains { containsShortsRoute($0, depth: depth + 1) } }
        guard let node = value as? [String: Any] else { return false }
        if node["reelWatchEndpoint"] != nil { return true }
        if let url = node["url"] as? String, url.contains("/shorts/") { return true }
        return node.values.contains { containsShortsRoute($0, depth: depth + 1) }
    }
}
