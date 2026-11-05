import Foundation
import Observation

/// Curated discovery content. A popularity section is intentionally absent
/// until real usage data exists.
@MainActor
@Observable
final class DiscoverViewModel {
    struct Content: Equatable, Sendable {
        let featured: [DivineEntity]
        let recentlyAdded: [DivineEntity]
        let religions: [Religion]

        var isEmpty: Bool { featured.isEmpty && recentlyAdded.isEmpty && religions.isEmpty }
    }

    static let recentlyAddedLimit = 5
    static let favoritesPreviewLimit = 3
    static let recentlyViewedLimit = 5

    private(set) var state: LoadState<Content> = .idle
    let library: UserLibrary

    private var entitiesByID: [String: DivineEntity] = [:]
    private let repository: any ContentRepository

    init(repository: any ContentRepository, library: UserLibrary) {
        self.repository = repository
        self.library = library
    }

    /// The user's favourites that still exist in the dataset, newest first.
    var favoriteEntities: [DivineEntity] {
        library.favoriteIDs.compactMap { entitiesByID[$0] }
    }

    var favoritesPreview: [DivineEntity] {
        Array(favoriteEntities.prefix(Self.favoritesPreviewLimit))
    }

    var recentlyViewedEntities: [DivineEntity] {
        Array(library.recentlyViewedIDs.compactMap { entitiesByID[$0] }.prefix(Self.recentlyViewedLimit))
    }

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await load()
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        do {
            async let entities = repository.entities()
            async let religions = repository.religions()
            let allEntities = try await entities
            entitiesByID = Dictionary(allEntities.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let featured = EntityQuery(featuredOnly: true).apply(to: allEntities)
            let recentlyAdded = EntityQuery(sortOrder: .recentlyAdded)
                .apply(to: allEntities.filter { $0.addedAt != nil })
                .prefix(Self.recentlyAddedLimit)
            state = .loaded(Content(
                featured: featured,
                recentlyAdded: Array(recentlyAdded),
                religions: try await religions.sortedByTraditionOrder()
            ))
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(message: UserFacingError.message(for: error, context: "Loading Discover"))
        }
    }
}
