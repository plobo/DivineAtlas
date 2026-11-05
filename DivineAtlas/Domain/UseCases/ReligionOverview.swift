import Foundation

/// A tradition's landing page: the religion record plus its entities grouped by
/// the categories *that tradition* assigns to them.
struct ReligionOverview: Equatable, Sendable {
    struct CategoryGroup: Identifiable, Equatable, Sendable {
        let category: EntityCategory
        let entities: [DivineEntity]

        var id: EntityCategory { category }
    }

    let religion: Religion
    let groups: [CategoryGroup]
    let sources: [SourceReference]

    init(religion: Religion, allEntities: [DivineEntity], allSources: [SourceReference]) {
        self.religion = religion

        var buckets: [EntityCategory: [DivineEntity]] = [:]
        for entity in allEntities {
            let categories = Set(entity.classifications.filter { $0.traditionID == religion.id }.map(\.category))
            for category in categories {
                buckets[category, default: []].append(entity)
            }
        }
        groups = EntityCategory.allCases.compactMap { category in
            guard let entities = buckets[category] else { return nil }
            return CategoryGroup(
                category: category,
                entities: entities.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            )
        }

        let sourcesByID = Dictionary(allSources.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        sources = religion.sourceIDs.compactMap { sourcesByID[$0] }
    }
}
