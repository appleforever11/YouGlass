import Foundation

extension YouTubeAPIClient {
    func rating(for videoID: String) async throws -> String? {
        guard try await oauth.validAccessToken() != nil else { return nil }
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos/getRating")!
        components.queryItems = [URLQueryItem(name: "id", value: videoID)]
        let data = try await data(from: components, preferOAuth: true)
        let response = try JSONDecoder().decode(RatingResponse.self, from: data)
        return response.items.first?.rating
    }

    func rate(videoID: String, rating: String) async throws {
        guard ["like", "dislike", "none"].contains(rating) else {
            throw YouTubeAPIError.invalidRequest("Unsupported YouTube rating.")
        }
        guard let token = try await oauth.validAccessToken() else {
            throw YouTubeAPIError.authenticationRequired
        }

        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos/rate")!
        components.queryItems = [
            URLQueryItem(name: "id", value: videoID),
            URLQueryItem(name: "rating", value: rating)
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try await requestData(request)
    }

    func subscribe(to channelID: String) async throws {
        guard let token = try await oauth.validAccessToken() else {
            throw YouTubeAPIError.authenticationRequired
        }

        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/subscriptions")!
        components.queryItems = [URLQueryItem(name: "part", value: "snippet")]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "snippet": [
                "resourceId": [
                    "kind": "youtube#channel",
                    "channelId": channelID
                ]
            ]
        ])
        _ = try await requestData(request)
    }

    func mySubscriptions(maxResults: Int = 30) async throws -> [SubscriptionItem] {
        guard let token = try await oauth.validAccessToken() else {
            throw YouTubeAPIError.authenticationRequired
        }

        let limit = max(1, min(maxResults, 200))
        var pageToken: String?
        var items: [SubscriptionItem] = []

        repeat {
            var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/subscriptions")!
            components.queryItems = [
                URLQueryItem(name: "part", value: "snippet"),
                URLQueryItem(name: "mine", value: "true"),
                URLQueryItem(name: "maxResults", value: "\(min(limit - items.count, 50))"),
                URLQueryItem(name: "order", value: "relevance")
            ]
            if let pageToken {
                components.queryItems?.append(URLQueryItem(name: "pageToken", value: pageToken))
            }

            let data = try await authorizedData(from: components.url!, token: token)
            let response = try JSONDecoder().decode(SubscriptionResponse.self, from: data)
            items.append(contentsOf: response.items.compactMap { item in
                guard let channelID = item.snippet.resourceID?.channelID else { return nil }
                return SubscriptionItem(
                    id: channelID,
                    name: item.snippet.title.htmlDecoded,
                    avatarURL: URL(string: item.snippet.thumbnails.medium?.url ?? item.snippet.thumbnails.defaultThumbnail.url),
                    channelURL: URL(string: "https://www.youtube.com/channel/\(channelID)"),
                    isLive: false
                )
            })
            pageToken = response.nextPageToken
        } while items.count < limit && pageToken != nil

        return items.reduce(into: [SubscriptionItem]()) { result, item in
            if !result.contains(where: { $0.id == item.id }) {
                result.append(item)
            }
        }
    }

    func likedVideos(maxResults: Int = 12) async throws -> [VideoItem] {
        guard let token = try await oauth.validAccessToken() else {
            throw YouTubeAPIError.authenticationRequired
        }

        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/playlistItems")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails"),
            URLQueryItem(name: "playlistId", value: "LL"),
            URLQueryItem(name: "maxResults", value: "\(maxResults)")
        ]

        let data = try await authorizedData(from: components.url!, token: token)
        let response = try JSONDecoder().decode(PlaylistItemsResponse.self, from: data)
        let playlistItems = response.items.compactMap { item -> (String, VideoItem)? in
            let videoID = item.contentDetails.videoId
            guard !videoID.isEmpty else { return nil }
            let fallback = VideoItem(
                id: videoID,
                title: item.snippet.title.htmlDecoded,
                channel: (item.snippet.videoOwnerChannelTitle ?? item.snippet.channelTitle).htmlDecoded,
                views: "Liked",
                age: item.snippet.relativePublishedDate,
                duration: "",
                imageURL: URL(string: item.snippet.thumbnails.high?.url ?? item.snippet.thumbnails.medium?.url ?? item.snippet.thumbnails.defaultThumbnail.url),
                verified: false
            )
            return (videoID, fallback)
        }
        let ids = playlistItems.map(\.0)
        let resources = (try? await videoResources(ids: ids)) ?? []
        let resourcesByID = Dictionary(uniqueKeysWithValues: resources.map { ($0.id, $0) })
        return playlistItems.map { id, fallback in
            resourcesByID[id].map(videoItem(from:)) ?? fallback
        }.filter(YouGlassContentPolicy.allows)
    }
}
