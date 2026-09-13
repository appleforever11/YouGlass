import Foundation

extension YouTubeStore {
        func recommendationQuery(for video: VideoItem) -> String {
            let titleWords = video.title
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 3 }
                .prefix(7)
                .joined(separator: " ")
            return "\(video.channel) \(titleWords)".trimmingCharacters(in: .whitespacesAndNewlines)
        }

}
