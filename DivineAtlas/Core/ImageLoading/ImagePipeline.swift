import ImageIO
import SwiftUI
import UIKit

protocol ImageLoading: Sendable {
    /// Loads an image decoded to at most `maxPixelSize` on its longest side.
    func image(for url: URL, maxPixelSize: Int) async throws -> UIImage
}

extension ImageLoading {
    func image(for url: URL) async throws -> UIImage {
        try await image(for: url, maxPixelSize: ImagePipeline.defaultMaxPixelSize)
    }
}

enum ImageLoadingError: Error, Equatable {
    case undecodableData
    case unavailable
}

/// Loads remote images with a bounded in-memory cache, a bounded disk cache
/// (which also serves images offline), request de-duplication, and
/// downsampling to the size being displayed.
///
/// Decoded images are cached per size bucket, so a 72 pt thumbnail does not
/// hold a full-resolution bitmap in memory. The disk cache stores the original
/// bytes once per URL and serves every size.
actor ImagePipeline: ImageLoading {
    static let defaultMaxPixelSize = 1600
    /// Requested sizes are rounded up to one of these to limit cache variants.
    static let sizeBuckets = [128, 256, 512, 1024, 1600]

    private let client: HTTPClient
    private let diskCache: DiskCache?
    private let maxPixelSize: Int
    private let memoryCache = NSCache<NSString, UIImage>()
    private var inFlight: [String: Task<UIImage, any Error>] = [:]

    /// - Parameter maxPixelSize: Upper bound on any decoded image, whatever size is requested.
    init(client: HTTPClient, diskCache: DiskCache?, memoryLimitBytes: Int = 64 * 1024 * 1024, maxPixelSize: Int = ImagePipeline.defaultMaxPixelSize) {
        self.client = client
        self.diskCache = diskCache
        self.maxPixelSize = maxPixelSize
        memoryCache.totalCostLimit = memoryLimitBytes
    }

    static func live() -> ImagePipeline {
        ImagePipeline(
            client: HTTPClient(transport: URLSessionTransport.makeDefault()),
            diskCache: .inCachesDirectory(named: "ImageCache", maxBytes: 150 * 1024 * 1024)
        )
    }

    func image(for url: URL, maxPixelSize requested: Int) async throws -> UIImage {
        let pixelSize = min(Self.bucket(for: requested), maxPixelSize)
        let key = "\(url.absoluteString)#\(pixelSize)"
        if let cached = memoryCache.object(forKey: key as NSString) { return cached }
        if let existing = inFlight[key] { return try await existing.value }

        let task = Task { try await load(url, pixelSize: pixelSize) }
        inFlight[key] = task
        defer { inFlight[key] = nil }

        let image = try await task.value
        memoryCache.setObject(image, forKey: key as NSString, cost: Self.memoryCost(of: image))
        return image
    }

    static func bucket(for requested: Int) -> Int {
        sizeBuckets.first { $0 >= requested } ?? sizeBuckets.last ?? requested
    }

    private func load(_ url: URL, pixelSize: Int) async throws -> UIImage {
        let diskKey = url.absoluteString
        if let data = diskCache?.data(forKey: diskKey), let image = decode(data, maxPixelSize: pixelSize) {
            return image
        }
        let data = try await client.get(url)
        guard let image = decode(data, maxPixelSize: pixelSize) else { throw ImageLoadingError.undecodableData }
        try? diskCache?.store(data, forKey: diskKey)
        return image
    }

    private func decode(_ data: Data, maxPixelSize: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private static func memoryCost(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }
}

/// Default environment value: never loads, so artwork shows its placeholder
/// unless a real loader is injected by the composition root.
struct UnavailableImageLoader: ImageLoading {
    func image(for url: URL, maxPixelSize: Int) async throws -> UIImage {
        throw ImageLoadingError.unavailable
    }
}

private struct ImageLoaderKey: EnvironmentKey {
    static let defaultValue: any ImageLoading = UnavailableImageLoader()
}

extension EnvironmentValues {
    var imageLoader: any ImageLoading {
        get { self[ImageLoaderKey.self] }
        set { self[ImageLoaderKey.self] = newValue }
    }
}
