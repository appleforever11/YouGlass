import Foundation

extension YouTubeAPIClient {
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
}
