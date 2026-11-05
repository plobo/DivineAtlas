import SwiftUI

/// Results for global search. Hosted by Discover while a search is active.
struct SearchView: View {
    let viewModel: SearchViewModel

    var body: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView(message: "Preparing search…")
        case .failed(let message):
            ErrorStateView(message: message) {
                Task { await viewModel.load() }
            }
        case .loaded:
            let results = viewModel.results
            if results.isEmpty {
                ContentUnavailableView.search(text: viewModel.trimmedSearchText)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .accessibilityIdentifier("search.noResults")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.m) {
                        Text("\(results.count) \(results.count == 1 ? "result" : "results")")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Palette.textSecondary)
                        ForEach(results) { entity in
                            NavigationLink(value: Route.entity(id: entity.id)) {
                                EntityRowView(entity: entity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, Theme.Spacing.m)
                }
                .scrollDismissesKeyboard(.immediately)
            }
        }
    }
}
