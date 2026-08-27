import Foundation

extension VideoComment {
    static let samples = [
        VideoComment(
            id: "sample-1",
            author: "Kevin",
            text: "This native player layout already feels much better than a web view.",
            age: "2 hours ago",
            likes: "42",
            avatarURL: nil
        ),
        VideoComment(
            id: "sample-2",
            author: "Ava",
            text: "The glass controls and related rail make this feel like a real macOS app.",
            age: "1 day ago",
            likes: "18",
            avatarURL: nil
        )
    ]
}

extension VideoItem {
    static func fromYouTubeInput(_ value: String) -> VideoItem? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate: String

        if let url = URL(string: trimmed),
           let host = url.host?.lowercased(),
           host == "youtube.com" || host.hasSuffix(".youtube.com") || host == "youtu.be" {
            if host == "youtu.be" {
                candidate = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            } else if let queryID = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "v" })?.value {
                candidate = queryID
            } else {
                let paths = url.pathComponents
                if let marker = paths.firstIndex(where: { $0 == "shorts" || $0 == "live" || $0 == "embed" }),
                   paths.indices.contains(marker + 1) {
                    candidate = paths[marker + 1]
                } else {
                    return nil
                }
            }
        } else {
            candidate = trimmed
        }

        guard candidate.count == 11,
              candidate.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil else {
            return nil
        }

        return VideoItem(
            id: candidate,
            title: "YouTube video",
            channel: "YouTube",
            views: "Loading details",
            age: "",
            duration: "",
            imageURL: URL(string: "https://i.ytimg.com/vi/\(candidate)/hqdefault.jpg"),
            verified: false
        )
    }

    static let hero = VideoItem(
        id: "hero-yosemite",
        title: "The Beauty of Yosemite",
        channel: "Featured",
        views: "Experience the wonder of nature",
        age: "in stunning 4K.",
        duration: "",
        imageURL: URL(string: "https://images.unsplash.com/photo-1472396961693-142e6e269027?auto=format&fit=crop&w=1400&q=85"),
        verified: false
    )

    static let samples: [VideoItem] = [
        VideoItem(id: "iphone", title: "iPhone 15 Pro Review: Titanium Feels Different", channel: "Marques Brownlee", views: "1.8M views", age: "1 day ago", duration: "9:13", imageURL: URL(string: "https://images.unsplash.com/photo-1695048133142-1a20484d2569?auto=format&fit=crop&w=900&q=85"), verified: true),
        VideoItem(id: "apple-park", title: "Inside Apple Park", channel: "Apple", views: "3.2M views", age: "2 weeks ago", duration: "8:47", imageURL: URL(string: "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=900&q=85"), verified: true),
        VideoItem(id: "iceland", title: "Is Iceland the Most Beautiful Place on Earth?", channel: "Kara and Nate", views: "2.1M views", age: "5 days ago", duration: "10:32", imageURL: URL(string: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=900&q=85"), verified: true),
        VideoItem(id: "cars", title: "The Future of Electric Cars", channel: "MrBeast", views: "4.3M views", age: "3 days ago", duration: "7:28", imageURL: URL(string: "https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=900&q=85"), verified: true),
        VideoItem(id: "studio", title: "The Studio Tour", channel: "Marques Brownlee", views: "812K views", age: "4 days ago", duration: "9:21", imageURL: URL(string: "https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?auto=format&fit=crop&w=900&q=85"), verified: true),
        VideoItem(id: "space", title: "What We Found Beyond Earth", channel: "Mark Rober", views: "6.4M views", age: "1 week ago", duration: "14:08", imageURL: URL(string: "https://images.unsplash.com/photo-1446776811953-b23d57bd21aa?auto=format&fit=crop&w=900&q=85"), verified: true),
        VideoItem(id: "steak", title: "Cooking With Fire", channel: "Tastemade", views: "942K views", age: "2 days ago", duration: "12:03", imageURL: URL(string: "https://images.unsplash.com/photo-1558030006-450675393462?auto=format&fit=crop&w=900&q=85"), verified: false),
        VideoItem(id: "mountains", title: "Alone in the Arctic", channel: "Kara and Nate", views: "1.1M views", age: "6 days ago", duration: "4:12", imageURL: URL(string: "https://images.unsplash.com/photo-1483728642387-6c3bdd6c93e5?auto=format&fit=crop&w=900&q=85"), verified: false)
    ]

    static var sampleFeed: HomeFeed {
        HomeFeed(
            hero: .hero,
            queue: [
                samples[7],
                VideoItem(id: "future", title: "Building the Future", channel: "Mark Rober", views: "", age: "", duration: "15:48", imageURL: URL(string: "https://images.unsplash.com/photo-1518709268805-4e9042af2176?auto=format&fit=crop&w=700&q=85"), verified: false),
                samples[4],
                samples[6]
            ],
            forYou: Array(samples.prefix(4)),
            trending: Array(samples.dropFirst(4)),
            more: []
        )
    }

    static var loadingFeed: HomeFeed {
        HomeFeed(hero: .hero, queue: [], forYou: [], trending: [], more: [])
    }
}
