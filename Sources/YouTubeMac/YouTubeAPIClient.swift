import Foundation
import Security

struct YouTubeAPIClient: Sendable {
    private let apiKey: String?
    private let oauth: YouTubeOAuthClient
    private let session: URLSession
    private let requestGate: YouGlassRequestGate
    private let responseCache: YouGlassResponseCache

    init(
        apiKey: String? = YouTubeAPIClient.resolveAPIKey(),
        oauth: YouTubeOAuthClient = .shared,
        session: URLSession = .shared,
        requestGate: YouGlassRequestGate = youGlassSharedRequestGate,
        responseCache: YouGlassResponseCache = youGlassSharedResponseCache
    ) {
        self.apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? apiKey : nil
        self.oauth = oauth
        self.session = session
        self.requestGate = requestGate
        self.responseCache = responseCache
    }

    var canConnect: Bool {
        apiKey != nil
    }

    func hasCredentials() async -> Bool {
        if apiKey != nil { return true }
        return (try? await oauth.validAccessToken()) != nil
    }

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

    func comments(videoID: String, maxResults: Int = 50, pageToken: String? = nil) async throws -> [VideoComment] {
        try await commentsPage(videoID: videoID, maxResults: maxResults, pageToken: pageToken).comments
    }

    func commentsPage(videoID: String, maxResults: Int = 50, pageToken: String? = nil) async throws -> CommentPage {
        guard !videoID.isEmpty else {
            return CommentPage(comments: [], totalCount: 0, isAvailable: false, message: "This video does not have a valid YouTube ID.")
        }

        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/commentThreads")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "videoId", value: videoID),
            URLQueryItem(name: "maxResults", value: "\(min(maxResults, 100))"),
            URLQueryItem(name: "order", value: "relevance"),
            URLQueryItem(name: "textFormat", value: "plainText")
        ]
        if let pageToken, !pageToken.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "pageToken", value: pageToken))
        }

        let data = try await data(from: components)
        let response = try JSONDecoder().decode(CommentThreadResponse.self, from: data)
        let comments = response.items.compactMap { item -> VideoComment? in
            guard let topLevelComment = item.snippet.topLevelComment else { return nil }
            let snippet = topLevelComment.snippet
            return VideoComment(
                id: item.id,
                author: snippet.authorDisplayName.htmlDecoded,
                text: snippet.textDisplay.htmlDecoded,
                age: snippet.relativePublishedDate,
                likes: snippet.likeCount.abbreviated,
                avatarURL: URL(string: snippet.authorProfileImageUrl)
            )
        }
        return CommentPage(
            comments: comments,
            totalCount: response.pageInfo?.totalResults ?? comments.count,
            isAvailable: true,
            message: comments.isEmpty ? "No published comments were returned for this video." : nil,
            nextPageToken: response.nextPageToken
        )
    }

    func channelPage(for subscription: SubscriptionItem, maxResults: Int = 30) async throws -> YouTubeChannelPage {
        let resource = try await channelResource(for: subscription)
        guard let uploadsID = resource.contentDetails?.relatedPlaylists.uploads else {
            throw YouTubeAPIError.invalidResponse("YouTube did not return an uploads playlist for this channel.")
        }

        let playlistIDs = try await uploadVideoIDs(playlistID: uploadsID, maxResults: maxResults)
        let resources = try await videoResources(ids: playlistIDs)
        let resourcesByID = Dictionary(uniqueKeysWithValues: resources.map { ($0.id, $0) })
        let orderedItems = playlistIDs.compactMap { resourcesByID[$0] }.map { videoItem(from: $0) }
        let shorts = orderedItems.filter { durationSeconds(for: $0.duration) <= 180 }
        let live = resources
            .filter { $0.liveStreamingDetails?.isCurrentlyLive == true }
            .sorted { $0.snippet.publishedAt > $1.snippet.publishedAt }
            .map { videoItem(from: $0) }

        let subscriberText: String
        if resource.statistics?.hiddenSubscriberCount == true {
            subscriberText = "Subscribers hidden"
        } else if let raw = resource.statistics?.subscriberCount {
            subscriberText = "\(raw.abbreviatedCount) subscribers"
        } else {
            subscriberText = "Subscribers unavailable"
        }

        let videoText: String
        if let raw = resource.statistics?.videoCount {
            videoText = "\(raw.abbreviatedCount) videos"
        } else {
            videoText = "Videos unavailable"
        }

        let channel = YouTubeChannel(
            id: resource.id,
            name: resource.snippet.title.htmlDecoded,
            handle: resource.snippet.customURL ?? handle(from: subscription) ?? "@\(resource.id)",
            description: resource.snippet.description.htmlDecoded,
            avatarURL: URL(string: resource.snippet.thumbnails.high?.url ?? resource.snippet.thumbnails.medium?.url ?? resource.snippet.thumbnails.defaultThumbnail.url),
            bannerURL: resource.brandingSettings?.image?.bannerExternalURL.flatMap(URL.init(string:)),
            subscriberCount: subscriberText,
            videoCount: videoText,
            isSubscribed: true
        )

        return YouTubeChannelPage(channel: channel, videos: orderedItems, shorts: shorts, live: live)
    }

    func videoDetails(videoID: String) async throws -> VideoDetails {
        guard let resource = try await videoResources(ids: [videoID]).first else {
            throw YouTubeAPIError.invalidResponse("YouTube did not return details for this video.")
        }

        let currentRating = try? await rating(for: videoID)
        return details(from: resource, rating: currentRating ?? nil)
    }

    func liveChatPage(liveChatID: String, pageToken: String? = nil, maxResults: Int = 100) async throws -> LiveChatPage {
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/liveChat/messages")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet,authorDetails"),
            URLQueryItem(name: "liveChatId", value: liveChatID),
            URLQueryItem(name: "maxResults", value: "\(min(maxResults, 2000))")
        ]
        if let pageToken {
            components.queryItems?.append(URLQueryItem(name: "pageToken", value: pageToken))
        }

        let data = try await data(from: components)
        let response = try JSONDecoder().decode(LiveChatResponse.self, from: data)
        let messages = response.items.compactMap { item -> LiveChatMessage? in
            guard let text = item.snippet.displayMessage?.htmlDecoded, !text.isEmpty else { return nil }
            return LiveChatMessage(
                id: item.id,
                author: item.authorDetails?.displayName.htmlDecoded ?? "YouTube viewer",
                text: text,
                publishedAt: item.snippet.publishedAt.map(relativeDate) ?? "now",
                avatarURL: item.authorDetails?.profileImageURL.flatMap(URL.init(string:)),
                isHighlighted: item.snippet.type != "textMessageEvent"
            )
        }
        return LiveChatPage(
            messages: messages,
            nextPageToken: response.nextPageToken,
            pollingInterval: UInt64(max(2_000, response.pollingIntervalMillis ?? 5_000)) * 1_000_000,
            isLive: true,
            isAvailable: true
        )
    }

    func sendLiveChatMessage(liveChatID: String, text: String) async throws -> LiveChatMessage {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !liveChatID.isEmpty, !cleanText.isEmpty else {
            throw YouTubeAPIError.invalidRequest("A live chat and message are required.")
        }
        guard let token = try await oauth.validAccessToken() else {
            throw YouTubeAPIError.authenticationRequired
        }

        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/liveChat/messages")!
        components.queryItems = [URLQueryItem(name: "part", value: "snippet,authorDetails")]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "snippet": [
                "liveChatId": liveChatID,
                "type": "textMessageEvent",
                "textMessageDetails": [
                    "messageText": cleanText
                ]
            ]
        ])

        let data = try await requestData(request)
        let response = try JSONDecoder().decode(LiveChatResponse.self, from: data)
        guard let item = response.items.first else {
            throw YouTubeAPIError.invalidResponse("YouTube accepted the chat message but did not return it.")
        }
        return LiveChatMessage(
            id: item.id,
            author: item.authorDetails?.displayName.htmlDecoded ?? "You",
            text: item.snippet.displayMessage?.htmlDecoded ?? cleanText,
            publishedAt: item.snippet.publishedAt.map(relativeDate) ?? "now",
            avatarURL: item.authorDetails?.profileImageURL.flatMap(URL.init(string:)),
            isHighlighted: item.snippet.type != "textMessageEvent"
        )
    }

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

    func addComment(videoID: String, channelID: String, text: String) async throws -> VideoComment {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !videoID.isEmpty, !channelID.isEmpty, !cleanText.isEmpty else {
            throw YouTubeAPIError.invalidRequest("A video, channel, and comment are required.")
        }
        guard let token = try await oauth.validAccessToken() else {
            throw YouTubeAPIError.authenticationRequired
        }

        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/commentThreads")!
        components.queryItems = [URLQueryItem(name: "part", value: "snippet")]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "snippet": [
                "channelId": channelID,
                "videoId": videoID,
                "topLevelComment": [
                    "snippet": [
                        "textOriginal": cleanText
                    ]
                ]
            ]
        ])

        let data = try await requestData(request)
        let response = try JSONDecoder().decode(CommentThreadResponse.self, from: data)
        guard let item = response.items.first,
              let topLevelComment = item.snippet.topLevelComment else {
            throw YouTubeAPIError.invalidResponse("YouTube accepted the comment but did not return it.")
        }

        let snippet = topLevelComment.snippet
        return VideoComment(
            id: item.id,
            author: snippet.authorDisplayName.htmlDecoded,
            text: snippet.textDisplay.htmlDecoded,
            age: snippet.relativePublishedDate,
            likes: snippet.likeCount.abbreviated,
            avatarURL: URL(string: snippet.authorProfileImageUrl)
        )
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
        }
    }

    func myPlaylists(maxResults: Int = 50) async throws -> [YouTubePlaylist] {
        guard let token = try await oauth.validAccessToken() else {
            throw YouTubeAPIError.authenticationRequired
        }

        let limit = max(1, min(maxResults, 200))
        var pageToken: String?
        var playlists: [YouTubePlaylist] = []

        repeat {
            var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/playlists")!
            components.queryItems = [
                URLQueryItem(name: "part", value: "snippet,contentDetails"),
                URLQueryItem(name: "mine", value: "true"),
                URLQueryItem(name: "maxResults", value: "\(min(limit - playlists.count, 50))")
            ]
            if let pageToken {
                components.queryItems?.append(URLQueryItem(name: "pageToken", value: pageToken))
            }

            let data = try await authorizedData(from: components.url!, token: token)
            let response = try JSONDecoder().decode(PlaylistListResponse.self, from: data)
            playlists.append(contentsOf: response.items.map { item in
                YouTubePlaylist(
                    id: item.id,
                    title: item.snippet.title.htmlDecoded,
                    description: item.snippet.description.htmlDecoded,
                    thumbnailURL: URL(string: item.snippet.thumbnails.high?.url ?? item.snippet.thumbnails.medium?.url ?? item.snippet.thumbnails.defaultThumbnail.url),
                    itemCount: item.contentDetails?.itemCount ?? 0
                )
            })
            pageToken = response.nextPageToken
        } while playlists.count < limit && pageToken != nil

        return playlists.reduce(into: [YouTubePlaylist]()) { result, playlist in
            if !result.contains(where: { $0.id == playlist.id }) {
                result.append(playlist)
            }
        }
    }

    func playlistVideos(playlistID: String, maxResults: Int = 50) async throws -> [VideoItem] {
        guard !playlistID.isEmpty else {
            throw YouTubeAPIError.invalidRequest("A playlist ID is required.")
        }

        let limit = max(1, min(maxResults, 200))
        var pageToken: String?
        var playlistItems: [(String, VideoItem)] = []

        repeat {
            var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/playlistItems")!
            components.queryItems = [
                URLQueryItem(name: "part", value: "snippet,contentDetails"),
                URLQueryItem(name: "playlistId", value: playlistID),
                URLQueryItem(name: "maxResults", value: "\(min(limit - playlistItems.count, 50))")
            ]
            if let pageToken {
                components.queryItems?.append(URLQueryItem(name: "pageToken", value: pageToken))
            }

            let data = try await data(from: components)
            let response = try JSONDecoder().decode(PlaylistItemsResponse.self, from: data)
            playlistItems.append(contentsOf: response.items.compactMap { item in
                let videoID = item.contentDetails.videoId
                guard !videoID.isEmpty else { return nil }
                let fallback = VideoItem(
                    id: videoID,
                    title: item.snippet.title.htmlDecoded,
                    channel: (item.snippet.videoOwnerChannelTitle ?? item.snippet.channelTitle).htmlDecoded,
                    views: "YouTube",
                    age: item.snippet.relativePublishedDate,
                    duration: "",
                    imageURL: URL(string: item.snippet.thumbnails.high?.url ?? item.snippet.thumbnails.medium?.url ?? item.snippet.thumbnails.defaultThumbnail.url),
                    verified: false
                )
                return (videoID, fallback)
            })
            pageToken = response.nextPageToken
        } while playlistItems.count < limit && pageToken != nil

        let ordered = playlistItems.reduce(into: [(String, VideoItem)]()) { result, item in
            if !result.contains(where: { $0.0 == item.0 }) {
                result.append(item)
            }
        }
        let resources = (try? await videoResources(ids: ordered.map(\.0))) ?? []
        let resourcesByID = Dictionary(uniqueKeysWithValues: resources.map { ($0.id, $0) })
        return ordered.map { id, fallback in
            resourcesByID[id].map(videoItem(from:)) ?? fallback
        }
    }

    private func channelResource(for subscription: SubscriptionItem) async throws -> ChannelResource {
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/channels")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails,statistics,brandingSettings")
        ]

        if let channelID = channelID(from: subscription) {
            components.queryItems?.append(URLQueryItem(name: "id", value: channelID))
        } else if let handle = handle(from: subscription) {
            components.queryItems?.append(URLQueryItem(name: "forHandle", value: handle))
        } else {
            throw YouTubeAPIError.invalidRequest("The channel does not have a usable YouTube handle or channel ID.")
        }

        let data = try await data(from: components)
        let response = try JSONDecoder().decode(ChannelListResponse.self, from: data)
        guard let resource = response.items.first else {
            throw YouTubeAPIError.invalidResponse("YouTube could not find this channel.")
        }
        return resource
    }

    private func uploadVideoIDs(playlistID: String, maxResults: Int) async throws -> [String] {
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/playlistItems")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails"),
            URLQueryItem(name: "playlistId", value: playlistID),
            URLQueryItem(name: "maxResults", value: "\(min(maxResults, 50))")
        ]

        let data = try await data(from: components)
        let response = try JSONDecoder().decode(PlaylistItemsResponse.self, from: data)
        return response.items.compactMap { item in
            let id = item.contentDetails.videoId
            return id.isEmpty ? nil : id
        }
    }

    private func videoResources(ids: [String]) async throws -> [VideoListItem] {
        let validIDs = ids.filter { !$0.isEmpty }.prefix(50)
        guard !validIDs.isEmpty else { return [] }

        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet,statistics,contentDetails,liveStreamingDetails"),
            URLQueryItem(name: "id", value: validIDs.joined(separator: ","))
        ]
        let data = try await data(from: components)
        let response = try JSONDecoder().decode(VideoListResponse.self, from: data)
        return response.items
    }

    private func videoItem(from resource: VideoListItem) -> VideoItem {
            VideoItem(
                id: resource.id,
                title: resource.snippet.title.htmlDecoded,
            channel: resource.snippet.channelTitle.htmlDecoded,
            views: resource.statistics?.viewCount?.abbreviatedViews ?? "YouTube",
            age: resource.snippet.relativePublishedDate,
                duration: resource.contentDetails?.displayDuration ?? "",
                imageURL: URL(string: resource.snippet.thumbnails.high?.url ?? resource.snippet.thumbnails.medium?.url ?? resource.snippet.thumbnails.defaultThumbnail.url),
                verified: false,
                channelID: resource.snippet.channelID
            )
    }

    private func details(from resource: VideoListItem, rating: String?) -> VideoDetails {
        let liveDetails = resource.liveStreamingDetails
        let isLive = liveDetails?.isCurrentlyLive == true
        return VideoDetails(
            id: resource.id,
            likeCount: resource.statistics?.likeCount?.abbreviatedCount ?? "Like count unavailable",
            commentCount: resource.statistics?.commentCount?.abbreviatedCount ?? "Comment count unavailable",
            concurrentViewers: liveDetails?.concurrentViewers?.abbreviatedCount,
            liveChatID: liveDetails?.activeLiveChatID,
            channelID: resource.snippet.channelID,
            channelAvatarURL: URL(string: resource.snippet.thumbnails.medium?.url ?? resource.snippet.thumbnails.defaultThumbnail.url),
            description: resource.snippet.description.htmlDecoded,
            isLive: isLive,
            rating: rating
        )
    }

    private func channelID(from subscription: SubscriptionItem) -> String? {
        if subscription.id.hasPrefix("UC") {
            return subscription.id
        }

        if let url = subscription.channelURL,
           let component = url.pathComponents.first(where: { $0.hasPrefix("UC") }) {
            return component
        }

        if let component = subscription.id.split(separator: "/").map(String.init).first(where: { $0.hasPrefix("UC") }) {
            return component
        }
        return nil
    }

    private func handle(from subscription: SubscriptionItem) -> String? {
        let url = subscription.channelURL ?? URL(string: subscription.id)
        guard let path = url?.pathComponents.first(where: { $0.hasPrefix("@") }) else {
            return nil
        }
        return path
    }

    private func durationSeconds(for displayDuration: String) -> Int {
        let parts = displayDuration.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 2: return parts[0] * 60 + parts[1]
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        default: return Int(displayDuration) ?? 0
        }
    }

    private func data(
        from components: URLComponents,
        preferOAuth: Bool = true,
        cacheTTL: TimeInterval = 20
    ) async throws -> Data {
        guard let url = components.url else {
            throw YouTubeAPIError.invalidRequest("YouTube request URL could not be constructed.")
        }

        if preferOAuth, let token = try await oauth.validAccessToken() {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            // OAuth responses can be account-specific, so do not share them
            // through the public response cache.
            return try await requestData(request)
        }

        guard let apiKey else {
            throw YouTubeAPIError.authenticationRequired
        }
        var authenticated = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var queryItems = authenticated.queryItems ?? []
        queryItems.append(URLQueryItem(name: "key", value: apiKey))
        authenticated.queryItems = queryItems
        // Cache only API-key responses. The cache key intentionally excludes
        // the key itself so it never becomes part of the in-memory cache map.
        return try await requestData(
            URLRequest(url: authenticated.url!),
            cacheKey: url.absoluteString,
            cacheTTL: cacheTTL
        )
    }

    private func authorizedData(from url: URL, token: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await requestData(request)
    }

    private func requestData(
        _ request: URLRequest,
        cacheKey: String? = nil,
        cacheTTL: TimeInterval = 20
    ) async throws -> Data {
        if let cacheKey, let cached = await responseCache.data(forKey: cacheKey) {
            YouGlassDiagnostics.api.debug("Using cached YouTube response for \(request.url?.path ?? "/", privacy: .public)")
            return cached
        }

        let method = (request.httpMethod ?? "GET").uppercased()
        let canRetry = method == "GET" || method == "HEAD"
        var attempt = 0

        while true {
            let requestStartedAt = Date()
            do {
                // Keep bursts from the feed, search, comments, and channel
                // paths below the quota/rate-limit threshold.
                await youGlassSharedRateLimitState.waitIfBlocked()
                await requestGate.wait(minimumInterval: 0.35)
                let requestPath = request.url?.path ?? "/"
                YouGlassDiagnostics.api.debug("YouTube request \(requestPath, privacy: .public)")
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw YouTubeAPIError.invalidResponse("YouTube returned a non-HTTP response.")
                }

                guard (200..<300).contains(httpResponse.statusCode) else {
                    let apiError = YouTubeAPIError.httpStatus(
                        httpResponse.statusCode,
                        reason: Self.apiErrorReason(from: data),
                        message: Self.apiErrorMessage(from: data)
                    )
                    if httpResponse.statusCode == 429 {
                        await youGlassSharedRateLimitState.markRateLimited()
                        YouGlassDiagnostics.record(
                            .warning,
                            category: "api",
                            message: "YouTube API rate limit cooldown started",
                            metadata: ["cooldownSeconds": "30", "path": requestPath]
                        )
                    }
                    guard canRetry, apiError.isRetryable, attempt < 2 else {
                        YouGlassDiagnostics.api.error("YouTube request failed with HTTP \(httpResponse.statusCode, privacy: .public)")
                        YouGlassDiagnostics.record(
                            .error,
                            category: "api",
                            message: "YouTube request failed",
                            metadata: [
                                "path": requestPath,
                                "status": String(httpResponse.statusCode),
                                "attempt": String(attempt + 1),
                                "error": apiError.localizedDescription
                            ]
                        )
                        throw apiError
                    }
                    if YouGlassDebugEngine.shared.isVerboseLoggingEnabled {
                        YouGlassDiagnostics.record(
                            .notice,
                            category: "api",
                            message: "Retrying a transient YouTube request",
                            metadata: [
                                "path": requestPath,
                                "status": String(httpResponse.statusCode),
                                "attempt": String(attempt + 1)
                            ]
                        )
                    }
                    try await Self.waitBeforeRetry(attempt: attempt)
                    attempt += 1
                    continue
                }

                if YouGlassDebugEngine.shared.isVerboseLoggingEnabled {
                    YouGlassDiagnostics.record(
                        .debug,
                        category: "api",
                        message: "YouTube request completed",
                        metadata: [
                            "path": requestPath,
                            "status": String(httpResponse.statusCode),
                            "durationMs": String(Int(Date().timeIntervalSince(requestStartedAt) * 1000))
                        ]
                    )
                }

                if let cacheKey {
                    await responseCache.insert(data, forKey: cacheKey, ttl: cacheTTL)
                }
                return data
            } catch let error as YouTubeAPIError {
                if case .httpStatus = error {
                    // HTTP failures are recorded at the status check above.
                } else {
                    YouGlassDiagnostics.record(
                        .error,
                        category: "api",
                        message: "YouTube API request ended with an error",
                        metadata: [
                            "path": request.url?.path ?? "/",
                            "attempt": String(attempt + 1),
                            "error": error.localizedDescription
                        ]
                    )
                }
                throw error
            } catch {
                guard canRetry, attempt < 2 else {
                    YouGlassDiagnostics.record(
                        .error,
                        category: "api",
                        message: "YouTube request ended with a transport error",
                        metadata: [
                            "path": request.url?.path ?? "/",
                            "attempt": String(attempt + 1),
                            "error": error.localizedDescription
                        ]
                    )
                    throw error
                }
                if YouGlassDebugEngine.shared.isVerboseLoggingEnabled {
                    YouGlassDiagnostics.record(
                        .notice,
                        category: "api",
                        message: "Retrying a transport error",
                        metadata: [
                            "path": request.url?.path ?? "/",
                            "attempt": String(attempt + 1),
                            "error": error.localizedDescription
                        ]
                    )
                }
                try await Self.waitBeforeRetry(attempt: attempt)
                attempt += 1
            }
        }
    }

    private static func waitBeforeRetry(attempt: Int) async throws {
        let delays: [UInt64] = [250_000_000, 750_000_000]
        try await Task.sleep(nanoseconds: delays[min(attempt, delays.count - 1)])
    }

    private static func apiErrorReason(from data: Data) -> String? {
        (try? JSONDecoder().decode(YouTubeAPIErrorEnvelope.self, from: data))?.error?.errors?.first?.reason
    }

    private static func apiErrorMessage(from data: Data) -> String? {
        (try? JSONDecoder().decode(YouTubeAPIErrorEnvelope.self, from: data))?.error?.message
    }

    private static func resolveAPIKey() -> String? {
        if let key = ProcessInfo.processInfo.environment["YOUTUBE_API_KEY"], !key.isEmpty {
            return key
        }

        return KeychainStore.read(service: "com.kevinhowe.YouGlass", account: "YOUTUBE_API_KEY")
            ?? KeychainStore.read(service: "com.kevinhowe.YouTubeMac", account: "YOUTUBE_API_KEY")
    }
}

