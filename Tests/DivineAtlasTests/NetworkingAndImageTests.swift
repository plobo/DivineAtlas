import UIKit
import XCTest
@testable import DivineAtlas

/// Transport double returning a fixed result and counting requests.
private final class StubTransport: HTTPTransport, @unchecked Sendable {
    // Mutated only from test code before/after awaits; guarded by a lock.
    private let lock = NSLock()
    private var _requestCount = 0
    private let result: @Sendable (URLRequest) throws -> (Data, URLResponse)

    init(_ result: @escaping @Sendable (URLRequest) throws -> (Data, URLResponse)) {
        self.result = result
    }

    var requestCount: Int { lock.withLock { _requestCount } }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lock.withLock { _requestCount += 1 }
        // Yield so concurrent callers overlap, exercising de-duplication.
        try await Task.sleep(for: .milliseconds(20))
        return try result(request)
    }

    static func respond(status: Int = 200, data: Data) -> StubTransport {
        StubTransport { request in
            (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
    }

    static func fail(_ code: URLError.Code) -> StubTransport {
        StubTransport { _ in throw URLError(code) }
    }
}

private let imageURL = URL(string: "https://example.com/art.png")!

/// PNG with exactly `width` × `height` pixels (scale 1, not the screen scale).
private func pngData(width: Int = 40, height: Int = 20) -> Data {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
        UIColor.orange.setFill()
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }.pngData()!
}

private func temporaryCache(maxBytes: Int = 10_000_000) -> DiskCache {
    DiskCache(directory: FileManager.default.temporaryDirectory.appending(path: "DiskCacheTests-\(UUID().uuidString)"), maxBytes: maxBytes)
}

final class HTTPClientTests: XCTestCase {
    func testReturnsDataForSuccessfulResponse() async throws {
        let data = try await HTTPClient(transport: StubTransport.respond(data: Data("ok".utf8))).get(imageURL)
        XCTAssertEqual(data, Data("ok".utf8))
    }

    func testSendsUserAgentAndCustomHeaders() async throws {
        let transport = StubTransport { request in
            let ok = request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("DivineAtlas/") == true
                && request.value(forHTTPHeaderField: "X-Test") == "1"
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: ok ? 200 : 400, httpVersion: nil, headerFields: nil)!)
        }
        _ = try await HTTPClient(transport: transport).get(imageURL, headers: ["X-Test": "1"])
    }

    func testPerRequestHeadersOverrideDefaults() async throws {
        let transport = StubTransport { request in
            let ok = request.value(forHTTPHeaderField: "User-Agent") == "Custom"
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: ok ? 200 : 400, httpVersion: nil, headerFields: nil)!)
        }
        _ = try await HTTPClient(transport: transport).get(imageURL, headers: ["User-Agent": "Custom"])
    }

    func testRejectsNonHTTPSURLsWithoutRequesting() async {
        let transport = StubTransport.respond(data: Data())
        let url = URL(string: "http://example.com/a.png")!
        await assertThrows(NetworkError.insecureURL(url)) { try await HTTPClient(transport: transport).get(url) }
        XCTAssertEqual(transport.requestCount, 0)
    }

    func testMapsHTTPStatusErrors() async {
        await assertThrows(NetworkError.httpStatus(404)) {
            try await HTTPClient(transport: StubTransport.respond(status: 404, data: Data())).get(imageURL)
        }
    }

    func testMapsOfflineAndTransportErrors() async {
        await assertThrows(NetworkError.offline) {
            try await HTTPClient(transport: StubTransport.fail(.notConnectedToInternet)).get(imageURL)
        }
        await assertThrows(NetworkError.transport(code: URLError.Code.timedOut.rawValue)) {
            try await HTTPClient(transport: StubTransport.fail(.timedOut)).get(imageURL)
        }
    }

    func testRejectsOversizedPayloads() async {
        var client = HTTPClient(transport: StubTransport.respond(data: Data(count: 11)))
        client.maxResponseBytes = 10
        await assertThrows(NetworkError.payloadTooLarge(bytes: 11)) { try await client.get(imageURL) }
    }

    func testCancellationSurfacesAsCancellationError() async {
        let task = Task { try await HTTPClient(transport: StubTransport.respond(data: Data())).get(imageURL) }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError, "\(error)")
        }
    }

    private func assertThrows(_ expected: NetworkError, _ body: () async throws -> Data, line: UInt = #line) async {
        do {
            _ = try await body()
            XCTFail("Expected \(expected)", line: line)
        } catch {
            XCTAssertEqual(error as? NetworkError, expected, line: line)
        }
    }
}

final class DiskCacheTests: XCTestCase {
    func testStoresAndRetrievesData() throws {
        let cache = temporaryCache()
        try cache.store(Data("hello".utf8), forKey: "k")
        XCTAssertEqual(cache.data(forKey: "k"), Data("hello".utf8))
        XCTAssertNil(cache.data(forKey: "other"))
        cache.removeAll()
        XCTAssertNil(cache.data(forKey: "k"))
    }

