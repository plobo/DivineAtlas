import Foundation
import SwiftData

@Model
final class FavoriteRecord {
    @Attribute(.unique) var entityID: String
    var addedAt: Date

    init(entityID: String, addedAt: Date) {
        self.entityID = entityID
        self.addedAt = addedAt
    }
}

@Model
final class RecentViewRecord {
    @Attribute(.unique) var entityID: String
    var viewedAt: Date

    init(entityID: String, viewedAt: Date) {
        self.entityID = entityID
        self.viewedAt = viewedAt
    }
}

@Model
final class PreferenceRecord {
    @Attribute(.unique) var key: String
    var value: String

    init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

/// SwiftData-backed `UserDataStore`.
@MainActor
final class SwiftDataUserDataStore: UserDataStore {
    static let schema = Schema([FavoriteRecord.self, RecentViewRecord.self, PreferenceRecord.self])

    /// Retained deliberately: a `ModelContext` does not keep its container
    /// alive, and fetching through a context whose container has been
    /// deallocated traps at runtime.
    private let container: ModelContainer
    private let context: ModelContext

    init(container: ModelContainer) {
        self.container = container
        context = container.mainContext
    }

    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        if inMemory {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        }
        // Application Support does not exist on a fresh install; create it so
        // the store opens cleanly on first launch.
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let storeURL = directory.appending(path: "UserData.store", directoryHint: .notDirectory)
        return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: storeURL))
    }

    // MARK: Favourites

    func favorites() throws -> [FavoriteEntry] {
        let descriptor = FetchDescriptor<FavoriteRecord>(sortBy: [SortDescriptor(\.addedAt, order: .reverse)])
        return try context.fetch(descriptor).map { FavoriteEntry(entityID: $0.entityID, addedAt: $0.addedAt) }
    }

    func addFavorite(entityID: String, at date: Date) throws {
        guard try favoriteRecord(entityID) == nil else { return }
        context.insert(FavoriteRecord(entityID: entityID, addedAt: date))
        try context.save()
    }

    func removeFavorites(entityIDs: [String]) throws {
        for id in entityIDs {
            if let record = try favoriteRecord(id) { context.delete(record) }
        }
        try context.save()
    }

    private func favoriteRecord(_ entityID: String) throws -> FavoriteRecord? {
        var descriptor = FetchDescriptor<FavoriteRecord>(predicate: #Predicate { $0.entityID == entityID })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: Recently viewed

    func recentViews() throws -> [RecentView] {
        let descriptor = FetchDescriptor<RecentViewRecord>(sortBy: [SortDescriptor(\.viewedAt, order: .reverse)])
        return try context.fetch(descriptor).map { RecentView(entityID: $0.entityID, viewedAt: $0.viewedAt) }
    }

    func recordView(entityID: String, at date: Date, keepingLatest limit: Int) throws {
        var descriptor = FetchDescriptor<RecentViewRecord>(predicate: #Predicate { $0.entityID == entityID })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.viewedAt = date
        } else {
            context.insert(RecentViewRecord(entityID: entityID, viewedAt: date))
        }
        let all = try context.fetch(FetchDescriptor<RecentViewRecord>(sortBy: [SortDescriptor(\.viewedAt, order: .reverse)]))
        for record in all.dropFirst(limit) {
            context.delete(record)
        }
        try context.save()
    }

    // MARK: Preferences

    func preference(forKey key: String) throws -> String? {
        try preferenceRecord(key)?.value
    }

    func setPreference(_ value: String?, forKey key: String) throws {
        let existing = try preferenceRecord(key)
        switch (existing, value) {
        case (let record?, let value?): record.value = value
        case (let record?, nil): context.delete(record)
        case (nil, let value?): context.insert(PreferenceRecord(key: key, value: value))
        case (nil, nil): return
        }
        try context.save()
    }

    private func preferenceRecord(_ key: String) throws -> PreferenceRecord? {
        var descriptor = FetchDescriptor<PreferenceRecord>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func deleteAll() throws {
        try context.delete(model: FavoriteRecord.self)
        try context.delete(model: RecentViewRecord.self)
        try context.delete(model: PreferenceRecord.self)
        try context.save()
    }
}
