import Foundation
import Observation

/// YouTube search results for one entity. Loads only when its section is
/// shown, because each uncached search spends API quota.
@MainActor
@Observable
final class EntityVideosViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded([VideoSearchResult])
        /// Nothing to list; the message explains why. The fallback button still works.
        case unavailable(String)
    }

    let query: VideoSearchQuery
    private(set) var state: State = .idle

    private let service: any VideoSearchService

    init(entity: DivineEntity, service: any VideoSearchService) {
        self.query = VideoSearchQuery(entity: entity)
        self.service = service
    }

    /// Always available, whatever the state of the in-app list.
    var fallbackURL: URL { query.youtubeSearchURL }

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await load()
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        do {
            state = .loaded(try await service.videos(for: query))
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .unavailable(Self.message(for: error))
        }
    }

    static func message(for error: any Error) -> String {
        switch error as? VideoSearchError {
        case .notConfigured:
            "Video results aren't available in this version of the app."
        case .quotaExceeded:
            "Video results are temporarily unavailable. Please try again later."
        case .offline:
            "You're offline. Connect to the internet to see videos."
        case .rejected, .unavailable, nil:
            "Video results couldn't be loaded."
        }
    }
}
