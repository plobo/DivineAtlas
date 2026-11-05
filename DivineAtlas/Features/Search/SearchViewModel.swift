import Foundation
import Observation

/// Global search across every entity, regardless of group or tradition.
@MainActor
@Observable
final class SearchViewModel {
    var searchText = ""
    private(set) var state: LoadState<[DivineEntity]> = .idle

    @ObservationIgnored private var searchIndex: EntitySearchIndex?
    private let repository: any ContentRepository

    init(repository: any ContentRepository) {
        self.repository = repository
    }

    var isSearching: Bool { EntityQuery(searchText: searchText).isSearching }

    var results: [DivineEntity] {
        guard isSearching else { return [] }
        return EntityQuery(searchText: searchText).apply(to: state.value ?? [], index: searchIndex)
    }

    var trimmedSearchText: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await load()
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        do {
            let entities = try await repository.entities()
            searchIndex = await EntitySearchIndex.build(entities)
            state = .loaded(entities)
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(message: UserFacingError.message(for: error, context: "Loading search index"))
        }
    }
}
