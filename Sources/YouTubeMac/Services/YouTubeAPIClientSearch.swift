import Foundation

extension YouTubeAPIClient {
    func searchVideos(
        query: String,
        maxResults: Int = 12,
        order: String = "relevance",
        topicId: String? = nil,
        videoCategoryId: String? = nil,
        videoDuration: String? = nil,
        regionCode: String = "US",
        forceFresh: Bool = false
    ) async throws -> [VideoItem] {
        guard !YouGlassContentPolicy.isShortsSearch(query) else { return [] }

        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
        var queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "maxResults", value: "\(maxResults)"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "order", value: order),
            URLQueryItem(name: "regionCode", value: regionCode),
            URLQueryItem(name: "relevanceLanguage", value: "en"),
            URLQueryItem(name: "safeSearch", value: "moderate")
        ]
        if let topicId {
            queryItems.append(URLQueryItem(name: "topicId", value: topicId))
        }
        if let videoCategoryId {
            queryItems.append(URLQueryItem(name: "videoCategoryId", value: videoCategoryId))
        }
        if let videoDuration {
            queryItems.append(URLQueryItem(name: "videoDuration", value: videoDuration))
        }
        components.queryItems = queryItems

        let data = try await data(from: components, cacheTTL: 45, bypassCache: forceFresh)
        let response: SearchResponse
        do {
            response = try JSONDecoder().decode(SearchResponse.self, from: data)
        } catch DecodingError.keyNotFound(let key, let context) {
            // Record schema location only, never response contents or request URLs.
            YouGlassDiagnostics.record(
                .error, category: "search",
                message: "Search response missing required field",
                metadata: ["field": (context.codingPath.map(\.stringValue) + [key.stringValue]).joined(separator: ".")]
            )
            throw YouTubeAPIError.invalidResponse("YouTube search returned an incomplete response.")
        }
        let ids = response.items.compactMap(\.id.videoId).filter { !$0.isEmpty }
        guard !ids.isEmpty else { return [] }
        let resources = (try? await videoResources(ids: ids)) ?? []
        let resourcesByID = Dictionary(uniqueKeysWithValues: resources.map { ($0.id, $0) })

        return response.items.compactMap { item in
            // Search can contain non-video resources; one channel/playlist
            // result must not invalidate every playable result in the response.
            guard let videoID = item.id.videoId, !videoID.isEmpty else { return nil }
            if let resource = resourcesByID[videoID] {
                return videoItem(from: resource)
            }
            return VideoItem(
                id: videoID,
                title: item.snippet.title.htmlDecoded,
                channel: item.snippet.channelTitle.htmlDecoded,
                views: "YouTube",
                age: item.snippet.relativePublishedDate,
                duration: "",
                imageURL: URL(string: item.snippet.thumbnails.high?.url ?? item.snippet.thumbnails.medium?.url ?? item.snippet.thumbnails.defaultThumbnail.url),
                verified: false,
                channelID: item.snippet.channelID
            )
        }.filter(YouGlassContentPolicy.allows)
    }

    func mostPopularVideos(
        maxResults: Int = 12,
        regionCode: String = "US",
        videoCategoryId: String? = nil,
        forceFresh: Bool = false
    ) async throws -> [VideoItem] {
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")!
        var queryItems = [
            URLQueryItem(name: "part", value: "snippet,statistics,contentDetails"),
            URLQueryItem(name: "chart", value: "mostPopular"),
            URLQueryItem(name: "maxResults", value: "\(maxResults)"),
            URLQueryItem(name: "regionCode", value: regionCode)
        ]
        if let videoCategoryId {
            queryItems.append(URLQueryItem(name: "videoCategoryId", value: videoCategoryId))
        }
        components.queryItems = queryItems

        let data = try await data(from: components, preferOAuth: false, bypassCache: forceFresh)
        let response = try JSONDecoder().decode(VideoListResponse.self, from: data)
        return response.items.map(videoItem(from:)).filter(YouGlassContentPolicy.allows)
    }
}
