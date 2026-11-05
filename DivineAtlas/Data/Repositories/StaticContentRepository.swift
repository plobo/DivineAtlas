import Foundation

/// Serves fixed in-memory content, or a fixed error, optionally after a delay.
/// Used for SwiftUI previews and deterministic UI-test scenarios.
struct StaticContentRepository: ContentRepository {
    private let result: Result<SeedContent, any Error>
    private let delay: Duration?

    init(_ result: Result<SeedContent, any Error>, delay: Duration? = nil) {
        self.result = result
        self.delay = delay
    }

    func religions() async throws -> [Religion] { try await content().religions }
    func entities() async throws -> [DivineEntity] { try await content().entities }
    func sources() async throws -> [SourceReference] { try await content().sources }

    private func content() async throws -> SeedContent {
        if let delay { try await Task.sleep(for: delay) }
        return try result.get()
    }
}
