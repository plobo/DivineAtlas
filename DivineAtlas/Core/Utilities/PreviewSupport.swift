import Foundation

/// Containers for SwiftUI previews, covering each screen state.
@MainActor
enum PreviewSupport {
    static let container = make(SeedContentRepository(loader: .bundled()))
    static let emptyContainer = make(StaticContentRepository(.success(.empty)))
    static let failingContainer = make(StaticContentRepository(.failure(SeedDataError.missingFile("entities.json"))))
    static let loadingContainer = make(StaticContentRepository(.success(.empty), delay: .seconds(3600)))

    /// Previews use in-memory user data and never touch the network.
    private static func make(_ repository: any ContentRepository) -> DependencyContainer {
        DependencyContainer(contentRepository: repository, userLibrary: .inMemory())
    }
}
