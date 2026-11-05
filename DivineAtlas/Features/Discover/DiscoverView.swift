import SwiftUI

/// Curated discovery, plus global search across every figure.
struct DiscoverView: View {
    @State private var viewModel: DiscoverViewModel
    @State private var searchViewModel: SearchViewModel

    init(viewModel: DiscoverViewModel, searchViewModel: SearchViewModel) {
        _viewModel = State(initialValue: viewModel)
        _searchViewModel = State(initialValue: searchViewModel)
    }

    var body: some View {
        Group {
            if searchViewModel.isSearching {
                SearchView(viewModel: searchViewModel)
            } else {
                content
            }
        }
        .navigationTitle("Discover")
        .themedScreenBackground()
        .searchable(
            text: $searchViewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search all figures"
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.favorites) {
                    Label("Favorites", systemImage: "heart")
                }
                .accessibilityIdentifier("discover.favoritesButton")
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .task { await searchViewModel.loadIfNeeded() }
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
        case .loaded(let content) where content.isEmpty:
            EmptyStateView(title: "Nothing to Discover Yet", message: "Curated content will appear here as the collection grows.", systemImage: "sparkles")
        case .loaded(let content):
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    favoritesSection
                    entitySection("Recently Viewed", entities: viewModel.recentlyViewedEntities, identifier: "discover.recentlyViewed")
                    if !content.featured.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                            SectionHeaderView(title: "Featured")
                            ForEach(content.featured) { entity in
                                NavigationLink(value: Route.entity(id: entity.id)) {
                                    EntityRowView(entity: entity)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if !content.recentlyAdded.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                            SectionHeaderView(title: "Recently Added")
                            ForEach(content.recentlyAdded) { entity in
                                NavigationLink(value: Route.entity(id: entity.id)) {
                                    EntityRowView(entity: entity)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if !content.religions.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                            SectionHeaderView(title: "Explore by Tradition")
                            ForEach(content.religions) { religion in
                                NavigationLink(value: Route.religion(religion.id)) {
                                    ReligionCardView(religion: religion)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.l)
            }
        }
    }
}

extension DiscoverView {
    @ViewBuilder
    private var favoritesSection: some View {
        let favorites = viewModel.favoritesPreview
        if !favorites.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                AdaptiveStack(verticalAlignment: .firstTextBaseline) {
                    SectionHeaderView(title: "Your Favorites")
                    NavigationLink(value: Route.favorites) {
                        Text("See All (\(viewModel.favoriteEntities.count))")
                            .font(.subheadline.weight(.semibold))
                            .fixedSize()
                    }
                    .tint(Theme.Palette.gold)
                    .accessibilityIdentifier("discover.seeAllFavorites")
                }
                ForEach(favorites) { entity in
                    NavigationLink(value: Route.entity(id: entity.id)) {
                        EntityRowView(entity: entity, isFavorite: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("discover.favorites")
        }
    }

    @ViewBuilder
    private func entitySection(_ title: String, entities: [DivineEntity], identifier: String) -> some View {
        if !entities.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                SectionHeaderView(title: title)
                ForEach(entities) { entity in
                    NavigationLink(value: Route.entity(id: entity.id)) {
                        EntityRowView(entity: entity, isFavorite: viewModel.library.isFavorite(entity.id))
                    }
                    .buttonStyle(.plain)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(identifier)
        }
    }
}

#Preview {
    NavigationStack {
        DiscoverView(
            viewModel: PreviewSupport.container.makeDiscoverViewModel(),
            searchViewModel: PreviewSupport.container.makeSearchViewModel()
        )
    }
}

#Preview("Empty") {
    NavigationStack {
        DiscoverView(
            viewModel: PreviewSupport.emptyContainer.makeDiscoverViewModel(),
            searchViewModel: PreviewSupport.emptyContainer.makeSearchViewModel()
        )
    }
}
