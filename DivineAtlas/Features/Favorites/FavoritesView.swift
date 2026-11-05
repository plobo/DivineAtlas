import SwiftUI

struct FavoritesView: View {
    @State private var viewModel: FavoritesViewModel

    init(viewModel: FavoritesViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle("Favorites")
            .themedScreenBackground()
            .task { await viewModel.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView()
        case .failed(let message):
            ErrorStateView(message: message) {
                Task { await viewModel.load() }
            }
        case .loaded:
            if viewModel.favorites.isEmpty && viewModel.unavailableIDs.isEmpty {
                EmptyStateView(
                    title: "No Favorites Yet",
                    message: "Tap the heart on any entry to save it here. Favorites are stored on this device and available offline.",
                    systemImage: "heart"
                )
            } else {
                list
            }
        }
    }

    private var list: some View {
        List {
            if !viewModel.unavailableIDs.isEmpty {
                Section {
                    AdaptiveStack(verticalAlignment: .firstTextBaseline) {
                        Text(unavailableMessage)
                            .font(.subheadline)
                            .foregroundStyle(Theme.Palette.textSecondary)
                        Spacer(minLength: Theme.Spacing.s)
                        Button("Remove", action: viewModel.removeUnavailable)
                            .tint(Theme.Palette.gold)
                            .accessibilityIdentifier("favorites.removeUnavailable")
                    }
                }
                .listRowBackground(Theme.Palette.surface)
            }
            Section {
                ForEach(viewModel.favorites) { entity in
                    NavigationLink(value: Route.entity(id: entity.id)) {
                        EntityRowView(entity: entity, isFavorite: true)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: Theme.Spacing.s, leading: Theme.Spacing.l, bottom: Theme.Spacing.s, trailing: Theme.Spacing.l))
                    .swipeActions {
                        Button("Remove", systemImage: "heart.slash", role: .destructive) { viewModel.remove(entity) }
                    }
                    .favoriteContextMenu(isFavorite: true) { viewModel.remove(entity) }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("favorites.list")
    }

    private var unavailableMessage: String {
        let count = viewModel.unavailableIDs.count
        return count == 1
            ? "1 saved entry is no longer in the collection."
            : "\(count) saved entries are no longer in the collection."
    }
}

#Preview {
    let container = PreviewSupport.container
    container.userLibrary.setFavorite("michael", true)
    container.userLibrary.setFavorite("removed-entry", true)
    return NavigationStack {
        FavoritesView(viewModel: container.makeFavoritesViewModel())
    }
}

#Preview("Empty") {
    NavigationStack {
        FavoritesView(viewModel: PreviewSupport.emptyContainer.makeFavoritesViewModel())
    }
}
