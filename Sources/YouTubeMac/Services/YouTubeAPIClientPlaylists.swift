import Foundation

extension YouTubeAPIClient {
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

    func channelPlaylists(channelID: String, maxResults: Int = 30) async throws -> [YouTubePlaylist] {
        guard !channelID.isEmpty else {
            throw YouTubeAPIError.invalidRequest("A channel ID is required.")
        }

        let limit = max(1, min(maxResults, 200))
        var pageToken: String?
        var playlists: [YouTubePlaylist] = []

        repeat {
            var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/playlists")!
            components.queryItems = [
                URLQueryItem(name: "part", value: "snippet,contentDetails"),
                URLQueryItem(name: "channelId", value: channelID),
                URLQueryItem(name: "maxResults", value: "\(min(limit - playlists.count, 50))")
            ]
            if let pageToken {
                components.queryItems?.append(URLQueryItem(name: "pageToken", value: pageToken))
            }

            let data = try await data(from: components)
            let response = try JSONDecoder().decode(PlaylistListResponse.self, from: data)
            playlists.append(contentsOf: response.items.map(Self.playlist(from:)))
            pageToken = response.nextPageToken
        } while playlists.count < limit && pageToken != nil

        return playlists.reduce(into: [YouTubePlaylist]()) { result, playlist in
            if !result.contains(where: { $0.id == playlist.id }) {
                result.append(playlist)
            }
        }
    }

    static func playlist(from item: PlaylistResource) -> YouTubePlaylist {
        YouTubePlaylist(
            id: item.id,
            title: item.snippet.title.htmlDecoded,
            description: item.snippet.description.htmlDecoded,
            thumbnailURL: URL(string: item.snippet.thumbnails.high?.url ?? item.snippet.thumbnails.medium?.url ?? item.snippet.thumbnails.defaultThumbnail.url),
            itemCount: item.contentDetails?.itemCount ?? 0
        )
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
}
