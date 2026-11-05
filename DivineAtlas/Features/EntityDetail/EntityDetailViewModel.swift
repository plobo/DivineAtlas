import Foundation
import Observation

@MainActor
@Observable
final class EntityDetailViewModel {
    let entityID: String
    private(set) var state: LoadState<EntityDetail> = .idle
    let library: UserLibrary
    /// Created once the entity has loaded; loads its own results lazily.
    private(set) var videos: EntityVideosViewModel?

    private let repository: any ContentRepository
    private let videoSearch: any VideoSearchService

    init(
        entityID: String,
        repository: any ContentRepository,
        library: UserLibrary,
        videoSearch: any VideoSearchService = UnavailableVideoSearchService()
    ) {
        self.entityID = entityID
        self.repository = repository
        self.library = library
        self.videoSearch = videoSearch
    }

    var title: String { state.value?.entity.name ?? "" }

    var isFavorite: Bool { library.isFavorite(entityID) }

    func toggleFavorite() {
        library.toggleFavorite(entityID)
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
            async let sources = repository.sources()
            let allEntities = try await entities
            guard let entity = allEntities.first(where: { $0.id == entityID }) else {
                // Entries can be removed from seed data while still referenced
                // elsewhere (e.g. favourites); fail gracefully.
                state = .failed(message: "This entry is no longer available.")
                return
            }
            state = .loaded(EntityDetail(entity: entity, allEntities: allEntities, allSources: try await sources))
            if videos == nil {
                videos = EntityVideosViewModel(entity: entity, service: videoSearch)
            }
            library.recordView(entityID)
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(message: UserFacingError.message(for: error, context: "Loading entity \(entityID)"))
        }
    }
}
