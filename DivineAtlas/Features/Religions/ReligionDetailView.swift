import SwiftUI

struct ReligionDetailView: View {
    @State private var viewModel: ReligionDetailViewModel

    init(viewModel: ReligionDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.large)
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
        case .loaded(let overview):
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    Text(overview.religion.introduction)
                        .font(.body)
                        .foregroundStyle(Theme.Palette.textPrimary)

                    InterpretiveNoteView(text: overview.religion.interpretiveNote)

                    if overview.groups.isEmpty {
                        Text("No entries have been added for this tradition yet.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    ForEach(overview.groups) { group in
                        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                            SectionHeaderView(title: group.category.pluralDisplayName)
                            ForEach(group.entities) { entity in
                                NavigationLink(value: Route.entity(id: entity.id)) {
                                    EntityRowView(entity: entity)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !overview.sources.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                            SectionHeaderView(title: "Texts & Sources")
                            ForEach(overview.sources) { SourceReferenceRow(source: $0) }
                        }
                    }
                }
                .padding(Theme.Spacing.l)
            }
        }
    }
}

/// Callout stating that interpretations vary within a tradition.
struct InterpretiveNoteView: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.textSecondary)
        } icon: {
            Image(systemName: "info.circle")
                .foregroundStyle(Theme.Palette.gold)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Note: \(text)")
    }
}

#Preview {
    NavigationStack {
        ReligionDetailView(viewModel: PreviewSupport.container.makeReligionDetailViewModel(traditionID: .islam))
    }
}
