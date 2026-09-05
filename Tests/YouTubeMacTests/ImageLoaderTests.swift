import CoreGraphics
import ImageIO
import XCTest
@testable import YouTubeMac

final class ImageLoaderTests: XCTestCase {
    private let url = URL(string: "https://example.invalid/thumbnail.png")!

    func testConcurrentConsumersShareDecodeAndCache() async throws {
        let url = self.url
        let source = try png()
        let counter = FetchCounter(data: source)
        let loader = YouGlassImageLoader(fetch: { _ in await counter.fetch() })
        async let first = loader.image(for: url)
        async let second = loader.image(for: url)
        let (one, two) = try await (first, second)
        let cached = try await loader.image(for: url)
        XCTAssertTrue(one === two)
        XCTAssertTrue(one === cached)
        let count = await counter.count
        XCTAssertEqual(count, 1)
    }

    func testDownsamplingPreservesAspectRatio() async throws {
        let source = try png()
        let loader = YouGlassImageLoader(maximumPixelSize: 40, fetch: { _ in source })
        let image = try await loader.image(for: url)
        XCTAssertEqual(image.width, 40)
        XCTAssertEqual(image.height, 20)
    }

    func testDecodeFailureCanRetry() async throws {
        let counter = FetchCounter(data: Data())
        let loader = YouGlassImageLoader(fetch: { _ in await counter.fetch() })
        for _ in 0..<2 {
            do {
                _ = try await loader.image(for: url)
                XCTFail("Invalid images must not be cached")
            } catch {
                XCTAssertEqual((error as? URLError)?.code, .cannotDecodeContentData)
            }
        }
        let count = await counter.count
        XCTAssertEqual(count, 2)
    }

    private func png() throws -> Data {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 200, height: 100, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let image = try XCTUnwrap(context.makeImage())
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(
            data, "public.png" as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}

private actor FetchCounter {
    private(set) var count = 0
    let data: Data
    init(data: Data) { self.data = data }
    func fetch() async -> Data {
        count += 1
        await Task.yield()
        return data
    }
}
