import Foundation

/// An entity with its relationships and citations resolved for display.
struct EntityDetail: Equatable, Sendable {
    struct RelatedEntry: Identifiable, Equatable, Sendable {
        let relationship: EntityRelationship
        /// `nil` when the target is no longer in the dataset; the UI then shows
        /// the explanation without a link instead of failing.
        let relatedEntity: DivineEntity?

        var id: String { relationship.id }
    }

    let entity: DivineEntity
    let relatedEntries: [RelatedEntry]
    /// Unique cited sources, in order of first citation.
    let sources: [SourceReference]

    init(entity: DivineEntity, allEntities: [DivineEntity], allSources: [SourceReference]) {
        self.entity = entity
        let entitiesByID = Dictionary(allEntities.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        relatedEntries = entity.relationships.map {
            RelatedEntry(relationship: $0, relatedEntity: entitiesByID[$0.relatedEntityID])
        }
        let sourcesByID = Dictionary(allSources.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()
        sources = entity.allCitations
            .map(\.sourceID)
            .filter { seen.insert($0).inserted }
            .compactMap { sourcesByID[$0] }
    }

    /// Content sections in display order (by `SectionKind`, then authored order).
    var orderedSections: [EntityContentSection] {
        let order = SectionKind.allCases
        return entity.sections.enumerated().sorted { lhs, rhs in
            let l = order.firstIndex(of: lhs.element.kind) ?? 0
            let r = order.firstIndex(of: rhs.element.kind) ?? 0
            return l == r ? lhs.offset < rhs.offset : l < r
        }.map(\.element)
    }

    /// Human-readable citation, e.g. "Tanakh (Hebrew Bible), Daniel 10:13".
    func text(for citation: Citation) -> String {
        let title = sources.first { $0.id == citation.sourceID }?.title ?? citation.sourceID
        guard let locator = citation.locator, !locator.isEmpty else { return title }
        return "\(title), \(locator)"
    }
}