enum YouTubeAPIError: LocalizedError, Equatable {
    case authenticationRequired
    case invalidRequest(String)
    case invalidResponse(String)
    case httpStatus(Int, reason: String? = nil, message: String? = nil)

    var isRetryable: Bool {
        switch self {
        case .httpStatus(let status, _, let message):
            // Retrying a throttled request multiplies the pressure on the
            // project and makes a search failure slower. Let the caller use
            // its web-session fallback instead.
            return status == 408 || (500...599).contains(status)
                || message?.localizedCaseInsensitiveContains("temporar") == true
        default:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "YouTube Data API credentials are not configured. Use an API key or OAuth access token for official API data."
        case .invalidRequest(let message), .invalidResponse(let message):
            return message
        case .httpStatus(let status, let reason, let message):
            if reason == "quotaExceeded" || reason == "dailyLimitExceeded" {
                return "YouTube API quota is exhausted for this project. Add another API project or wait for the quota to reset."
            }
            if reason == "forbidden" || status == 403 {
                return message.map { "YouTube denied this request: \($0)" } ?? "YouTube denied this request. Check API and OAuth access."
            }
            if status == 401 {
                return "YouTube authorization expired or was rejected. Sign in again in Settings."
            }
            if status == 429 {
                return "YouTube is rate limiting requests. Please try again in a moment."
            }
            if let message, !message.isEmpty {
                return "YouTube returned HTTP status \(status): \(message)"
            }
            return "YouTube returned HTTP status \(status)."
        }
    }
}

