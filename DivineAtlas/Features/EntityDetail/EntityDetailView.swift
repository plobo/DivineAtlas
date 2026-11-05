import SwiftUI

/// Entry detail. Every section is optional and hidden when it has no content.
struct EntityDetailView: View {
    @State private var viewModel: EntityDetailViewModel
    @State private var attributionAsset: MediaAsset?

    init(viewModel: EntityDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .themedScreenBackground()
            .task { await viewModel.loadIfNeeded() }
            .sheet(item: $attributionAsset) { asset in
                MediaAttributionView(asset: asset)
            }
            .toolbar {
                if viewModel.state.isLoaded {
                    ToolbarItem(placement: .topBarTrailing) {
                        FavoriteButton(isFavorite: viewModel.isFavorite, action: viewModel.toggleFavorite)
                    }
                }
            }

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
        case .loaded(let detail):
            ScrollView {
                // Lazy so the YouTube section (which spends API quota) is only
                // built, and searched, when scrolled into view.
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    header(detail.entity)
                    classifications(detail)
                    ForEach(detail.orderedSections) { section in
                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            SectionHeaderView(title: section.title)
                            Text(section.body)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            CitationList(citations: section.citations, detail: detail)
                        }
                    }
                    videos(detail.entity)
                    related(detail)
                    if let videos = viewModel.videos {
                        EntityVideosSection(viewModel: videos)
                    }
                    sources(detail)
                }
                .padding(Theme.Spacing.l)
            }
            .accessibilityIdentifier("entityDetail.\(detail.entity.id)")
        }
    }

    private func header(_ entity: DivineEntity) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            EntityArtworkView(asset: entity.primaryImage, entityName: entity.name, size: .hero)
            if let asset = entity.primaryImage {
                Button {
                    attributionAsset = asset
                } label: {
                    // Attribution sits directly under the image, as CC BY licences expect.
                    Label(asset.creditLine.isEmpty ? "Image credit" : asset.creditLine, systemImage: "info.circle")
                        .font(.caption.weight(.medium))
                        .multilineTextAlignment(.leading)
                }
                .tint(Theme.Palette.gold)
                .accessibilityLabel("Image credit: \(asset.creditLine)")
                .accessibilityHint("Shows the artwork's creator, licence, and source")
                .accessibilityIdentifier("entityDetail.imageCredit")
            }
            Text(entity.name)
                .font(.displayLarge)
                .foregroundStyle(Theme.Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if !entity.alternativeNames.isEmpty {
                Text("Also known as \(entity.alternativeNames.joined(separator: ", "))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            if entity.reviewStatus == .draft {
                Label("Draft entry — pending editorial review", systemImage: "pencil.circle")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.Palette.gold)
            }
            Text(entity.summary)
                .font(.body)
                .foregroundStyle(Theme.Palette.textPrimary)
        }
    }

    @ViewBuilder
    private func classifications(_ detail: EntityDetail) -> some View {
        if !detail.entity.classifications.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                SectionHeaderView(title: "In Each Tradition")
                ForEach(Array(detail.entity.classifications.enumerated()), id: \.offset) { _, classification in
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        AdaptiveStack(verticalAlignment: .firstTextBaseline) {
                            Text(classification.traditionID.displayName)
                                .font(.entityTitle)
                                .foregroundStyle(Theme.Palette.textPrimary)
                                .accessibilityAddTraits(.isHeader)
                            Spacer(minLength: 0)
                            CategoryChipView(text: classification.category.displayName)
                        }
                        Text(classification.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Palette.gold)
                        if let explanation = classification.explanation {
                            Text(explanation)
                                .foregroundStyle(Theme.Palette.textPrimary)
                        }
                        CitationList(citations: classification.citations, detail: detail)
                    }
                    .padding(Theme.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface()
                }
            }
        }
    }

    @ViewBuilder
    private func videos(_ entity: DivineEntity) -> some View {
        if !entity.videoLinks.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                // Editor-curated and reviewed; distinct from the unreviewed YouTube results.
                SectionHeaderView(title: "Recommended Videos")
                ForEach(entity.videoLinks) { VideoLinkCard(video: $0) }
            }
        }
    }

    @ViewBuilder
    private func related(_ detail: EntityDetail) -> some View {
        if !detail.relatedEntries.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                SectionHeaderView(title: "Related Figures")
                ForEach(detail.relatedEntries) { entry in
                    if let relatedEntity = entry.relatedEntity {
                        NavigationLink(value: Route.entity(id: relatedEntity.id)) {
                            RelatedEntityCard(name: relatedEntity.name, explanation: entry.relationship.explanation, isLinked: true)
                        }
                        .buttonStyle(.plain)
                    } else {
                        RelatedEntityCard(name: nil, explanation: entry.relationship.explanation, isLinked: false)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sources(_ detail: EntityDetail) -> some View {
        if !detail.sources.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                SectionHeaderView(title: "Sources")
                ForEach(detail.sources) { SourceReferenceRow(source: $0) }
            }
        }
    }
}

struct RelatedEntityCard: View {
    let name: String?
    let explanation: String
    let isLinked: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                if let name {
                    Text(name)
                        .font(.entityTitle)
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer(minLength: 0)
            if isLinked {
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(Theme.Spacing.m)
        .cardSurface()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct CitationList: View {
    let citations: [Citation]
    let detail: EntityDetail

    var body: some View {
        if !citations.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                ForEach(Array(citations.enumerated()), id: \.offset) { _, citation in
                    Label(detail.text(for: citation), systemImage: "text.book.closed")
                        .font(.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Sources: " + citations.map(detail.text(for:)).joined(separator: "; "))
        }
    }
}

struct SourceReferenceRow: View {
    let source: SourceReference

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(source.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text([source.sourceType.displayName, source.author, source.publisher, source.publicationDate]
                .compactMap { $0 }
                .joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(Theme.Palette.gold)
            if let notes = source.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        EntityDetailView(viewModel: PreviewSupport.container.makeEntityDetailViewModel(entityID: "michael"))
    }
}

#Preview("Removed entry") {
    NavigationStack {
        EntityDetailView(viewModel: PreviewSupport.container.makeEntityDetailViewModel(entityID: "removed"))
    }
}
