import Foundation
import Observation

@MainActor
@Observable
final class ReligionDetailViewModel {
    let traditionID: TraditionID
    private(set) var state: LoadState<ReligionOverview> = .idle

    private let repository: any ContentRepository

    init(traditionID: TraditionID, repository: any ContentRepository) {
        self.traditionID = traditionID
        self.repository = repository
    }

    var title: String { state.value?.religion.name ?? traditionID.displayName }

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await load()
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        do {
            async let religions = repository.religions()
            async let entities = repository.entities()
            async let sources = repository.sources()
            guard let religion = try await religions.first(where: { $0.id == traditionID }) else {
                state = .failed(message: "This tradition is not available.")
                return
            }
            state = .loaded(ReligionOverview(religion: religion, allEntities: try await entities, allSources: try await sources))
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(message: UserFacingError.message(for: error, context: "Loading religion \(traditionID.rawValue)"))
        }
    }
}