private struct YouTubeAPIErrorEnvelope: Decodable {
    let error: YouTubeAPIErrorBody?
}

private struct YouTubeAPIErrorBody: Decodable {
    let message: String?
    let errors: [YouTubeAPIErrorDetail]?
}

private struct YouTubeAPIErrorDetail: Decodable {
    let reason: String?
}

private struct SearchResponse: Decodable {
    let items: [SearchItem]
}

private struct SearchItem: Decodable {
    struct ID: Decodable {
        let videoId: String
    }

    let id: ID
    let snippet: Snippet
}

private struct VideoListResponse: Decodable {
    let items: [VideoListItem]
}

private struct VideoListItem: Decodable {
    let id: String
    let snippet: Snippet
    let statistics: VideoStatistics?
    let contentDetails: VideoContentDetails?
    let liveStreamingDetails: VideoLiveStreamingDetails?
}

private struct VideoStatistics: Decodable {
    let viewCount: String?
    let likeCount: String?
    let commentCount: String?
}

private struct VideoLiveStreamingDetails: Decodable {
    let concurrentViewers: String?
    let activeLiveChatID: String?
    let actualStartTime: String?
    let actualEndTime: String?

    enum CodingKeys: String, CodingKey {
        case concurrentViewers
        case activeLiveChatID = "activeLiveChatId"
        case actualStartTime
        case actualEndTime
    }

