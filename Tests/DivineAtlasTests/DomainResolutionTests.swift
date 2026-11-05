import XCTest
@testable import DivineAtlas

final class DomainResolutionTests: XCTestCase {
    func testEntityDetailResolvesRelationshipsAndHandlesMissingTargets() {
        var alpha = TestFixtures.alpha
        alpha.relationships.append(TestFixtures.relationship("alpha-ghost", to: "ghost"))

        let detail = EntityDetail(entity: alpha, allEntities: TestFixtures.content.entities, allSources: [TestFixtures.source])

        XCTAssertEqual(detail.relatedEntries.map(\.id), ["alpha-beta", "alpha-ghost"])
        XCTAssertEqual(detail.relatedEntries[0].relatedEntity?.id, "beta")
        XCTAssertNil(detail.relatedEntries[1].relatedEntity)
    }

    func testEntityDetailDeduplicatesSourcesAndFormatsCitations() {
        let detail = EntityDetail(entity: TestFixtures.alpha, allEntities: [], allSources: [TestFixtures.source])

        XCTAssertEqual(detail.sources, [TestFixtures.source])
        XCTAssertEqual(detail.text(for: Citation(sourceID: "src-a", locator: "2:3")), "Source A, 2:3")
        XCTAssertEqual(detail.text(for: Citation(sourceID: "src-a", locator: nil)), "Source A")
    }

    func testReligionOverviewGroupsByThatTraditionsCategories() {
        let overview = ReligionOverview(
            religion: TestFixtures.religion(.judaism),
            allEntities: TestFixtures.content.entities,
            allSources: [TestFixtures.source]
        )
        // Within Judaism, beta is "other" (not a fallen angel) and gamma is absent.
        XCTAssertEqual(overview.groups.map(\.category), [.angel, .other])
        XCTAssertEqual(overview.groups.map { $0.entities.map(\.id) }, [["alpha"], ["beta"]])
        XCTAssertEqual(overview.sources, [TestFixtures.source])
    }

    func testTraditionIDsAreDerivedUniquelyInOrder() {
        var entity = TestFixtures.alpha
        entity.classifications.append(TestFixtures.classification(.judaism, .archangel, .divineAndCelestial))
        XCTAssertEqual(entity.traditionIDs, [.judaism, .christianity])
    }

    func testReligionsSortInTraditionOrder() {
        let shuffled = [TraditionID.hinduism, .christianity, .islam, .judaism].map(TestFixtures.religion)
        XCTAssertEqual(shuffled.sortedByTraditionOrder().map(\.id), TraditionID.allCases)
    }

    func testOrderedSectionsFollowKindThenAuthoredOrder() {
        var entity = TestFixtures.alpha
        entity.sections = [
            EntityContentSection(id: "i", title: "I", body: "b", kind: .interpretations, citations: []),
            EntityContentSection(id: "h2", title: "H2", body: "b", kind: .history, citations: []),
            EntityContentSection(id: "o", title: "O", body: "b", kind: .overview, citations: []),
            EntityContentSection(id: "h1", title: "H1", body: "b", kind: .history, citations: []),
        ]
        let detail = EntityDetail(entity: entity, allEntities: [], allSources: [])
        XCTAssertEqual(detail.orderedSections.map(\.id), ["o", "h2", "h1", "i"])
    }
}
