import Foundation

extension YouTubeAPIClient {
    func searchVideos(
        query: String,
        maxResults: Int = 12,
        order: String = "relevance",
        topicId: String? = nil,
        videoCategoryId: String? = nil,
        videoDuration: String? = nil,
        regionCode: String = "US"
    ) async throws -> [VideoItem] {
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

        let data = try await data(from: components, cacheTTL: 45)
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)
        let ids = response.items.map(\.id.videoId).filter { !$0.isEmpty }
        let resources = (try? await videoResources(ids: ids)) ?? []
        let resourcesByID = Dictionary(uniqueKeysWithValues: resources.map { ($0.id, $0) })

        return response.items.compactMap { item in
            if let resource = resourcesByID[item.id.videoId] {
                return videoItem(from: resource)
            }
            guard !item.id.videoId.isEmpty else { return nil }
            return VideoItem(
                id: item.id.videoId,
                title: item.snippet.title.htmlDecoded,
                channel: item.snippet.channelTitle.htmlDecoded,
                views: "YouTube",
                age: item.snippet.relativePublishedDate,
                duration: "",
                imageURL: URL(string: item.snippet.thumbnails.high?.url ?? item.snippet.thumbnails.medium?.url ?? item.snippet.thumbnails.defaultThumbnail.url),
                verified: false,
                channelID: item.snippet.channelID
            )
        }
    }

    func mostPopularVideos(maxResults: Int = 12, regionCode: String = "US", videoCategoryId: String? = nil) async throws -> [VideoItem] {
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

        let data = try await data(from: components, preferOAuth: false)
        let response = try JSONDecoder().decode(VideoListResponse.self, from: data)
        return response.items.map(videoItem(from:))
    }
}
