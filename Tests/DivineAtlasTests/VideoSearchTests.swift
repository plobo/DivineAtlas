import XCTest
@testable import DivineAtlas

/// Thread-safe transport double that records requests. Never touches the network.
private final class RecordingTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [URLRequest] = []
    private let respond: @Sendable (URLRequest) throws -> (Data, Int)

    init(_ respond: @escaping @Sendable (URLRequest) throws -> (Data, Int)) {
        self.respond = respond
    }

    var requests: [URLRequest] { lock.withLock { _requests } }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lock.withLock { _requests.append(request) }
        let (data, status) = try respond(request)
        return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

/// Mutable clock shared with the service under test.
private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var _now = Date(timeIntervalSince1970: 1_000_000)
    var now: Date { lock.withLock { _now } }
    func advance(by interval: TimeInterval) { lock.withLock { _now += interval } }
}

private let searchFixture = Data("""
{
  "items": [
    { "id": { "kind": "youtube#video", "videoId": "abc123" },
      "snippet": { "title": "Who is Vishnu? &#39;Preserver&#39; &amp; protector", "channelTitle": "Ancient &quot;Texts&quot;",
                   "publishedAt": "2023-05-01T12:00:00Z",
                   "thumbnails": { "default": { "url": "https://i.ytimg.com/vi/abc123/default.jpg" },
                                   "medium": { "url": "https://i.ytimg.com/vi/abc123/mqdefault.jpg" } } } },
    { "id": { "kind": "youtube#channel", "channelId": "UCxyz" },
      "snippet": { "title": "A channel", "channelTitle": "A channel", "publishedAt": "2023-05-01T12:00:00Z" } },
    { "id": { "kind": "youtube#video", "videoId": "def456" },
      "snippet": { "title": "Vishnu in the Rigveda", "channelTitle": "Lectures", "publishedAt": "2022-01-01T00:00:00Z" } }
  ]
}
""".utf8)

