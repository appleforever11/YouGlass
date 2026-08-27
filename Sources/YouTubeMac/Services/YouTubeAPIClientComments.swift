import Foundation

extension YouTubeAPIClient {
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
}
