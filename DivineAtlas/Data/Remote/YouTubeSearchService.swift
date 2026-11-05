import Foundation

/// Searches YouTube (Data API v3 `search.list`) with an on-device cache.
///
/// - Each search costs 100 quota units (about 100 searches a day on the free
///   tier), so results are cached per query for `cacheLifetime` (24 h, well
///   within the API policy's 30-day limit on stored API data).
/// - When the network fails or the quota is exhausted, an expired cached
///   result is served instead of an error.
/// - `safeSearch=strict` and a topic-specific query keep results relevant;
///   results are still unreviewed and labelled as such in the UI.
actor YouTubeSearchService: VideoSearchService {
    static let cacheLifetime: TimeInterval = 24 * 60 * 60
    /// Never serve stored API data older than this (YouTube API Services policy).
    static let maxStaleAge: TimeInterval = 30 * 24 * 60 * 60
    static let maxResults = 10

    private struct CacheEntry: Codable {
        let fetchedAt: Date
        let results: [VideoSearchResult]
    }

    private let apiKey: String
    private let bundleIdentifier: String
    private let client: HTTPClient
    private let cache: DiskCache?
    private let now: @Sendable () -> Date

    init(
        apiKey: String,
        bundleIdentifier: String,
        client: HTTPClient,
        cache: DiskCache?,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.apiKey = apiKey
        self.bundleIdentifier = bundleIdentifier
        self.client = client
        self.cache = cache
        self.now = now
    }

    /// Reads the key from Info.plist (`YouTubeAPIKey`, set from Config/Secrets.xcconfig).
    /// Returns nil when no key is configured.
    static func live(bundle: Bundle = .main) -> YouTubeSearchService? {
        guard let key = bundle.object(forInfoDictionaryKey: "YouTubeAPIKey") as? String,
              !key.isEmpty, !key.hasPrefix("$(") else { return nil }
        return YouTubeSearchService(
            apiKey: key,
            bundleIdentifier: bundle.bundleIdentifier ?? "",
            client: HTTPClient(transport: URLSessionTransport.makeDefault()),
            cache: .inCachesDirectory(named: "VideoSearchCache", maxBytes: 5 * 1024 * 1024)
        )
    }

    func videos(for query: VideoSearchQuery) async throws -> [VideoSearchResult] {
        let cached = cachedEntry(for: query).flatMap { entry in
            now().timeIntervalSince(entry.fetchedAt) < Self.maxStaleAge ? entry : nil
        }
        if let cached, now().timeIntervalSince(cached.fetchedAt) < Self.cacheLifetime {
            return cached.results
        }
        do {
            let results = try await fetch(query)
            store(CacheEntry(fetchedAt: now(), results: results), for: query)
            return results
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as VideoSearchError where error == .quotaExceeded || error == .offline || error == .unavailable {
            // Stale results beat no results when the failure is temporary.
            if let cached { return cached.results }
            throw error
        }
    }

    nonisolated func requestURL(for query: VideoSearchQuery) -> URL {
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "maxResults", value: String(Self.maxResults)),
            URLQueryItem(name: "safeSearch", value: "strict"),
            URLQueryItem(name: "relevanceLanguage", value: "en"),
            URLQueryItem(name: "q", value: query.text),
            URLQueryItem(name: "key", value: apiKey),
        ]
        return components.url!
    }

    private func fetch(_ query: VideoSearchQuery) async throws -> [VideoSearchResult] {
        let data: Data
        let response: HTTPURLResponse
        do {
            // The bundle ID header lets Google enforce an iOS-app key restriction.
            (data, response) = try await client.response(
                for: requestURL(for: query),
                headers: ["X-Ios-Bundle-Identifier": bundleIdentifier]
            )
        } catch NetworkError.offline {
            throw VideoSearchError.offline
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw VideoSearchError.unavailable
        }
        guard (200..<300).contains(response.statusCode) else {
            throw YouTubeSearchMapper.error(statusCode: response.statusCode, body: data)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode(YouTubeSearchResponse.self, from: data) else {
            throw VideoSearchError.unavailable
        }
        return YouTubeSearchMapper.results(from: decoded)
    }

    private func cacheKey(for query: VideoSearchQuery) -> String {
        "youtube-search-v1:\(query.text.lowercased())"
    }

    private func cachedEntry(for query: VideoSearchQuery) -> CacheEntry? {
        guard let data = cache?.data(forKey: cacheKey(for: query)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CacheEntry.self, from: data)
    }

    private func store(_ entry: CacheEntry, for query: VideoSearchQuery) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entry) else { return }
        try? cache?.store(data, forKey: cacheKey(for: query))
    }
}
