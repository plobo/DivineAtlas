import Foundation
@testable import DivineAtlas

/// Deterministic in-memory fixtures. Content is synthetic and exists only to
/// exercise logic; it is not religious content.
enum TestFixtures {
    static let source = SourceReference(id: "src-a", title: "Source A", sourceType: .primaryText)

    static func religion(_ id: TraditionID) -> Religion {
        Religion(id: id, name: id.displayName, summary: "Summary", introduction: "Introduction", interpretiveNote: "Note", sourceIDs: [source.id])
    }

    static func classification(
        _ tradition: TraditionID,
        _ category: EntityCategory,
        _ group: EntityGroup,
        label: String? = nil
    ) -> EntityClassification {
        EntityClassification(traditionID: tradition, category: category, group: group, label: label ?? category.displayName, citations: [Citation(sourceID: source.id, locator: "1:1")])
    }

    static func entity(
        _ id: String,
        name: String? = nil,
        alternativeNames: [String] = [],
        featured: Bool = false,
        classifications: [EntityClassification],
        relationships: [EntityRelationship] = []
    ) -> DivineEntity {
        DivineEntity(
            id: id,
            name: name ?? id.capitalized,
            alternativeNames: alternativeNames,
            summary: "Summary of \(id)",
            classifications: classifications,
            relationships: relationships,
            isFeatured: featured
        )
    }

    static func relationship(_ id: String, to target: String) -> EntityRelationship {
        EntityRelationship(id: id, relatedEntityID: target, relationshipType: "relatedTo", explanation: "Explanation", citations: [])
    }

    /// Alpha: celestial in two traditions. Beta: adversarial in one tradition,
    /// "other" in another. Gamma: adversarial jinn-category entity.
    static let alpha = entity("alpha", alternativeNames: ["Al'pha-variant"], featured: true, classifications: [
        classification(.judaism, .angel, .divineAndCelestial),
        classification(.christianity, .archangel, .divineAndCelestial),
    ], relationships: [relationship("alpha-beta", to: "beta")])

    static let beta = entity("beta", classifications: [
        classification(.judaism, .other, .other),
        classification(.christianity, .fallenAngel, .adversarial),
    ])

    static let gamma = entity("gamma", name: "Ğamma", classifications: [
        classification(.islam, .jinn, .adversarial),
    ])

    static let content = SeedContent(
        religions: TraditionID.allCases.map(religion),
        entities: [alpha, beta, gamma],
        sources: [source]
    )
}

/// Repository double with configurable results and call counting.
actor MockContentRepository: ContentRepository {
    private let result: Result<SeedContent, any Error>
    private(set) var entitiesCallCount = 0

    init(_ result: Result<SeedContent, any Error>) {
        self.result = result
    }

    init(content: SeedContent = TestFixtures.content) {
        self.init(.success(content))
    }

    func religions() async throws -> [Religion] { try result.get().religions }

    func entities() async throws -> [DivineEntity] {
        entitiesCallCount += 1
        return try result.get().entities
    }

    func sources() async throws -> [SourceReference] { try result.get().sources }
}

struct TestError: Error {}
