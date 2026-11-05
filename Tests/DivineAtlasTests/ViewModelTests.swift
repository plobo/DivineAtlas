import XCTest
@testable import DivineAtlas

@MainActor
final class ViewModelTests: XCTestCase {
    // MARK: EntityBrowseViewModel

    func testBrowseLoadsOnlyEntitiesInGroup() async {
        let viewModel = EntityBrowseViewModel(group: .adversarial, repository: MockContentRepository(), library: .inMemory())
        XCTAssertEqual(viewModel.state, .idle)

        await viewModel.load()

        XCTAssertEqual(viewModel.state.value?.map(\.id), ["beta", "gamma"])
        XCTAssertEqual(viewModel.visibleEntities.map(\.id), ["beta", "gamma"])
        XCTAssertEqual(viewModel.title, "Demons")
    }

    func testBrowseQueryNarrowsVisibleEntitiesWithoutReloading() async {
        let repository = MockContentRepository()
        let viewModel = EntityBrowseViewModel(group: .adversarial, repository: repository, library: .inMemory())
        await viewModel.load()

        viewModel.query.tradition = .islam

        XCTAssertEqual(viewModel.visibleEntities.map(\.id), ["gamma"])
        let callCount = await repository.entitiesCallCount
        XCTAssertEqual(callCount, 1)
    }

    func testBrowseEmptyState() async {
        let empty = SeedContent(religions: [], entities: [], sources: [])
        let viewModel = EntityBrowseViewModel(group: .divineAndCelestial, repository: MockContentRepository(content: empty), library: .inMemory())

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .loaded([]))
        XCTAssertTrue(viewModel.visibleEntities.isEmpty)
    }

    func testBrowseFailureState() async {
        let viewModel = EntityBrowseViewModel(group: .divineAndCelestial, repository: MockContentRepository(.failure(TestError())), library: .inMemory())

        await viewModel.load()

        guard case .failed(let message) = viewModel.state else { return XCTFail("Expected failure, got \(viewModel.state)") }
        XCTAssertFalse(message.isEmpty)
    }

    func testSeedErrorsMapToContentMessage() async {
        let repository = MockContentRepository(.failure(SeedDataError.missingFile("entities.json")))
        let viewModel = EntityBrowseViewModel(group: .divineAndCelestial, repository: repository, library: .inMemory())

        await viewModel.load()

        guard case .failed(let message) = viewModel.state else { return XCTFail("Expected failure") }
        XCTAssertTrue(message.contains("built-in content"), message)
    }

    func testLoadIfNeededDoesNotReload() async {
        let repository = MockContentRepository()
        let viewModel = EntityBrowseViewModel(group: .divineAndCelestial, repository: repository, library: .inMemory())

        await viewModel.loadIfNeeded()
        await viewModel.loadIfNeeded()

        let callCount = await repository.entitiesCallCount
        XCTAssertEqual(callCount, 1)
    }

    // MARK: Other screens

    func testReligionsLoadInTraditionOrder() async {
        var content = TestFixtures.content
        content.religions.reverse()
        let viewModel = ReligionsViewModel(repository: MockContentRepository(content: content))

        await viewModel.load()

        XCTAssertEqual(viewModel.state.value?.map(\.id), TraditionID.allCases)
    }

    func testReligionDetailLoadsOverview() async {
        let viewModel = ReligionDetailViewModel(traditionID: .islam, repository: MockContentRepository())

        await viewModel.load()

        XCTAssertEqual(viewModel.state.value?.groups.map(\.category), [.jinn])
        XCTAssertEqual(viewModel.title, "Islam")
    }

    func testReligionDetailMissingReligionFails() async {
        let content = SeedContent(religions: [], entities: [], sources: [])
        let viewModel = ReligionDetailViewModel(traditionID: .islam, repository: MockContentRepository(content: content))

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .failed(message: "This tradition is not available."))
    }

    func testDiscoverShowsOnlyFeaturedEntities() async {
        let viewModel = DiscoverViewModel(repository: MockContentRepository(), library: .inMemory())

        await viewModel.load()

        XCTAssertEqual(viewModel.state.value?.featured.map(\.id), ["alpha"])
        XCTAssertEqual(viewModel.state.value?.religions.count, 4)
        // Fixtures have no addedAt, so there is no "Recently added" section.
        XCTAssertEqual(viewModel.state.value?.recentlyAdded, [])
    }

    func testDiscoverRecentlyAddedIsNewestFirstAndLimited() async {
        var content = TestFixtures.content
        content.entities = (0..<8).map { index in
            var entity = TestFixtures.entity("e\(index)", classifications: [TestFixtures.classification(.islam, .angel, .divineAndCelestial)])
            entity.addedAt = Date(timeIntervalSince1970: TimeInterval(index))
            return entity
        }
        let viewModel = DiscoverViewModel(repository: MockContentRepository(content: content), library: .inMemory())

        await viewModel.load()

        XCTAssertEqual(viewModel.state.value?.recentlyAdded.map(\.id), ["e7", "e6", "e5", "e4", "e3"])
    }

    func testEntityDetailLoads() async {
        let viewModel = EntityDetailViewModel(entityID: "alpha", repository: MockContentRepository(), library: .inMemory())

        await viewModel.load()

        XCTAssertEqual(viewModel.state.value?.entity.id, "alpha")
        XCTAssertEqual(viewModel.state.value?.relatedEntries.first?.relatedEntity?.id, "beta")
        XCTAssertEqual(viewModel.title, "Alpha")
    }

    func testEntityDetailForRemovedEntityFailsGracefully() async {
        let viewModel = EntityDetailViewModel(entityID: "removed", repository: MockContentRepository(), library: .inMemory())

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .failed(message: "This entry is no longer available."))
    }

    // MARK: Composition root

    func testLiveContainerServesBundledContent() async throws {
        let container = DependencyContainer.live()
        let viewModel = container.makeEntityBrowseViewModel(group: .divineAndCelestial)

        await viewModel.load()

        XCTAssertTrue(viewModel.state.isLoaded)
        XCTAssertFalse(viewModel.visibleEntities.isEmpty)
    }
}
