import Foundation

struct FavoriteEntry: Equatable, Sendable {
    let entityID: String
    let addedAt: Date
}

struct RecentView: Equatable, Sendable {
    let entityID: String
    let viewedAt: Date
}

/// Persistence for user-owned data: favourites, recently viewed entries, and
/// preferences. Only entity IDs are stored, never entity content, so seed
/// data can change freely underneath.
///
/// Main-actor isolated because the SwiftData implementation uses the
/// container's main context.
@MainActor
protocol UserDataStore: AnyObject {
    /// Newest first.
    func favorites() throws -> [FavoriteEntry]
    func addFavorite(entityID: String, at date: Date) throws
    func removeFavorites(entityIDs: [String]) throws

    /// Most recent first.
    func recentViews() throws -> [RecentView]
    /// Inserts or refreshes a view, then keeps only the `limit` most recent.
    func recordView(entityID: String, at date: Date, keepingLatest limit: Int) throws

    func preference(forKey key: String) throws -> String?
    func setPreference(_ value: String?, forKey key: String) throws

    func deleteAll() throws
}

/// Non-persistent store for previews, tests, and as a fallback when the
/// on-disk store cannot be opened.
@MainActor
final class InMemoryUserDataStore: UserDataStore {
    private var favoriteEntries: [FavoriteEntry] = []
    private var views: [RecentView] = []
    private var preferences: [String: String] = [:]

    init() {}

    func favorites() throws -> [FavoriteEntry] {
        favoriteEntries.sorted { $0.addedAt > $1.addedAt }
    }

    func addFavorite(entityID: String, at date: Date) throws {
        guard !favoriteEntries.contains(where: { $0.entityID == entityID }) else { return }
        favoriteEntries.append(FavoriteEntry(entityID: entityID, addedAt: date))
    }

    func removeFavorites(entityIDs: [String]) throws {
        let ids = Set(entityIDs)
        favoriteEntries.removeAll { ids.contains($0.entityID) }
    }

    func recentViews() throws -> [RecentView] {
        views.sorted { $0.viewedAt > $1.viewedAt }
    }

    func recordView(entityID: String, at date: Date, keepingLatest limit: Int) throws {
        views.removeAll { $0.entityID == entityID }
        views.append(RecentView(entityID: entityID, viewedAt: date))
        views = Array(views.sorted { $0.viewedAt > $1.viewedAt }.prefix(limit))
    }

    func preference(forKey key: String) throws -> String? {
        preferences[key]
    }

    func setPreference(_ value: String?, forKey key: String) throws {
        preferences[key] = value
    }

    func deleteAll() throws {
        favoriteEntries = []
        views = []
        preferences = [:]
    }
}
