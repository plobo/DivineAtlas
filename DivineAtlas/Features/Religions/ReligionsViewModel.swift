import Foundation
import Observation

@MainActor
@Observable
final class ReligionsViewModel {
    private(set) var state: LoadState<[Religion]> = .idle

    private let repository: any ContentRepository

    init(repository: any ContentRepository) {
        self.repository = repository
    }

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await load()
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        do {
            state = .loaded(try await repository.religions().sortedByTraditionOrder())
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(message: UserFacingError.message(for: error, context: "Loading religions"))
        }
    }
}
