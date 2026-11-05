import Foundation
import OSLog

/// Composition root. Builds repositories and view models; views never create
/// services themselves. Passed explicitly — there is no global instance.
@MainActor
final class DependencyContainer {
    let contentRepository: any ContentRepository
    let userLibrary: UserLibrary
    let imageLoader: any ImageLoading
    let videoSearch: any VideoSearchService

    init(
        contentRepository: any ContentRepository,
        userLibrary: UserLibrary,
        imageLoader: any ImageLoading = UnavailableImageLoader(),
        videoSearch: any VideoSearchService = UnavailableVideoSearchService()
    ) {
        self.contentRepository = contentRepository
        self.userLibrary = userLibrary
        self.imageLoader = imageLoader
        self.videoSearch = videoSearch
    }

    /// Production configuration: bundled seed data, SwiftData user data,
    /// the caching image pipeline, and YouTube search when a key is configured.
    ///
    /// Debug builds also accept UI-test launch arguments (see `UITestScenario`
    /// and `UITestScenario.resetUserDataArgument`).
    static func live(launchArguments: [String] = ProcessInfo.processInfo.arguments) -> DependencyContainer {
        let library = UserLibrary(store: makeUserDataStore())
        var repository: any ContentRepository = SeedContentRepository(loader: .bundled())
        var videoSearch: any VideoSearchService = YouTubeSearchService.live() ?? UnavailableVideoSearchService()
        #if DEBUG
        if launchArguments.contains(UITestScenario.resetUserDataArgument) {
            library.resetAll()
        }
        if let scenario = UITestScenario(launchArguments: launchArguments) {
            repository = scenario.repository
        }
        // UI tests never call the live API: stubbed results on request, otherwise none.
        if launchArguments.contains(where: { $0.hasPrefix("-uiTest") }) {
            videoSearch = launchArguments.contains(UITestScenario.stubVideosArgument)
                ? StubVideoSearchService()
                : UnavailableVideoSearchService()
        }
        #endif
        return DependencyContainer(
            contentRepository: repository,
            userLibrary: library,
            imageLoader: ImagePipeline.live(),
            videoSearch: videoSearch
        )
    }

    /// Opens the on-disk store, falling back to memory so the app still works
    /// (without persistence) if the store cannot be opened.
    private static func makeUserDataStore() -> any UserDataStore {
        do {
            return SwiftDataUserDataStore(container: try SwiftDataUserDataStore.makeContainer(inMemory: false))
        } catch {
            Logger(subsystem: "com.divineatlas.DivineAtlas", category: "Persistence")
                .error("Opening user data store failed; using memory only: \(String(describing: error), privacy: .public)")
            return InMemoryUserDataStore()
        }
    }

    func makeEntityBrowseViewModel(group: EntityGroup) -> EntityBrowseViewModel {
        EntityBrowseViewModel(group: group, repository: contentRepository, library: userLibrary)
    }

    func makeReligionsViewModel() -> ReligionsViewModel {
        ReligionsViewModel(repository: contentRepository)
    }

    func makeReligionDetailViewModel(traditionID: TraditionID) -> ReligionDetailViewModel {
        ReligionDetailViewModel(traditionID: traditionID, repository: contentRepository)
    }

    func makeDiscoverViewModel() -> DiscoverViewModel {
        DiscoverViewModel(repository: contentRepository, library: userLibrary)
    }

    func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(repository: contentRepository)
    }

    func makeFavoritesViewModel() -> FavoritesViewModel {
        FavoritesViewModel(repository: contentRepository, library: userLibrary)
    }

    func makeEntityDetailViewModel(entityID: String) -> EntityDetailViewModel {
        EntityDetailViewModel(entityID: entityID, repository: contentRepository, library: userLibrary, videoSearch: videoSearch)
    }
}

#if DEBUG
/// Content scenarios selectable by UI tests via launch arguments.
enum UITestScenario: String, CaseIterable {
    /// Clears favourites, history, and preferences at launch.
    static let resetUserDataArgument = "-uiTestResetUserData"
    /// Returns fixed YouTube results instead of calling the API.
    static let stubVideosArgument = "-uiTestStubVideos"

    case emptyContent = "-uiTestEmptyContent"
    case failingContent = "-uiTestFailingContent"

    init?(launchArguments: [String]) {
        guard let match = Self.allCases.first(where: { launchArguments.contains($0.rawValue) }) else { return nil }
        self = match
    }

    var repository: any ContentRepository {
        switch self {
        case .emptyContent: StaticContentRepository(.success(.empty))
        case .failingContent: StaticContentRepository(.failure(SeedDataError.missingFile("entities.json")))
        }
    }
}

/// Deterministic video results for UI tests and previews.
struct StubVideoSearchService: VideoSearchService {
    func videos(for query: VideoSearchQuery) async throws -> [VideoSearchResult] {
        (1...3).map { index in
            VideoSearchResult(
                videoID: "stub\(index)",
                title: "\(query.text): introduction part \(index)",
                channelTitle: "Sample Channel",
                publishedAt: nil,
                thumbnailURL: nil
            )
        }
    }
}
#endif
