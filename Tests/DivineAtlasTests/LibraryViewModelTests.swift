import XCTest
@testable import DivineAtlas

@MainActor
final class LibraryViewModelTests: XCTestCase {
    func testDetailRecordsViewAndTogglesFavorite() async {
        let library = UserLibrary.inMemory()
        let viewModel = EntityDetailViewModel(entityID: "alpha", repository: MockContentRepository(), library: library)

        await viewModel.load()
        XCTAssertEqual(library.recentlyViewedIDs, ["alpha"])
        XCTAssertFalse(viewModel.isFavorite)

        viewModel.toggleFavorite()
        XCTAssertTrue(viewModel.isFavorite)
        XCTAssertEqual(library.favoriteIDs, ["alpha"])
    }

    func testDetailForRemovedEntityDoesNotRecordView() async {
        let library = UserLibrary.inMemory()
        let viewModel = EntityDetailViewModel(entityID: "removed", repository: MockContentRepository(), library: library)

        await viewModel.load()

        XCTAssertEqual(library.recentlyViewedIDs, [])
    }

    func testBrowseRestoresAndPersistsSortOrder() {
        let library = UserLibrary.inMemory()
        library.setSortOrder(.featuredFirst, for: .adversarial)

        let viewModel = EntityBrowseViewModel(group: .adversarial, repository: MockContentRepository(), library: library)
        XCTAssertEqual(viewModel.sortOrder, .featuredFirst)

        viewModel.sortOrder = .recentlyAdded
        XCTAssertEqual(library.sortOrder(for: .adversarial), .recentlyAdded)
        XCTAssertNil(library.sortOrder(for: .divineAndCelestial))
    }

    func testBrowseFavoriteToggleIsSharedThroughLibrary() async {
        let library = UserLibrary.inMemory()
        let browse = EntityBrowseViewModel(group: .adversarial, repository: MockContentRepository(), library: library)
        await browse.load()
        let beta = browse.visibleEntities[0]

        browse.toggleFavorite(beta)

        XCTAssertTrue(browse.isFavorite(beta))
        let detail = EntityDetailViewModel(entityID: beta.id, repository: MockContentRepository(), library: library)
        XCTAssertTrue(detail.isFavorite)
    }

    func testFavoritesResolveEntitiesAndReportUnavailable() async {
        let library = UserLibrary.inMemory()
        library.setFavorite("alpha", true)
        library.setFavorite("removed", true)
        library.setFavorite("gamma", true)
        let viewModel = FavoritesViewModel(repository: MockContentRepository(), library: library)

        XCTAssertEqual(viewModel.unavailableIDs, [], "Nothing is unavailable before content loads")
        await viewModel.load()

        XCTAssertEqual(viewModel.favorites.map(\.id), ["gamma", "alpha"])
        XCTAssertEqual(viewModel.unavailableIDs, ["removed"])

        viewModel.removeUnavailable()
        XCTAssertEqual(library.favoriteIDs, ["gamma", "alpha"])

        viewModel.remove(viewModel.favorites[0])
        XCTAssertEqual(viewModel.favorites.map(\.id), ["alpha"])
    }

    func testFavoritesFailureState() async {
        let viewModel = FavoritesViewModel(repository: MockContentRepository(.failure(TestError())), library: .inMemory())
        await viewModel.load()
        guard case .failed = viewModel.state else { return XCTFail("Expected failure") }
    }

    func testDiscoverShowsFavoritesAndRecentlyViewed() async {
        let library = UserLibrary.inMemory()
        library.setFavorite("beta", true)
        library.setFavorite("removed", true)
        library.recordView("gamma")
        library.recordView("alpha")
        let viewModel = DiscoverViewModel(repository: MockContentRepository(), library: library)

        await viewModel.load()

        XCTAssertEqual(viewModel.favoriteEntities.map(\.id), ["beta"])
        XCTAssertEqual(viewModel.recentlyViewedEntities.map(\.id), ["alpha", "gamma"])

        library.setFavorite("alpha", true)
        XCTAssertEqual(viewModel.favoritesPreview.map(\.id), ["alpha", "beta"], "Discover reflects library changes live")
    }
}
