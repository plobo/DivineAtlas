import SwiftUI

struct ReligionsView: View {
    @State private var viewModel: ReligionsViewModel

    init(viewModel: ReligionsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle("Religions")
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
        case .loaded(let religions) where religions.isEmpty:
            EmptyStateView(title: "No Traditions", message: "Traditions will appear here once they have been added.")
        case .loaded(let religions):
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.m) {
                    ForEach(religions) { religion in
                        NavigationLink(value: Route.religion(religion.id)) {
                            ReligionCardView(religion: religion)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.m)
            }
        }
    }
}

struct ReligionCardView: View {
    let religion: Religion

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(religion.name)
                .font(.displayTitle)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(religion.summary)
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.l)
        .cardSurface()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("religionCard.\(religion.id.rawValue)")
    }
}

#Preview {
    NavigationStack {
        ReligionsView(viewModel: PreviewSupport.container.makeReligionsViewModel())
    }
}
