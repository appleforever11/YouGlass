import Foundation
import ImageIO

/// Shares both download and eager decoding across image consumers. Actor-owned
/// decoding keeps image decompression out of SwiftUI's main-thread render pass.
actor YouGlassImageLoader {
    static let shared = YouGlassImageLoader()
    typealias Fetch = @Sendable (URL) async throws -> Data

    private let fetch: Fetch
    private let maximumPixelSize: Int
    private let cache = NSCache<NSString, CGImage>()
    private var inFlight: [String: Task<CGImage, Error>] = [:]

    init(maximumPixelSize: Int = 800, fetch: @escaping Fetch = YouGlassImageLoader.download) {
        self.maximumPixelSize = max(1, maximumPixelSize)
        self.fetch = fetch
        cache.countLimit = 120
        cache.totalCostLimit = 32 * 1024 * 1024
    }

    func image(for url: URL, maximumPixelSize requestedSize: Int? = nil) async throws -> CGImage {
        let maximumPixelSize = max(1, min(1_600, requestedSize ?? self.maximumPixelSize))
        let key = "\(maximumPixelSize):\(url.absoluteString)"
        if let cached = cache.object(forKey: key as NSString) { return cached }
        if let existing = inFlight[key] { return try await existing.value }

        let fetch = self.fetch
        let task = Task {
            let data = try await fetch(url)
            return try Self.decode(data, maximumPixelSize: maximumPixelSize)
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        let image = try await task.value
        cache.setObject(image, forKey: key as NSString, cost: image.bytesPerRow * image.height)
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
