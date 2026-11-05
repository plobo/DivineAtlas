import SwiftData
import XCTest
@testable import DivineAtlas

/// Runs the same behavioural checks against both store implementations.
@MainActor
final class UserLibraryTests: XCTestCase {
    private var clock = Date(timeIntervalSince1970: 1_000)

    private func makeStores() throws -> [(String, any UserDataStore)] {
        [
            ("InMemory", InMemoryUserDataStore()),
            ("SwiftData", SwiftDataUserDataStore(container: try SwiftDataUserDataStore.makeContainer(inMemory: true))),
        ]
    }

    private func library(_ store: any UserDataStore) -> UserLibrary {
        UserLibrary(store: store) { [unowned self] in
            clock = clock.addingTimeInterval(1)
            return clock
        }
    }

    func testToggleFavoriteKeepsNewestFirst() throws {
        for (name, store) in try makeStores() {
            let library = library(store)
            library.toggleFavorite("a")
            library.toggleFavorite("b")
            library.toggleFavorite("c")
            library.toggleFavorite("b")

            XCTAssertEqual(library.favoriteIDs, ["c", "a"], name)
            XCTAssertTrue(library.isFavorite("a"), name)
            XCTAssertFalse(library.isFavorite("b"), name)
        }
    }

    func testFavoritesPersistAcrossLibraryInstances() throws {
        for (name, store) in try makeStores() {
            let first = library(store)
            first.setFavorite("a", true)
            first.setFavorite("b", true)
            first.setFavorite("a", true) // Idempotent.

            let second = library(store)
            XCTAssertEqual(second.favoriteIDs, ["b", "a"], name)
        }
    }

    func testRemoveFavorites() throws {
        for (name, store) in try makeStores() {
            let library = library(store)
            ["a", "b", "c"].forEach { library.setFavorite($0, true) }

            library.removeFavorites(["a", "c", "missing"])

            XCTAssertEqual(library.favoriteIDs, ["b"], name)
            XCTAssertEqual(self.library(store).favoriteIDs, ["b"], name)
        }
    }

    func testRecentlyViewedIsDeduplicatedOrderedAndBounded() throws {
        for (name, store) in try makeStores() {
            let library = library(store)
            for index in 0..<(UserLibrary.recentlyViewedLimit + 5) {
                library.recordView("e\(index)")
            }
            library.recordView("e10")

            let expectedFirst = ["e10", "e24", "e23"]
            XCTAssertEqual(Array(library.recentlyViewedIDs.prefix(3)), expectedFirst, name)
            XCTAssertEqual(library.recentlyViewedIDs.count, UserLibrary.recentlyViewedLimit, name)

            let reloaded = self.library(store)
            XCTAssertEqual(Array(reloaded.recentlyViewedIDs.prefix(3)), expectedFirst, name)
            XCTAssertEqual(reloaded.recentlyViewedIDs.count, UserLibrary.recentlyViewedLimit, name)
        }
    }

    func testSortOrderPreferenceRoundTripsAndIgnoresUnknownValues() throws {
        for (name, store) in try makeStores() {
            let library = library(store)
            XCTAssertNil(library.sortOrder(for: .adversarial), name)

            library.setSortOrder(.recentlyAdded, for: .adversarial)
            XCTAssertEqual(self.library(store).sortOrder(for: .adversarial), .recentlyAdded, name)
            XCTAssertNil(library.sortOrder(for: .divineAndCelestial), name)

            library.setPreference("not-a-sort-order", forKey: "sortOrder.adversarial")
            XCTAssertNil(library.sortOrder(for: .adversarial), name)

            library.setPreference(nil, forKey: "sortOrder.adversarial")
            XCTAssertNil(library.preference("sortOrder.adversarial"), name)
        }
    }

    func testResetAllClearsEverything() throws {
        for (name, store) in try makeStores() {
            let library = library(store)
            library.setFavorite("a", true)
            library.recordView("a")
            library.setSortOrder(.featuredFirst, for: .adversarial)

            library.resetAll()

            XCTAssertEqual(library.favoriteIDs, [], name)
            XCTAssertEqual(library.recentlyViewedIDs, [], name)
            XCTAssertNil(library.sortOrder(for: .adversarial), name)
        }
    }

    func testFailedSaveRevertsAndReportsError() {
        let library = UserLibrary(store: FailingUserDataStore())

        library.toggleFavorite("a")

        XCTAssertFalse(library.isFavorite("a"))
        XCTAssertEqual(library.favoriteIDs, [])
        XCTAssertNotNil(library.lastErrorMessage)
        library.clearError()
        XCTAssertNil(library.lastErrorMessage)
    }
}

@MainActor
private final class FailingUserDataStore: UserDataStore {
    func favorites() throws -> [FavoriteEntry] { [] }
    func addFavorite(entityID: String, at date: Date) throws { throw TestError() }
    func removeFavorites(entityIDs: [String]) throws { throw TestError() }
    func recentViews() throws -> [RecentView] { [] }
    func recordView(entityID: String, at date: Date, keepingLatest limit: Int) throws { throw TestError() }
    func preference(forKey key: String) throws -> String? { nil }
    func setPreference(_ value: String?, forKey key: String) throws { throw TestError() }
    func deleteAll() throws {}
}
