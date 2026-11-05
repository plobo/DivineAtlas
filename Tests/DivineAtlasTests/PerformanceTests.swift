import XCTest
@testable import DivineAtlas

/// Search must stay responsive as the dataset grows well beyond the MVP's
/// ~70 entries. `measure` blocks report timings in the test log; the
/// equivalence test guards correctness of the index.
final class PerformanceTests: XCTestCase {
    private static let largeDataset: [DivineEntity] = (0..<5_000).map { index in
        DivineEntity(
            id: "entity-\(index)",
            name: "Figure \(index) Ṣaṃskṛta",
            alternativeNames: ["Alias \(index)", "Ālternative-\(index)"],
            summary: "A synthetic summary used only for performance testing, number \(index).",
            classifications: [
                EntityClassification(
                    traditionID: TraditionID.allCases[index % 4],
                    category: EntityCategory.allCases[index % EntityCategory.allCases.count],
                    group: EntityGroup.allCases[index % 3],
                    label: "Label \(index)"
                ),
            ]
        )
    }

    func testIndexedSearchMatchesUnindexedSearch() throws {
        let bundled = try SeedDataLoader.bundled(in: .main).load().entities
        let index = EntitySearchIndex(bundled)
        for text in ["", "jibril", "Mikhael", "visnu", "islam", "fallen angel", "asura", "zzz", "Ṣiva", "of"] {
            let query = EntityQuery(searchText: text)
            XCTAssertEqual(query.apply(to: bundled, index: index), query.apply(to: bundled), "Mismatch for '\(text)'")
        }
    }

    func testIndexedSearchPerformance() {
        let entities = Self.largeDataset
        let index = EntitySearchIndex(entities)
        let query = EntityQuery(group: .adversarial, searchText: "alternative-49")
        measure {
            _ = query.apply(to: entities, index: index)
        }
    }

    func testUnindexedSearchPerformance() {
        let entities = Self.largeDataset
        let query = EntityQuery(group: .adversarial, searchText: "alternative-49")
        measure {
            _ = query.apply(to: entities)
        }
    }

    func testIndexBuildPerformance() {
        let entities = Self.largeDataset
        measure {
            _ = EntitySearchIndex(entities)
        }
    }

    func testSeedLoadPerformance() {
        measure {
            _ = try? SeedDataLoader.bundled(in: .main).load()
        }
    }
}