private func errorBody(_ reason: String, code: Int) -> Data {
    Data(#"{"error":{"code":\#(code),"message":"m","errors":[{"reason":"\#(reason)"}]}}"#.utf8)
}

private func temporaryCache() -> DiskCache {
    DiskCache(directory: FileManager.default.temporaryDirectory.appending(path: "VideoSearchTests-\(UUID().uuidString)"), maxBytes: 1_000_000)
}

final class VideoSearchQueryTests: XCTestCase {
    func testQueryUsesTraditionsForOneOrTwoTraditions() {
        let single = TestFixtures.entity("vishnu", name: "Vishnu", classifications: [TestFixtures.classification(.hinduism, .god, .divineAndCelestial)])
        XCTAssertEqual(VideoSearchQuery(entity: single).text, "Vishnu Hinduism")
        XCTAssertEqual(VideoSearchQuery(entity: TestFixtures.beta).text, "Beta Judaism Christianity")
    }

    func testQueryUsesFirstMeaningfulCategoryForThreeOrMoreTraditions() {
        let entity = TestFixtures.entity("abraham", name: "Abraham", classifications: [
            TestFixtures.classification(.judaism, .other, .other),
            TestFixtures.classification(.christianity, .other, .other),
            TestFixtures.classification(.islam, .prophet, .other),
        ])
        XCTAssertEqual(VideoSearchQuery(entity: entity).text, "Abraham Prophet")
    }

    func testFallbackAndWatchURLsAreEncoded() {
        let query = VideoSearchQuery(text: "Mikha'el & Gabriel")
        XCTAssertEqual(query.youtubeSearchURL.absoluteString, "https://www.youtube.com/results?search_query=Mikha'el%20%26%20Gabriel")
        let result = VideoSearchResult(videoID: "abc123", title: "t", channelTitle: "c", publishedAt: nil, thumbnailURL: nil)
        XCTAssertEqual(result.watchURL.absoluteString, "https://www.youtube.com/watch?v=abc123")
    }

    func testBundledEntitiesProduceNonEmptyQueries() throws {
        for entity in try SeedDataLoader.bundled(in: .main).load().entities {
            let text = VideoSearchQuery(entity: entity).text
            XCTAssertTrue(text.hasPrefix(entity.name) && text.count > entity.name.count, "\(entity.id): '\(text)'")
        }
    }
}

final class YouTubeSearchServiceTests: XCTestCase {
    private func makeService(
        _ transport: RecordingTransport,
        cache: DiskCache? = nil,
        clock: TestClock = TestClock()
    ) -> YouTubeSearchService {
        YouTubeSearchService(
            apiKey: "TEST_KEY", bundleIdentifier: "com.divineatlas.DivineAtlas",
            client: HTTPClient(transport: transport), cache: cache, now: { clock.now }
        )
    }

    func testRequestParametersAndHeaders() async throws {
        let transport = RecordingTransport { _ in (searchFixture, 200) }
        _ = try await makeService(transport).videos(for: VideoSearchQuery(text: "Vishnu Hinduism"))

        let request = try XCTUnwrap(transport.requests.first)
        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
        let params = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(request.url?.host(), "www.googleapis.com")
        XCTAssertEqual(params["q"], "Vishnu Hinduism")
        XCTAssertEqual(params["safeSearch"], "strict")
        XCTAssertEqual(params["type"], "video")
        XCTAssertEqual(params["maxResults"], "10")
        XCTAssertEqual(params["key"], "TEST_KEY")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier"), "com.divineatlas.DivineAtlas")
    }

    func testMapsResultsDecodingEntitiesAndSkippingNonVideos() async throws {
        let results = try await makeService(RecordingTransport { _ in (searchFixture, 200) })
            .videos(for: VideoSearchQuery(text: "Vishnu"))

        XCTAssertEqual(results.map(\.videoID), ["abc123", "def456"])
        XCTAssertEqual(results[0].title, "Who is Vishnu? 'Preserver' & protector")
        XCTAssertEqual(results[0].channelTitle, "Ancient \"Texts\"")
        XCTAssertEqual(results[0].thumbnailURL?.absoluteString, "https://i.ytimg.com/vi/abc123/mqdefault.jpg", "Prefers the medium thumbnail")
        XCTAssertNil(results[1].thumbnailURL)
        XCTAssertNotNil(results[0].publishedAt)
    }

    func testErrorMapping() async {
        let cases: [(Data, Int, VideoSearchError)] = [
            (errorBody("quotaExceeded", code: 403), 403, .quotaExceeded),
            (errorBody("keyInvalid", code: 400), 400, .rejected(reason: "keyInvalid")),
            (errorBody("forbidden", code: 403), 403, .rejected(reason: "forbidden")),
            (Data("not json".utf8), 500, .rejected(reason: "HTTP 500")),
            (Data("not json".utf8), 200, .unavailable),
        ]
        for (body, status, expected) in cases {
            do {
                _ = try await makeService(RecordingTransport { _ in (body, status) }).videos(for: VideoSearchQuery(text: "x"))
                XCTFail("Expected \(expected)")
            } catch {
                XCTAssertEqual(error as? VideoSearchError, expected)
            }
        }
    }

    func testOfflineMapsToOffline() async {
        do {
            _ = try await makeService(RecordingTransport { _ in throw URLError(.notConnectedToInternet) }).videos(for: VideoSearchQuery(text: "x"))
            XCTFail("Expected offline")
        } catch {
            XCTAssertEqual(error as? VideoSearchError, .offline)
        }
    }

    func testFreshCacheAvoidsNetworkAndExpiresAfter24Hours() async throws {
        let transport = RecordingTransport { _ in (searchFixture, 200) }
        let clock = TestClock()
        let service = makeService(transport, cache: temporaryCache(), clock: clock)
        let query = VideoSearchQuery(text: "Vishnu Hinduism")

        _ = try await service.videos(for: query)
        clock.advance(by: 23 * 3600)
        _ = try await service.videos(for: query)
        XCTAssertEqual(transport.requests.count, 1, "Served from cache within 24 h")

        clock.advance(by: 2 * 3600)
        _ = try await service.videos(for: query)
        XCTAssertEqual(transport.requests.count, 2, "Refetched after 24 h")
    }

    func testCacheKeyIgnoresCase() async throws {
        let transport = RecordingTransport { _ in (searchFixture, 200) }
        let service = makeService(transport, cache: temporaryCache())
        _ = try await service.videos(for: VideoSearchQuery(text: "Vishnu"))
        _ = try await service.videos(for: VideoSearchQuery(text: "vishnu"))
        XCTAssertEqual(transport.requests.count, 1)
    }

    func testStaleResultsServedOnTemporaryFailureButNotAfter30Days() async throws {
        let cache = temporaryCache()
        let clock = TestClock()
        let query = VideoSearchQuery(text: "Vishnu")
        _ = try await makeService(RecordingTransport { _ in (searchFixture, 200) }, cache: cache, clock: clock).videos(for: query)

        clock.advance(by: 2 * 24 * 3600)
        let offline = makeService(RecordingTransport { _ in throw URLError(.notConnectedToInternet) }, cache: cache, clock: clock)
        let stale = try await offline.videos(for: query)
        XCTAssertEqual(stale.count, 2, "Stale results while offline")

        let quota = makeService(RecordingTransport { _ in (errorBody("quotaExceeded", code: 403), 403) }, cache: cache, clock: clock)
        let staleOnQuota = try await quota.videos(for: query)
        XCTAssertEqual(staleOnQuota.count, 2, "Stale results when quota is exhausted")

        clock.advance(by: 31 * 24 * 3600)
        do {
            _ = try await offline.videos(for: query)
            XCTFail("Data older than 30 days must not be served")
        } catch {
            XCTAssertEqual(error as? VideoSearchError, .offline)
        }
    }

    func testRejectedKeyDoesNotServeStaleResults() async throws {
        // A configuration problem should surface rather than hide behind old data.
        let cache = temporaryCache()
        let clock = TestClock()
        let query = VideoSearchQuery(text: "Vishnu")
        _ = try await makeService(RecordingTransport { _ in (searchFixture, 200) }, cache: cache, clock: clock).videos(for: query)
        clock.advance(by: 2 * 24 * 3600)
        do {
            _ = try await makeService(RecordingTransport { _ in (errorBody("keyInvalid", code: 400), 400) }, cache: cache, clock: clock)
                .videos(for: query)
            XCTFail("Expected rejection")
        } catch {
            XCTAssertEqual(error as? VideoSearchError, .rejected(reason: "keyInvalid"))
        }
    }

    func testLiveServiceRequiresConfiguredKey() {
        // The unit-test host bundle may or may not have a key; an empty or
        // unexpanded value must never produce a service.
        let bundle = Bundle(for: Self.self)
        XCTAssertNil(YouTubeSearchService.live(bundle: bundle), "Test bundle has no YouTubeAPIKey")
    }
}

final class HTMLEntitiesTests: XCTestCase {
    func testDecodesNamedAndNumericEntities() {
        XCTAssertEqual(HTMLEntities.decode("Rock &amp; Roll &lt;3 &quot;hi&quot; &#39;x&#39; &#x2014; &apos;"), "Rock & Roll <3 \"hi\" 'x' — '")
    }

    func testLeavesUnknownOrMalformedEntitiesAlone() {
        XCTAssertEqual(HTMLEntities.decode("AT&T &bogus; & 5 &#xZZ;"), "AT&T &bogus; & 5 &#xZZ;")
        XCTAssertEqual(HTMLEntities.decode("plain"), "plain")
    }
}

@MainActor
final class EntityVideosViewModelTests: XCTestCase {
    private struct FixedService: VideoSearchService {
        let result: Result<[VideoSearchResult], VideoSearchError>
        func videos(for query: VideoSearchQuery) async throws -> [VideoSearchResult] { try result.get() }
    }

    private let video = VideoSearchResult(videoID: "v", title: "t", channelTitle: "c", publishedAt: nil, thumbnailURL: nil)

    func testLoadsResults() async {
        let viewModel = EntityVideosViewModel(entity: TestFixtures.alpha, service: FixedService(result: .success([video])))
        XCTAssertEqual(viewModel.state, .idle)

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .loaded([video]))
        XCTAssertEqual(viewModel.fallbackURL, viewModel.query.youtubeSearchURL)
    }

    func testEmptyResults() async {
        let viewModel = EntityVideosViewModel(entity: TestFixtures.alpha, service: FixedService(result: .success([])))
        await viewModel.load()
        XCTAssertEqual(viewModel.state, .loaded([]))
    }

    func testErrorsBecomeUnavailableWithMessage() async {
        for error in [VideoSearchError.notConfigured, .quotaExceeded, .offline, .rejected(reason: "keyInvalid"), .unavailable] {
            let viewModel = EntityVideosViewModel(entity: TestFixtures.alpha, service: FixedService(result: .failure(error)))
            await viewModel.load()
            XCTAssertEqual(viewModel.state, .unavailable(EntityVideosViewModel.message(for: error)), "\(error)")
        }
    }

    func testLoadIfNeededLoadsOnce() async {
        let viewModel = EntityVideosViewModel(entity: TestFixtures.alpha, service: FixedService(result: .success([video])))
        await viewModel.loadIfNeeded()
        await viewModel.loadIfNeeded()
        XCTAssertEqual(viewModel.state, .loaded([video]))
    }

    func testDetailCreatesVideosViewModelAfterLoading() async {
        let detail = EntityDetailViewModel(
            entityID: "alpha", repository: MockContentRepository(), library: .inMemory(),
            videoSearch: FixedService(result: .success([video]))
        )
        XCTAssertNil(detail.videos)
        await detail.load()
        XCTAssertEqual(detail.videos?.query.text, VideoSearchQuery(entity: TestFixtures.alpha).text)
        XCTAssertEqual(detail.videos?.state, .idle, "Videos load lazily when their section appears, not with the detail")
    }
}
