import Foundation

extension YouTubeAPIClient {
    func channelPage(for subscription: SubscriptionItem, maxResults: Int = 30) async throws -> YouTubeChannelPage {
        let resource = try await channelResource(for: subscription)
        guard let uploadsID = resource.contentDetails?.relatedPlaylists.uploads else {
            throw YouTubeAPIError.invalidResponse("YouTube did not return an uploads playlist for this channel.")
        }

        let playlistIDs = try await uploadVideoIDs(playlistID: uploadsID, maxResults: maxResults)
        let resources = try await videoResources(ids: playlistIDs)
        let resourcesByID = Dictionary(uniqueKeysWithValues: resources.map { ($0.id, $0) })
        let orderedItems = playlistIDs
            .compactMap { resourcesByID[$0] }
            .map { videoItem(from: $0) }
            .filter(YouGlassContentPolicy.allows)
        let live = resources
            .filter { $0.liveStreamingDetails?.isCurrentlyLive == true }
            .sorted { $0.snippet.publishedAt > $1.snippet.publishedAt }
            .map { videoItem(from: $0) }
            .filter(YouGlassContentPolicy.allows)

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

        let playlists = (try? await channelPlaylists(channelID: resource.id, maxResults: 30)) ?? []
        return YouTubeChannelPage(
            channel: channel,
            videos: orderedItems,
            live: live,
            playlists: playlists
        )
    }

    func channelResource(for subscription: SubscriptionItem) async throws -> ChannelResource {
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

    func uploadVideoIDs(playlistID: String, maxResults: Int) async throws -> [String] {
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

    func channelID(from subscription: SubscriptionItem) -> String? {
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

    func handle(from subscription: SubscriptionItem) -> String? {
        let url = subscription.channelURL ?? URL(string: subscription.id)
        guard let path = url?.pathComponents.first(where: { $0.hasPrefix("@") }) else {
            return nil
        }
        return path
    }
}
