import Foundation

/// The subset of the YouTube Data API v3 `search.list` response the app uses.
struct YouTubeSearchResponse: Decodable {
    struct Item: Decodable {
        struct ID: Decodable {
            let videoId: String?
        }

        struct Snippet: Decodable {
            struct Thumbnails: Decodable {
                struct Thumbnail: Decodable {
                    let url: URL
                }

                let medium: Thumbnail?
                let high: Thumbnail?
                let `default`: Thumbnail?
            }

            let title: String
            let channelTitle: String
            let publishedAt: Date?
            let thumbnails: Thumbnails?
        }

        let id: ID
        let snippet: Snippet
    }

    let items: [Item]
}

/// The API's error envelope, e.g. `{"error": {"code": 403, "errors": [{"reason": "quotaExceeded"}]}}`.
struct YouTubeErrorResponse: Decodable {
    struct Body: Decodable {
        struct Detail: Decodable {
            let reason: String?
        }

        let code: Int?
        let message: String?
        let errors: [Detail]?
    }

    let error: Body
}

enum YouTubeSearchMapper {
    static func results(from response: YouTubeSearchResponse) -> [VideoSearchResult] {
        response.items.compactMap { item in
            // search.list with type=video should only return videos; skip anything else.
            guard let videoID = item.id.videoId, !videoID.isEmpty else { return nil }
            let thumbnails = item.snippet.thumbnails
            return VideoSearchResult(
                videoID: videoID,
                title: HTMLEntities.decode(item.snippet.title),
                channelTitle: HTMLEntities.decode(item.snippet.channelTitle),
                publishedAt: item.snippet.publishedAt,
                thumbnailURL: thumbnails?.medium?.url ?? thumbnails?.high?.url ?? thumbnails?.default?.url
            )
        }
    }

    static func error(statusCode: Int, body: Data) -> VideoSearchError {
        let reasons = (try? JSONDecoder().decode(YouTubeErrorResponse.self, from: body))?.error.errors?.compactMap(\.reason) ?? []
        if reasons.contains(where: { ["quotaExceeded", "dailyLimitExceeded", "rateLimitExceeded"].contains($0) }) {
            return .quotaExceeded
        }
        if let reason = reasons.first {
            return .rejected(reason: reason)
        }
        return .rejected(reason: "HTTP \(statusCode)")
    }
}

/// Decodes the HTML entities the YouTube API leaves in titles (`&#39;`, `&amp;`, `&quot;`, …)
/// without the cost of an HTML parser.
enum HTMLEntities {
    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
    ]

    static func decode(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        var remainder = Substring(text)
        while let ampersand = remainder.firstIndex(of: "&") {
            result += remainder[..<ampersand]
            let afterAmpersand = remainder.index(after: ampersand)
            guard let semicolon = remainder[afterAmpersand...].prefix(10).firstIndex(of: ";") else {
                result += "&"
                remainder = remainder[afterAmpersand...]
                continue
            }
            let entity = String(remainder[afterAmpersand..<semicolon])
            if let decoded = decodeEntity(entity) {
                result += decoded
            } else {
                result += remainder[ampersand...semicolon]
            }
            remainder = remainder[remainder.index(after: semicolon)...]
        }
        return result + remainder
    }

    private static func decodeEntity(_ entity: String) -> String? {
        if let value = named[entity] { return value }
        guard entity.hasPrefix("#") else { return nil }
        let digits = entity.dropFirst()
        let scalar: UInt32? = digits.first.map { $0 == "x" || $0 == "X" } == true
            ? UInt32(digits.dropFirst(), radix: 16)
            : UInt32(digits)
        return scalar.flatMap(Unicode.Scalar.init).map { String(Character($0)) }
    }
}
