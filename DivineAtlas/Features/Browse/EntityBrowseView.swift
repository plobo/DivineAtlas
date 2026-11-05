import SwiftUI

/// List screen used by both the Gods & Angels and Demons tabs, with search,
/// tradition/category filters, and sorting.
struct EntityBrowseView: View {
    @State private var viewModel: EntityBrowseViewModel

    init(viewModel: EntityBrowseViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle(viewModel.title)
            .themedScreenBackground()
            .searchable(
                text: $viewModel.query.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search names, traditions, categories"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { optionsMenu }
            }
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
        case .loaded(let entities) where entities.isEmpty:
            EmptyStateView(title: "No Entries Yet", message: "Entries for \(viewModel.title) will appear here once they have been added.")
        case .loaded:
            loadedContent
        }
    }

    private var loadedContent: some View {
        ScrollView {
            let entities = viewModel.visibleEntities
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.m) {
                filters
                if viewModel.query.hasActiveFilters {
                    ActiveFilterSummaryView(
                        summary: viewModel.resultSummary(visibleCount: entities.count),
                        filters: viewModel.activeFilterDescriptions,
                        onReset: viewModel.resetFilters
                    )
                }

                if entities.isEmpty {
                    EmptyStateView(
                        title: "No Matches",
                        message: "No entries match the current search and filters.",
                        systemImage: "magnifyingglass",
                        actionTitle: "Reset Filters",
                        action: viewModel.resetFilters
                    )
                    .padding(.top, Theme.Spacing.xl)
                } else {
                    ForEach(entities) { entity in
                        NavigationLink(value: Route.entity(id: entity.id)) {
                            EntityRowView(entity: entity, group: viewModel.group, isFavorite: viewModel.isFavorite(entity))
                        }
                        .buttonStyle(.plain)
                        .favoriteContextMenu(isFavorite: viewModel.isFavorite(entity)) {
                            viewModel.toggleFavorite(entity)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    @ViewBuilder
    private var filters: some View {
        if viewModel.availableTraditions.count > 1 {
            TraditionFilterView(
                traditions: viewModel.availableTraditions,
                selection: viewModel.query.tradition,
                onSelect: viewModel.selectTradition
            )
        }
        if viewModel.availableCategories.count > 1 {
            CategoryFilterView(
                categories: viewModel.availableCategories,
                selection: viewModel.query.category,
                onSelect: viewModel.selectCategory
            )
        }
    }

    private var optionsMenu: some View {
        Menu {
            Picker("Sort", selection: $viewModel.sortOrder) {
                ForEach(EntitySortOrder.allCases, id: \.self) { order in
                    Text(order.title).tag(order)
                }
            }
            Toggle("Featured Only", isOn: $viewModel.query.featuredOnly)
        } label: {
            Label("Sort and Filter", systemImage: "line.3.horizontal.decrease.circle")
        }
        .accessibilityIdentifier("browse.optionsMenu")
    }
}

#Preview("Loaded") {
    NavigationStack {
        EntityBrowseView(viewModel: PreviewSupport.container.makeEntityBrowseViewModel(group: .adversarial))
    }
}

#Preview("Empty") {
    NavigationStack {
        EntityBrowseView(viewModel: PreviewSupport.emptyContainer.makeEntityBrowseViewModel(group: .divineAndCelestial))
    }
}

#Preview("Error") {
    NavigationStack {
        EntityBrowseView(viewModel: PreviewSupport.failingContainer.makeEntityBrowseViewModel(group: .divineAndCelestial))
    }
}

#Preview("Loading") {
    NavigationStack {
        EntityBrowseView(viewModel: PreviewSupport.loadingContainer.makeEntityBrowseViewModel(group: .divineAndCelestial))
    }
}
