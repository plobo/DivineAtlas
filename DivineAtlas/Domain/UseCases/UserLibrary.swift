import Foundation
import Observation
import OSLog

/// The user's favourites, recently viewed entries, and preferences.
///
/// Observable so every screen showing favourite state updates together.
/// Changes are applied in memory first and reverted if persisting fails.
@MainActor
@Observable
final class UserLibrary {
    static let recentlyViewedLimit = 20

    /// Newest first. May contain IDs no longer present in the dataset.
    private(set) var favoriteIDs: [String] = []
    /// Most recent first.
    private(set) var recentlyViewedIDs: [String] = []
    /// Set when a change could not be saved; cleared by `clearError()`.
    private(set) var lastErrorMessage: String?

    private var favoriteSet: Set<String> = []

    @ObservationIgnored private let store: any UserDataStore
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let logger = Logger(subsystem: "com.divineatlas.DivineAtlas", category: "UserLibrary")

    init(store: any UserDataStore, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.now = now
        reload()
    }

    static func inMemory() -> UserLibrary {
        UserLibrary(store: InMemoryUserDataStore())
    }

    // MARK: Favourites

    func isFavorite(_ entityID: String) -> Bool {
        favoriteSet.contains(entityID)
    }

    func toggleFavorite(_ entityID: String) {
        setFavorite(entityID, !isFavorite(entityID))
    }

    func setFavorite(_ entityID: String, _ isFavorite: Bool) {
        guard isFavorite != self.isFavorite(entityID) else { return }
        let previous = favoriteIDs
        favoriteIDs = isFavorite ? [entityID] + favoriteIDs : favoriteIDs.filter { $0 != entityID }
        favoriteSet = Set(favoriteIDs)
        perform("save your favorites", revert: { self.restoreFavorites(previous) }) {
            if isFavorite {
                try store.addFavorite(entityID: entityID, at: now())
            } else {
                try store.removeFavorites(entityIDs: [entityID])
            }
        }
    }

    func removeFavorites(_ entityIDs: [String]) {
        guard !entityIDs.isEmpty else { return }
        let previous = favoriteIDs
        let removed = Set(entityIDs)
        favoriteIDs.removeAll { removed.contains($0) }
        favoriteSet = Set(favoriteIDs)
        perform("update your favorites", revert: { self.restoreFavorites(previous) }) {
            try store.removeFavorites(entityIDs: entityIDs)
        }
    }

    private func restoreFavorites(_ ids: [String]) {
        favoriteIDs = ids
        favoriteSet = Set(ids)
    }

    // MARK: Recently viewed

    func recordView(_ entityID: String) {
        recentlyViewedIDs = Array(([entityID] + recentlyViewedIDs.filter { $0 != entityID }).prefix(Self.recentlyViewedLimit))
        // Not worth surfacing an error to the user; history is best-effort.
        do {
            try store.recordView(entityID: entityID, at: now(), keepingLatest: Self.recentlyViewedLimit)
        } catch {
            logger.error("Recording view failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: Preferences

    func sortOrder(for group: EntityGroup) -> EntitySortOrder? {
        preference(Self.sortOrderKey(group)).flatMap(EntitySortOrder.init(rawValue:))
    }

    func setSortOrder(_ order: EntitySortOrder, for group: EntityGroup) {
        setPreference(order.rawValue, forKey: Self.sortOrderKey(group))
    }

    func preference(_ key: String) -> String? {
        do {
            return try store.preference(forKey: key)
        } catch {
            logger.error("Reading preference \(key, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    func setPreference(_ value: String?, forKey key: String) {
        do {
            try store.setPreference(value, forKey: key)
        } catch {
            logger.error("Saving preference \(key, privacy: .public) failed: \(String(describing: error), privacy: .public)")
        }
    }

    private static func sortOrderKey(_ group: EntityGroup) -> String { "sortOrder.\(group.rawValue)" }

    // MARK: Maintenance

    func clearError() {
        lastErrorMessage = nil
    }

    /// Deletes all user data (used by UI tests to start from a clean state).
    func resetAll() {
        do {
            try store.deleteAll()
        } catch {
            logger.error("Reset failed: \(String(describing: error), privacy: .public)")
        }
        reload()
    }

    private func reload() {
        do {
            restoreFavorites(try store.favorites().map(\.entityID))
            recentlyViewedIDs = try store.recentViews().map(\.entityID)
        } catch {
            logger.error("Loading user data failed: \(String(describing: error), privacy: .public)")
            lastErrorMessage = "Your saved favorites could not be loaded."
        }
    }

    private func perform(_ action: String, revert: () -> Void, _ body: () throws -> Void) {
        do {
            try body()
        } catch {
            logger.error("Failed to \(action, privacy: .public): \(String(describing: error), privacy: .public)")
            revert()
            lastErrorMessage = "We couldn't \(action). Please try again."
        }
    }
}
