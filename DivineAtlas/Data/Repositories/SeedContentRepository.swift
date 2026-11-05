import Foundation

/// Serves content from bundled seed JSON, loading and validating it once.
actor SeedContentRepository: ContentRepository {
    private let loader: SeedDataLoader
    private var cached: SeedContent?

    init(loader: SeedDataLoader) {
        self.loader = loader
    }

    func religions() async throws -> [Religion] {
        try content().religions
    }

    func entities() async throws -> [DivineEntity] {
        try content().entities
    }

    func sources() async throws -> [SourceReference] {
        try content().sources
    }

    private func content() throws -> SeedContent {
        if let cached { return cached }
        let loaded = try loader.load()
        cached = loaded
        return loaded
    }
}
