import Foundation
import Observation

/// Shared state for the Gods & Angels and Demons tabs, which differ only in
/// the `EntityGroup` they browse.
@MainActor
@Observable
final class EntityBrowseViewModel {
    let group: EntityGroup
    /// Entities with at least one classification in `group`.
    private(set) var state: LoadState<[DivineEntity]> = .idle
    var query: EntityQuery
    let library: UserLibrary

    @ObservationIgnored private var searchIndex: EntitySearchIndex?
    private let repository: any ContentRepository

    init(group: EntityGroup, repository: any ContentRepository, library: UserLibrary) {
        self.group = group
        self.repository = repository
        self.library = library
        self.query = EntityQuery(group: group, sortOrder: library.sortOrder(for: group) ?? .alphabetical)
    }

    /// Sort order, persisted per tab.
    var sortOrder: EntitySortOrder {
        get { query.sortOrder }
        set {
            query.sortOrder = newValue
            library.setSortOrder(newValue, for: group)
        }
    }

    func isFavorite(_ entity: DivineEntity) -> Bool {
        library.isFavorite(entity.id)
    }

    func toggleFavorite(_ entity: DivineEntity) {
        library.toggleFavorite(entity.id)
    }

    var title: String { group.title }

    var visibleEntities: [DivineEntity] {
        query.apply(to: state.value ?? [], index: searchIndex)
    }

    var totalCount: Int { state.value?.count ?? 0 }

    // MARK: Filter options

    private var groupClassifications: [EntityClassification] {
        (state.value ?? []).flatMap { $0.classifications(in: group) }
    }

    /// Traditions that have at least one entity in this group.
    var availableTraditions: [TraditionID] {
        let present = Set(groupClassifications.map(\.traditionID))
        return TraditionID.allCases.filter(present.contains)
    }

    /// Categories in this group, narrowed to the selected tradition, so a
    /// category chip never leads to a guaranteed-empty list.
    var availableCategories: [EntityCategory] {
        let present = Set(groupClassifications
            .filter { query.tradition == nil || $0.traditionID == query.tradition }
            .map(\.category))
        return EntityCategory.allCases.filter(present.contains)
    }

    func selectTradition(_ tradition: TraditionID?) {
        query.tradition = tradition
        if let category = query.category, !availableCategories.contains(category) {
            query.category = nil
        }
    }

    func selectCategory(_ category: EntityCategory?) {
        query.category = category
    }

    /// Human-readable list of active filters, e.g. ["Islam", "Jinn", "“iblis”"].
    var activeFilterDescriptions: [String] {
        var descriptions: [String] = []
        if let tradition = query.tradition { descriptions.append(tradition.displayName) }
        if let category = query.category { descriptions.append(category.displayName) }
        if query.featuredOnly { descriptions.append("Featured") }
        if query.isSearching {
            descriptions.append("“\(query.searchText.trimmingCharacters(in: .whitespacesAndNewlines))”")
        }
        return descriptions
    }

    var resultSummary: String {
        resultSummary(visibleCount: visibleEntities.count)
    }

    /// Lets the view reuse a count it has already computed.
    func resultSummary(visibleCount count: Int) -> String {
        "Showing \(count) of \(totalCount) \(totalCount == 1 ? "entry" : "entries")"
    }

    func resetFilters() {
        query.resetFilters()
    }

    // MARK: Loading

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await load()
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        do {
            let entities = try await repository.entities().filter { !$0.classifications(in: group).isEmpty }
            searchIndex = await EntitySearchIndex.build(entities)
            state = .loaded(entities)
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(message: UserFacingError.message(for: error, context: "Loading \(group.rawValue) entities"))
        }
    }
}
