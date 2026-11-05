import Foundation

/// A video found by searching an external provider. Unlike curated
/// `VideoLink`s, these are **not reviewed** and are never stored as entity
/// content; the UI labels them accordingly.
struct VideoSearchResult: Identifiable, Codable, Hashable, Sendable {
    let videoID: String
    let title: String
    let channelTitle: String
    let publishedAt: Date?
    let thumbnailURL: URL?

    var id: String { videoID }

    /// Opens in the YouTube app when installed (universal link), otherwise Safari.
    var watchURL: URL {
        var components = URLComponents(string: "https://www.youtube.com/watch")!
        components.queryItems = [URLQueryItem(name: "v", value: videoID)]
        return components.url!
    }
}

/// The search text for an entity, chosen to keep results on topic:
/// "Vishnu Hinduism", "Satan Judaism Christianity", or, for figures in three or
/// more traditions, the name plus its category ("Gabriel Angel").
struct VideoSearchQuery: Hashable, Sendable {
    let text: String

    init(text: String) {
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(entity: DivineEntity) {
        let traditions = entity.traditionIDs
        if (1...2).contains(traditions.count) {
            self.init(text: ([entity.name] + traditions.map(\.displayName)).joined(separator: " "))
        } else if let category = entity.classifications.map(\.category).first(where: { $0 != .other }) {
            self.init(text: "\(entity.name) \(category.displayName)")
        } else {
            self.init(text: "\(entity.name) religion")
        }
    }

    /// YouTube's own results page, for the always-available fallback button.
    var youtubeSearchURL: URL {
        var components = URLComponents(string: "https://www.youtube.com/results")!
        components.queryItems = [URLQueryItem(name: "search_query", value: text)]
        return components.url!
    }
}

enum VideoSearchError: Error, Equatable {
    /// No API key is configured for this build.
    case notConfigured
    /// The daily API quota is used up.
    case quotaExceeded
    /// The provider refused the request (e.g. key invalid or restricted).
    case rejected(reason: String)
    case offline
    case unavailable
}

protocol VideoSearchService: Sendable {
    func videos(for query: VideoSearchQuery) async throws -> [VideoSearchResult]
}

/// Used when no API key is configured, and in UI tests unless videos are stubbed.
struct UnavailableVideoSearchService: VideoSearchService {
    func videos(for query: VideoSearchQuery) async throws -> [VideoSearchResult] {
        throw VideoSearchError.notConfigured
    }
}
