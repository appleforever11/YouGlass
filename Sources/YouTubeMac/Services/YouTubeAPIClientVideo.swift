import Foundation

extension YouTubeAPIClient {
    func videoDetails(videoID: String) async throws -> VideoDetails {
        guard let resource = try await videoResources(ids: [videoID]).first else {
            throw YouTubeAPIError.invalidResponse("YouTube did not return details for this video.")
        }

        let currentRating = try? await rating(for: videoID)
        return details(from: resource, rating: currentRating ?? nil)
    }

    func videoResources(ids: [String]) async throws -> [VideoListItem] {
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

    func videoItem(from resource: VideoListItem) -> VideoItem {
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

    func details(from resource: VideoListItem, rating: String?) -> VideoDetails {
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
}
