import XCTest
@testable import DivineAtlas

@MainActor
final class FilterAndSearchViewModelTests: XCTestCase {
    private func loadedBrowse(_ group: EntityGroup) async -> EntityBrowseViewModel {
        let viewModel = EntityBrowseViewModel(group: group, repository: MockContentRepository(), library: .inMemory())
        await viewModel.load()
        return viewModel
    }

    // MARK: Filter options

    func testAvailableTraditionsAndCategoriesComeFromGroup() async {
        let viewModel = await loadedBrowse(.adversarial)

        // Beta's Judaism classification is "other", so Judaism is not offered here.
        XCTAssertEqual(viewModel.availableTraditions, [.christianity, .islam])
        XCTAssertEqual(viewModel.availableCategories, [.jinn, .fallenAngel])
    }

    func testCategoriesNarrowToSelectedTradition() async {
        let viewModel = await loadedBrowse(.adversarial)

        viewModel.selectTradition(.islam)

        XCTAssertEqual(viewModel.availableCategories, [.jinn])
        XCTAssertEqual(viewModel.visibleEntities.map(\.id), ["gamma"])
    }

    func testSelectingTraditionClearsIncompatibleCategory() async {
        let viewModel = await loadedBrowse(.adversarial)
        viewModel.selectCategory(.fallenAngel)

        viewModel.selectTradition(.islam)

        XCTAssertNil(viewModel.query.category)
        XCTAssertEqual(viewModel.visibleEntities.map(\.id), ["gamma"])
    }

    func testSelectingTraditionKeepsCompatibleCategory() async {
        let viewModel = await loadedBrowse(.adversarial)
        viewModel.selectCategory(.jinn)

        viewModel.selectTradition(.islam)

        XCTAssertEqual(viewModel.query.category, .jinn)
    }

    func testActiveFilterSummaryAndReset() async {
        let viewModel = await loadedBrowse(.adversarial)
        viewModel.selectTradition(.islam)
        viewModel.query.searchText = " gam "

        XCTAssertEqual(viewModel.activeFilterDescriptions, ["Islam", "“gam”"])
        XCTAssertEqual(viewModel.resultSummary, "Showing 1 of 2 entries")

        viewModel.resetFilters()

        XCTAssertFalse(viewModel.query.hasActiveFilters)
        XCTAssertEqual(viewModel.query.group, .adversarial)
        XCTAssertEqual(viewModel.visibleEntities.map(\.id), ["beta", "gamma"])
    }

    func testFilteredEmptyResult() async {
        let viewModel = await loadedBrowse(.divineAndCelestial)
        viewModel.query.searchText = "no such figure"

        XCTAssertTrue(viewModel.visibleEntities.isEmpty)
        XCTAssertEqual(viewModel.resultSummary, "Showing 0 of 1 entry")
    }

    func testFeaturedOnlyToggle() async {
        let viewModel = await loadedBrowse(.divineAndCelestial)
        viewModel.query.featuredOnly = true

        XCTAssertEqual(viewModel.visibleEntities.map(\.id), ["alpha"])
        XCTAssertEqual(viewModel.activeFilterDescriptions, ["Featured"])
    }

    // MARK: Global search

    func testSearchSpansAllGroups() async {
        let viewModel = SearchViewModel(repository: MockContentRepository())
        await viewModel.load()

        XCTAssertFalse(viewModel.isSearching)
        XCTAssertEqual(viewModel.results, [])

        viewModel.searchText = "christianity"
        XCTAssertTrue(viewModel.isSearching)
        XCTAssertEqual(viewModel.results.map(\.id), ["alpha", "beta"])
    }

    func testSearchFindsAlternativeName() async {
        let viewModel = SearchViewModel(repository: MockContentRepository())
        await viewModel.load()

        viewModel.searchText = "alpha variant"

        XCTAssertEqual(viewModel.results.map(\.id), ["alpha"])
    }

    func testSearchFailureState() async {
        let viewModel = SearchViewModel(repository: MockContentRepository(.failure(TestError())))
        await viewModel.load()

        guard case .failed = viewModel.state else { return XCTFail("Expected failure") }
    }

    // MARK: Static repository / scenarios

    func testStaticRepositoryReturnsConfiguredResult() async throws {
        let repository = StaticContentRepository(.success(TestFixtures.content))
        let entities = try await repository.entities()
        XCTAssertEqual(entities.count, 3)

        let failing = StaticContentRepository(.failure(TestError()))
        do {
            _ = try await failing.religions()
            XCTFail("Expected error")
        } catch {}
    }

    func testUITestScenarioParsing() {
        XCTAssertEqual(UITestScenario(launchArguments: ["app", "-uiTestEmptyContent"]), .emptyContent)
        XCTAssertEqual(UITestScenario(launchArguments: ["-uiTestFailingContent"]), .failingContent)
        XCTAssertNil(UITestScenario(launchArguments: ["app"]))
    }
}