    var isCurrentlyLive: Bool {
        activeLiveChatID != nil || (actualStartTime != nil && actualEndTime == nil)
    }
}

private struct VideoContentDetails: Decodable {
    let duration: String

    var displayDuration: String {
        var hours = 0
        var minutes = 0
        var seconds = 0
        var number = ""

        for character in duration {
            if character.isNumber {
                number.append(character)
            } else {
                let value = Int(number) ?? 0
                if character == "H" { hours = value }
                if character == "M" { minutes = value }
                if character == "S" { seconds = value }
                number = ""
            }
        }

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct Snippet: Decodable {
    let publishedAt: Date
    let title: String
    let channelTitle: String
    let channelID: String?
    let videoOwnerChannelTitle: String?
    let description: String
    let thumbnails: ThumbnailSet

    var relativePublishedDate: String {
        let days = max(1, Calendar.current.dateComponents([.day], from: publishedAt, to: Date()).day ?? 1)
        if days < 7 { return days == 1 ? "1 day ago" : "\(days) days ago" }
        let weeks = days / 7
        if weeks < 5 { return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago" }
        let months = max(1, days / 30)
        return months == 1 ? "1 month ago" : "\(months) months ago"
    }

    enum CodingKeys: CodingKey {
        case publishedAt
        case title
        case channelTitle
        case channelID
        case videoOwnerChannelTitle
        case description
        case thumbnails
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        channelTitle = try container.decode(String.self, forKey: .channelTitle)
        channelID = try container.decodeIfPresent(String.self, forKey: .channelID)
        videoOwnerChannelTitle = try container.decodeIfPresent(String.self, forKey: .videoOwnerChannelTitle)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        thumbnails = try container.decode(ThumbnailSet.self, forKey: .thumbnails)
        let dateString = try container.decode(String.self, forKey: .publishedAt)
        publishedAt = ISO8601DateFormatter().date(from: dateString) ?? Date()
    }
}

private struct ThumbnailSet: Decodable {
    let defaultThumbnail: Thumbnail
    let medium: Thumbnail?
    let high: Thumbnail?

    enum CodingKeys: String, CodingKey {
        case defaultThumbnail = "default"
        case medium
        case high
    }
}

private struct Thumbnail: Decodable {
    let url: String
}

private struct ChannelListResponse: Decodable {
    let items: [ChannelResource]
}

private struct ChannelResource: Decodable {
    let id: String
    let snippet: ChannelSnippet
    let contentDetails: ChannelContentDetails?
    let statistics: ChannelStatistics?
    let brandingSettings: ChannelBrandingSettings?
}

private struct ChannelSnippet: Decodable {
    let title: String
    let description: String
    let customURL: String?
    let thumbnails: ThumbnailSet

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case customURL = "customUrl"
        case thumbnails
    }
}

private struct ChannelContentDetails: Decodable {
    let relatedPlaylists: RelatedPlaylists
}

private struct RelatedPlaylists: Decodable {
    let uploads: String
}

private struct ChannelStatistics: Decodable {
    let subscriberCount: String?
    let hiddenSubscriberCount: Bool?
    let videoCount: String?
}

private struct ChannelBrandingSettings: Decodable {
    let image: ChannelBrandingImage?
}

private struct ChannelBrandingImage: Decodable {
    let bannerExternalURL: String?

    enum CodingKeys: String, CodingKey {
        case bannerExternalURL = "bannerExternalUrl"
    }
}

private struct SubscriptionResponse: Decodable {
    let items: [SubscriptionItemResponse]
    let nextPageToken: String?
}

private struct SubscriptionItemResponse: Decodable {
    let snippet: SubscriptionSnippet
}

private struct SubscriptionSnippet: Decodable {
    let title: String
    let thumbnails: ThumbnailSet
    let resourceID: SubscriptionResourceID?

    enum CodingKeys: String, CodingKey {
        case title
        case thumbnails
        case resourceID = "resourceId"
    }
}

private struct SubscriptionResourceID: Decodable {
    let channelID: String

    enum CodingKeys: String, CodingKey {
        case channelID = "channelId"
    }
}

private struct PlaylistListResponse: Decodable {
    let items: [PlaylistResource]
    let nextPageToken: String?
}

private struct PlaylistResource: Decodable {
    let id: String
    let snippet: PlaylistSnippet
    let contentDetails: PlaylistDetails?
}

private struct PlaylistSnippet: Decodable {
    let title: String
    let description: String
    let thumbnails: ThumbnailSet
}

private struct PlaylistDetails: Decodable {
    let itemCount: Int?
}

private struct PlaylistItemsResponse: Decodable {
    let items: [PlaylistItemResponse]
    let nextPageToken: String?
}

private struct PlaylistItemResponse: Decodable {
    let snippet: Snippet
    let contentDetails: PlaylistContentDetails
}

private struct PlaylistContentDetails: Decodable {
    let videoId: String
}

private struct CommentThreadResponse: Decodable {
    let items: [CommentThreadItem]
    let pageInfo: PageInfo?
    let nextPageToken: String?
}

private struct PageInfo: Decodable {
    let totalResults: Int?
}

private struct CommentThreadItem: Decodable {
    let id: String
    let snippet: CommentThreadSnippet
}

private struct CommentThreadSnippet: Decodable {
    let topLevelComment: TopLevelComment?
}

private struct TopLevelComment: Decodable {
    let snippet: CommentSnippet
}

private struct CommentSnippet: Decodable {
    let authorDisplayName: String
    let authorProfileImageUrl: String
    let textDisplay: String
    let likeCount: Int
    let publishedAt: Date

    var relativePublishedDate: String {
        let days = max(1, Calendar.current.dateComponents([.day], from: publishedAt, to: Date()).day ?? 1)
        if days < 7 { return days == 1 ? "1 day ago" : "\(days) days ago" }
        let weeks = days / 7
        if weeks < 5 { return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago" }
        let months = max(1, days / 30)
        if months < 12 { return months == 1 ? "1 month ago" : "\(months) months ago" }
        let years = max(1, days / 365)
        return years == 1 ? "1 year ago" : "\(years) years ago"
    }

    enum CodingKeys: CodingKey {
        case authorDisplayName
        case authorProfileImageUrl
        case textDisplay
        case likeCount
        case publishedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        authorDisplayName = try container.decode(String.self, forKey: .authorDisplayName)
        authorProfileImageUrl = try container.decode(String.self, forKey: .authorProfileImageUrl)
        textDisplay = try container.decode(String.self, forKey: .textDisplay)
        likeCount = try container.decode(Int.self, forKey: .likeCount)
        let dateString = try container.decode(String.self, forKey: .publishedAt)
        publishedAt = ISO8601DateFormatter().date(from: dateString) ?? Date()
    }
}

private struct RatingResponse: Decodable {
    let items: [RatingItem]
}

private struct RatingItem: Decodable {
    let videoID: String
    let rating: String

    enum CodingKeys: String, CodingKey {
        case videoID = "videoId"
        case rating
    }
}

private struct LiveChatResponse: Decodable {
    let items: [LiveChatItem]
    let nextPageToken: String?
    let pollingIntervalMillis: Int?
}

private struct LiveChatItem: Decodable {
    let id: String
    let snippet: LiveChatSnippet
    let authorDetails: LiveChatAuthor?
}

private struct LiveChatSnippet: Decodable {
    let type: String
    let displayMessage: String?
    let publishedAt: String?
}

private struct LiveChatAuthor: Decodable {
    let displayName: String
    let profileImageURL: String?

    enum CodingKeys: String, CodingKey {
        case displayName
        case profileImageURL = "profileImageUrl"
    }
}

private extension Int {
    var abbreviated: String {
        if self >= 1_000_000 { return "\(self / 1_000_000)M" }
        if self >= 1_000 { return "\(self / 1_000)K" }
        return "\(self)"
    }
}

private extension String {
    var abbreviatedCount: String {
        guard let value = Int(self) else { return self }
        if value >= 1_000_000_000 { return String(format: "%.1fB", Double(value) / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", Double(value) / 1_000) }
        return "\(value)"
    }

    var abbreviatedViews: String {
        guard let value = Int(self) else { return "YouTube" }
        if value >= 1_000_000 { return "\(value / 1_000_000)M views" }
        if value >= 1_000 { return "\(value / 1_000)K views" }
        return "\(value) views"
    }
}

private func relativeDate(_ value: String) -> String {
    guard let date = ISO8601DateFormatter().date(from: value) else { return "now" }
    let seconds = max(1, Int(Date().timeIntervalSince(date)))
    if seconds < 60 { return "now" }
    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes)m" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours)h" }
    return "\(hours / 24)d"
}

private extension String {
    var htmlDecoded: String {
        replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
