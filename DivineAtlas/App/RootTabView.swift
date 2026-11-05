import SwiftUI

enum AppTab: String, Hashable, CaseIterable {
    case godsAndAngels
    case demons
    case religions
    case discover

    var title: String {
        switch self {
        case .godsAndAngels: "Gods & Angels"
        case .demons: "Demons"
        case .religions: "Religions"
        case .discover: "Discover"
        }
    }

    var systemImage: String {
        switch self {
        case .godsAndAngels: "sun.max"
        case .demons: "flame"
        case .religions: "books.vertical"
        case .discover: "sparkles"
        }
    }
}

/// The four primary destinations, each with its own `NavigationStack` so
/// navigation state is preserved when switching tabs.
struct RootTabView: View {
    private let container: DependencyContainer

    @State private var selectedTab: AppTab = .godsAndAngels
    @State private var godsAndAngelsViewModel: EntityBrowseViewModel
    @State private var demonsViewModel: EntityBrowseViewModel
    @State private var religionsViewModel: ReligionsViewModel
    @State private var discoverViewModel: DiscoverViewModel
    @State private var searchViewModel: SearchViewModel

    private static let selectedTabKey = "selectedTab"

    init(container: DependencyContainer) {
        self.container = container
        _selectedTab = State(initialValue: container.userLibrary.preference(Self.selectedTabKey).flatMap(AppTab.init(rawValue:)) ?? .godsAndAngels)
        _godsAndAngelsViewModel = State(initialValue: container.makeEntityBrowseViewModel(group: .divineAndCelestial))
        _demonsViewModel = State(initialValue: container.makeEntityBrowseViewModel(group: .adversarial))
        _religionsViewModel = State(initialValue: container.makeReligionsViewModel())
        _discoverViewModel = State(initialValue: container.makeDiscoverViewModel())
        _searchViewModel = State(initialValue: container.makeSearchViewModel())
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            tab(.godsAndAngels) { EntityBrowseView(viewModel: godsAndAngelsViewModel) }
            tab(.demons) { EntityBrowseView(viewModel: demonsViewModel) }
            tab(.religions) { ReligionsView(viewModel: religionsViewModel) }
            tab(.discover) { DiscoverView(viewModel: discoverViewModel, searchViewModel: searchViewModel) }
        }
        .tint(Theme.Palette.gold)
        .environment(\.imageLoader, container.imageLoader)
        // Shown at the root so failures from any screen (e.g. a list's
        // context menu) are reported where they happen.
        .alert("Couldn't Save", isPresented: saveErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(container.userLibrary.lastErrorMessage ?? "")
        }
        .onChange(of: selectedTab) { _, tab in
            container.userLibrary.setPreference(tab.rawValue, forKey: Self.selectedTabKey)
        }
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { container.userLibrary.lastErrorMessage != nil },
            set: { if !$0 { container.userLibrary.clearError() } }
        )
    }

    private func tab<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .navigationDestination(for: Route.self) { route in
                    RouteDestinationView(route: route, container: container)
                }
        }
        .tabItem { Label(tab.title, systemImage: tab.systemImage) }
        .tag(tab)
    }
}

/// Builds the screen for a `Route` using the composition root.
private struct RouteDestinationView: View {
    let route: Route
    let container: DependencyContainer

    var body: some View {
        switch route {
        case .entity(let id):
            EntityDetailView(viewModel: container.makeEntityDetailViewModel(entityID: id))
        case .religion(let traditionID):
            ReligionDetailView(viewModel: container.makeReligionDetailViewModel(traditionID: traditionID))
        case .favorites:
            FavoritesView(viewModel: container.makeFavoritesViewModel())
        }
    }
}

#Preview {
    RootTabView(container: PreviewSupport.container)
        .preferredColorScheme(.dark)
}
