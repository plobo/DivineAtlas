import Foundation

/// Read access to encyclopedia content.
///
/// The MVP implementation reads bundled seed JSON (`SeedContentRepository`);
/// a remote or cached implementation can be substituted without touching
/// view models.
protocol ContentRepository: Sendable {
    func religions() async throws -> [Religion]
    func entities() async throws -> [DivineEntity]
    func sources() async throws -> [SourceReference]
}

extension ContentRepository {
    func entity(id: String) async throws -> DivineEntity? {
        try await entities().first { $0.id == id }
    }
}
