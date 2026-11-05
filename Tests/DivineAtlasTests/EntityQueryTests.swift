import XCTest
@testable import DivineAtlas

final class EntityQueryTests: XCTestCase {
    private let entities = [TestFixtures.gamma, TestFixtures.beta, TestFixtures.alpha]

    func testEmptyQueryReturnsAllSortedByName() {
        XCTAssertEqual(EntityQuery().apply(to: entities).map(\.id), ["alpha", "beta", "gamma"])
    }

    func testGroupFilter() {
        XCTAssertEqual(EntityQuery(group: .divineAndCelestial).apply(to: entities).map(\.id), ["alpha"])
        XCTAssertEqual(EntityQuery(group: .adversarial).apply(to: entities).map(\.id), ["beta", "gamma"])
    }

    func testGroupAndTraditionMustMatchSameClassification() {
        // Beta is adversarial only in Christianity, so it must not appear
        // under the adversarial group when filtered to Judaism.
        XCTAssertEqual(EntityQuery(group: .adversarial, tradition: .judaism).apply(to: entities), [])
        XCTAssertEqual(EntityQuery(group: .adversarial, tradition: .christianity).apply(to: entities).map(\.id), ["beta"])
    }

    func testCategoryAndFeaturedFilters() {
        XCTAssertEqual(EntityQuery(category: .archangel).apply(to: entities).map(\.id), ["alpha"])
        XCTAssertEqual(EntityQuery(tradition: .judaism, category: .archangel).apply(to: entities), [])
        XCTAssertEqual(EntityQuery(featuredOnly: true).apply(to: entities).map(\.id), ["alpha"])
    }

    func testSearchMatchesAlternativeNameIgnoringPunctuationAndCase() {
        XCTAssertEqual(EntityQuery(searchText: "alpha-variant").apply(to: entities).map(\.id), ["alpha"])
        XCTAssertEqual(EntityQuery(searchText: "ALPHAVAR").apply(to: entities).map(\.id), ["alpha"])
    }

    func testSearchIgnoresDiacritics() {
        XCTAssertEqual(EntityQuery(searchText: "gamma").apply(to: entities).map(\.id), ["gamma"])
    }

    func testSearchMatchesTraditionAndCategoryLabels() {
        XCTAssertEqual(EntityQuery(searchText: "islam").apply(to: entities).map(\.id), ["gamma"])
        XCTAssertEqual(EntityQuery(searchText: "fallen angel").apply(to: entities).map(\.id), ["beta"])
    }

    func testWhitespaceOnlySearchIsIgnored() {
        XCTAssertEqual(EntityQuery(searchText: "   ").apply(to: entities).count, 3)
        XCTAssertFalse(EntityQuery(searchText: "   ").hasActiveFilters)
        XCTAssertTrue(EntityQuery(tradition: .islam).hasActiveFilters)
    }

    func testBundledTransliterationVariantsAreSearchable() throws {
        let content = try SeedDataLoader.bundled(in: .main).load()
        XCTAssertEqual(EntityQuery(searchText: "Jibril").apply(to: content.entities).map(\.id), ["gabriel"])
        XCTAssertEqual(EntityQuery(searchText: "Mikhael").apply(to: content.entities).map(\.id), ["michael"])
        XCTAssertEqual(EntityQuery(searchText: "Visnu").apply(to: content.entities).map(\.id), ["vishnu"])
    }

    func testFeaturedFirstSortKeepsAlphabeticalWithinGroups() {
        let delta = TestFixtures.entity("delta", featured: true, classifications: [TestFixtures.classification(.islam, .angel, .divineAndCelestial)])
        let all = entities + [delta]

        XCTAssertEqual(EntityQuery(sortOrder: .featuredFirst).apply(to: all).map(\.id), ["alpha", "delta", "beta", "gamma"])
        XCTAssertEqual(EntityQuery(sortOrder: .alphabetical).apply(to: all).map(\.id), ["alpha", "beta", "delta", "gamma"])
    }

    func testResetFiltersKeepsGroupAndSort() {
        var query = EntityQuery(group: .adversarial, tradition: .islam, category: .jinn, featuredOnly: true, searchText: "x", sortOrder: .featuredFirst)
        XCTAssertTrue(query.hasActiveFilters)

        query.resetFilters()

        XCTAssertEqual(query, EntityQuery(group: .adversarial, sortOrder: .featuredFirst))
        XCTAssertFalse(query.hasActiveFilters)
    }

    func testCombinedFiltersAndSearch() {
        XCTAssertEqual(EntityQuery(group: .adversarial, tradition: .christianity, searchText: "beta").apply(to: entities).map(\.id), ["beta"])
        XCTAssertEqual(EntityQuery(group: .adversarial, tradition: .christianity, searchText: "gamma").apply(to: entities), [])
    }

    func testRecentlyAddedSortsNewestFirstWithUndatedLast() {
        var old = TestFixtures.alpha
        old.addedAt = Date(timeIntervalSince1970: 100)
        var new = TestFixtures.beta
        new.addedAt = Date(timeIntervalSince1970: 200)
        let undated = TestFixtures.gamma

        XCTAssertEqual(EntityQuery(sortOrder: .recentlyAdded).apply(to: [undated, old, new]).map(\.id), ["beta", "alpha", "gamma"])
    }
}
