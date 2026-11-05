import Foundation

/// The transport seam; `URLSessionTransport` in production, a stub in tests.
protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

struct URLSessionTransport: HTTPTransport {
    let session: URLSession

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }

    /// A session that does not use URLCache; caching is handled by the app's
    /// own bounded caches.
    static func makeDefault() -> URLSessionTransport {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 20
        return URLSessionTransport(session: URLSession(configuration: configuration))
    }
}

enum NetworkError: Error, Equatable {
    case insecureURL(URL)
    case offline
    case invalidResponse
    case httpStatus(Int)
    case payloadTooLarge(bytes: Int)
    case transport(code: Int)
}

/// Minimal HTTPS GET client with status validation and clear error mapping.
/// Cancellation surfaces as `CancellationError`.
struct HTTPClient: Sendable {
    static let defaultMaxResponseBytes = 15 * 1024 * 1024

    /// Identifies the app to servers, as Wikimedia's User-Agent policy requires.
    /// TODO(Milestone 6): replace the placeholder with the published support URL or email.
    static let userAgent: String = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        return "DivineAtlas/\(version) (iOS; contact: support address pending)"
    }()

    let transport: any HTTPTransport
    var maxResponseBytes = HTTPClient.defaultMaxResponseBytes
    /// Sent with every request; per-request headers take precedence.
    var defaultHeaders = ["User-Agent": HTTPClient.userAgent]

    func get(_ url: URL, headers: [String: String] = [:]) async throws -> Data {
        let (data, response) = try await response(for: url, headers: headers)
        guard (200..<300).contains(response.statusCode) else { throw NetworkError.httpStatus(response.statusCode) }
        return data
    }

    /// Like `get`, but returns the body and response for any HTTP status, for
    /// APIs that describe errors in the response body.
    func response(for url: URL, headers: [String: String] = [:]) async throws -> (Data, HTTPURLResponse) {
        guard url.scheme?.lowercased() == "https", url.host() != nil else {
            throw NetworkError.insecureURL(url)
        }
        try Task.checkCancellation()

        var request = URLRequest(url: url)
        for (field, value) in defaultHeaders.merging(headers, uniquingKeysWith: { _, override in override }) {
            request.setValue(value, forHTTPHeaderField: field)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch let error as URLError {
            throw Self.map(error)
        }
        try Task.checkCancellation()

        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard data.count <= maxResponseBytes else { throw NetworkError.payloadTooLarge(bytes: data.count) }
        return (data, http)
    }

    private static func map(_ error: URLError) -> any Error {
        switch error.code {
        case .cancelled:
            CancellationError()
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            NetworkError.offline
        default:
            NetworkError.transport(code: error.code.rawValue)
        }
    }
}
