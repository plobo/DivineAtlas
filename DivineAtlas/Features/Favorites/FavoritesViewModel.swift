import Foundation
import Observation

@MainActor
@Observable
final class FavoritesViewModel {
    /// All entities, used to resolve saved IDs.
    private(set) var state: LoadState<[DivineEntity]> = .idle
    let library: UserLibrary

    private var entitiesByID: [String: DivineEntity] = [:]
    private let repository: any ContentRepository

    init(repository: any ContentRepository, library: UserLibrary) {
        self.repository = repository
        self.library = library
    }

    /// Favourites present in the dataset, newest first.
    var favorites: [DivineEntity] {
        library.favoriteIDs.compactMap { entitiesByID[$0] }
    }

    /// Saved IDs whose entries have since been removed from the dataset.
    var unavailableIDs: [String] {
        guard state.isLoaded else { return [] }
        return library.favoriteIDs.filter { entitiesByID[$0] == nil }
    }

    func remove(_ entity: DivineEntity) {
        library.removeFavorites([entity.id])
    }

    func removeUnavailable() {
        library.removeFavorites(unavailableIDs)
    }

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await load()
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        do {
            let entities = try await repository.entities()
            entitiesByID = Dictionary(entities.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            state = .loaded(entities)
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(message: UserFacingError.message(for: error, context: "Loading favorites"))
        }
    }
}