    func testEvictsLeastRecentlyUsedBeyondLimit() throws {
        let cache = temporaryCache(maxBytes: 250)
        // Distinct contents so each file can be identified.
        try cache.store(Data(repeating: 1, count: 100), forKey: "a")
        try cache.store(Data(repeating: 2, count: 100), forKey: "b")
        // Explicit dates: "b" is least recently used, "a" most recently.
        try setModificationDate(Date().addingTimeInterval(-60), cache: cache, key: "b")
        try setModificationDate(Date().addingTimeInterval(60), cache: cache, key: "a")

        try cache.store(Data(repeating: 3, count: 100), forKey: "c")

        XCTAssertNotNil(cache.data(forKey: "a"))
        XCTAssertNil(cache.data(forKey: "b"), "Least recently used entry should be evicted")
        XCTAssertNotNil(cache.data(forKey: "c"))
        XCTAssertLessThanOrEqual(cache.totalBytes, 250)
    }

    func testIgnoresItemsLargerThanTheCache() throws {
        let cache = temporaryCache(maxBytes: 10)
        try cache.store(Data(count: 11), forKey: "big")
        XCTAssertNil(cache.data(forKey: "big"))
    }

    private func setModificationDate(_ date: Date, cache: DiskCache, key: String) throws {
        let files = try FileManager.default.contentsOfDirectory(at: cache.directory, includingPropertiesForKeys: nil)
        let data = try XCTUnwrap(cache.data(forKey: key))
        for file in files where (try? Data(contentsOf: file)) == data {
            try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: file.path())
        }
    }
}

final class ImagePipelineTests: XCTestCase {
    func testLoadsDecodesAndCachesInMemory() async throws {
        let transport = StubTransport.respond(data: pngData())
        let pipeline = ImagePipeline(client: HTTPClient(transport: transport), diskCache: nil)

        let first = try await pipeline.image(for: imageURL)
        _ = try await pipeline.image(for: imageURL)

        XCTAssertEqual(first.size, CGSize(width: 40, height: 20))
        XCTAssertEqual(transport.requestCount, 1)
    }

    func testDownsamplesLargeImages() async throws {
        let pipeline = ImagePipeline(
            client: HTTPClient(transport: StubTransport.respond(data: pngData(width: 400, height: 200))),
            diskCache: nil,
            maxPixelSize: 100
        )
        let image = try await pipeline.image(for: imageURL)
        XCTAssertEqual(max(image.size.width, image.size.height), 100)
    }

    func testConcurrentRequestsAreDeduplicated() async throws {
        let transport = StubTransport.respond(data: pngData())
        let pipeline = ImagePipeline(client: HTTPClient(transport: transport), diskCache: nil)

        async let a = pipeline.image(for: imageURL)
        async let b = pipeline.image(for: imageURL)
        _ = try await (a, b)

        XCTAssertEqual(transport.requestCount, 1)
    }

    func testServesFromDiskCacheWhenOffline() async throws {
        let cache = temporaryCache()
        let online = ImagePipeline(client: HTTPClient(transport: StubTransport.respond(data: pngData())), diskCache: cache)
        _ = try await online.image(for: imageURL)

        // A fresh pipeline (empty memory cache) with no network still succeeds.
        let offlineTransport = StubTransport.fail(.notConnectedToInternet)
        let offline = ImagePipeline(client: HTTPClient(transport: offlineTransport), diskCache: cache)
        let image = try await offline.image(for: imageURL)

        XCTAssertEqual(image.size, CGSize(width: 40, height: 20))
        XCTAssertEqual(offlineTransport.requestCount, 0)
    }

    func testOfflineWithoutCacheFails() async {
        let pipeline = ImagePipeline(client: HTTPClient(transport: StubTransport.fail(.notConnectedToInternet)), diskCache: temporaryCache())
        do {
            _ = try await pipeline.image(for: imageURL)
            XCTFail("Expected failure")
        } catch {
            XCTAssertEqual(error as? NetworkError, .offline)
        }
    }

    func testUndecodableDataFailsAndIsNotCached() async {
        let cache = temporaryCache()
        let pipeline = ImagePipeline(client: HTTPClient(transport: StubTransport.respond(data: Data("not an image".utf8))), diskCache: cache)
        do {
            _ = try await pipeline.image(for: imageURL)
            XCTFail("Expected failure")
        } catch {
            XCTAssertEqual(error as? ImageLoadingError, .undecodableData)
        }
        XCTAssertNil(cache.data(forKey: imageURL.absoluteString))
    }

    func testDecodesPerSizeBucketFromOneDownload() async throws {
        let transport = StubTransport.respond(data: pngData(width: 400, height: 200))
        let pipeline = ImagePipeline(client: HTTPClient(transport: transport), diskCache: temporaryCache())

        let thumbnail = try await pipeline.image(for: imageURL, maxPixelSize: 100)
        let hero = try await pipeline.image(for: imageURL, maxPixelSize: 1600)

        XCTAssertEqual(thumbnail.size.width, 128, "100 px rounds up to the 128 px bucket")
        XCTAssertEqual(hero.size.width, 400, "Images are never upscaled")
        XCTAssertEqual(transport.requestCount, 1, "The second size is decoded from the disk cache")
    }

    func testSizeBuckets() {
        XCTAssertEqual(ImagePipeline.bucket(for: 1), 128)
        XCTAssertEqual(ImagePipeline.bucket(for: 216), 256)
        XCTAssertEqual(ImagePipeline.bucket(for: 1024), 1024)
        XCTAssertEqual(ImagePipeline.bucket(for: 5000), 1600)
    }
}
