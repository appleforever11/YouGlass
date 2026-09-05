import Foundation
import ImageIO

/// Shares both download and eager decoding across image consumers. Actor-owned
/// decoding keeps image decompression out of SwiftUI's main-thread render pass.
actor YouGlassImageLoader {
    static let shared = YouGlassImageLoader()
    typealias Fetch = @Sendable (URL) async throws -> Data

    private let fetch: Fetch
    private let maximumPixelSize: Int
    private let cache = NSCache<NSURL, CGImage>()
    private var inFlight: [URL: Task<CGImage, Error>] = [:]

    init(maximumPixelSize: Int = 1_600, fetch: @escaping Fetch = YouGlassImageLoader.download) {
        self.maximumPixelSize = max(1, maximumPixelSize)
        self.fetch = fetch
        cache.countLimit = 180
        cache.totalCostLimit = 80 * 1024 * 1024
    }

    func image(for url: URL) async throws -> CGImage {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        if let existing = inFlight[url] { return try await existing.value }

        let fetch = self.fetch
        let maximumPixelSize = self.maximumPixelSize
        let task = Task {
            let data = try await fetch(url)
            return try Self.decode(data, maximumPixelSize: maximumPixelSize)
        }
        inFlight[url] = task
        defer { inFlight[url] = nil }
        let image = try await task.value
        cache.setObject(image, forKey: url as NSURL, cost: image.bytesPerRow * image.height)
        return image
    }

    private static func decode(_ data: Data, maximumPixelSize: Int) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else {
            throw URLError(.cannotDecodeContentData)
        }
        return image
    }

    static func download(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 12)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Apple Silicon Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse,
              200..<300 ~= response.statusCode else { throw URLError(.badServerResponse) }
        return data
    }
}
