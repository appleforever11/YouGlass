import Foundation

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
