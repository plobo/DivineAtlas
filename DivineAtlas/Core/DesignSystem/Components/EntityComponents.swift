import SwiftUI

/// Bordered text chip. Information is carried by the text, never by colour alone.
struct CategoryChipView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(Theme.Palette.gold)
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.xs)
            .overlay(Capsule().strokeBorder(Theme.Palette.gold.opacity(0.5), lineWidth: 1))
    }
}

struct SectionHeaderView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.sectionTitle)
            .foregroundStyle(Theme.Palette.gold)
            .textCase(.uppercase)
            .tracking(1.2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Artwork slot for an entity.
///
/// Loads the asset through the injected `ImageLoading` service (bounded
/// memory and disk caches; works offline once cached). Shows a clearly
/// labelled placeholder when there is no asset or it cannot be loaded, so
/// missing or unavailable media never breaks layout.
struct EntityArtworkView: View {
    enum Size {
        case thumbnail
        case hero

        var height: CGFloat {
            switch self {
            case .thumbnail: 72
            case .hero: 220
            }
        }
    }

    var asset: MediaAsset?
    let entityName: String
    var size: Size = .thumbnail

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size == .hero ? Theme.Radius.l : Theme.Radius.s, style: .continuous)
    }

    @Environment(\.imageLoader) private var imageLoader
    @Environment(\.displayScale) private var displayScale
    @State private var loadedImage: UIImage?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let asset, let loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .scaledToFill()
                    .accessibilityLabel(asset.altText)
                    .overlay(alignment: .bottomLeading) {
                        if asset.isArtisticReconstruction && size == .hero {
                            Text("Artistic interpretation")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, Theme.Spacing.s)
                                .padding(.vertical, Theme.Spacing.xs)
                                .background(.black.opacity(0.6), in: Capsule())
                                .foregroundStyle(Theme.Palette.textPrimary)
                                .padding(Theme.Spacing.s)
                        }
                    }
            } else {
                placeholder(failed: loadFailed)
            }
        }
        .frame(width: size == .thumbnail ? size.height : nil, height: size.height)
        .frame(maxWidth: size == .hero ? .infinity : nil)
        .clipShape(shape)
        .task(id: asset?.url) {
            loadedImage = nil
            loadFailed = false
            guard let url = asset?.url else { return }
            do {
                loadedImage = try await imageLoader.image(for: url, maxPixelSize: requestedPixelSize)
            } catch is CancellationError {
                // View disappeared; nothing to show.
            } catch {
                loadFailed = true
            }
        }
    }

    /// Thumbnails decode at their display size; the hero uses the pipeline's maximum.
    private var requestedPixelSize: Int {
        switch size {
        case .thumbnail: Int((size.height * displayScale).rounded(.up))
        case .hero: ImagePipeline.defaultMaxPixelSize
        }
    }

    private func placeholder(failed: Bool) -> some View {
        shape
            .fill(Theme.Palette.surfaceRaised)
            .overlay {
                VStack(spacing: Theme.Spacing.xs) {
                    Text(String(entityName.prefix(1)))
                        .font(.system(size == .hero ? .largeTitle : .title, design: .serif))
                        .foregroundStyle(Theme.Palette.gold.opacity(0.8))
                    if size == .hero {
                        Text(failed ? "Artwork unavailable" : "No artwork available")
                            .font(.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
            }
            .accessibilityElement()
            .accessibilityLabel(failed ? "Artwork for \(entityName) is unavailable" : "No artwork available for \(entityName)")
    }
}

struct FeaturedBadge: View {
    var body: some View {
        Label("Featured", systemImage: "star.fill")
            .labelStyle(.titleAndIcon)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.Palette.gold)
    }
}

/// List row for an entity. When `group` is given, only classifications that
/// place the entity in that group are summarised.
struct EntityRowView: View {
    let entity: DivineEntity
    var group: EntityGroup?
    var isFavorite = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var relevantClassifications: [EntityClassification] {
        group.map(entity.classifications(in:)) ?? entity.classifications
    }

    private var traditionsText: String {
        var seen = Set<TraditionID>()
        return relevantClassifications
            .map(\.traditionID)
            .filter { seen.insert($0).inserted }
            .map(\.displayName)
            .joined(separator: " · ")
    }

    private var categoryNames: [String] {
        var seen = Set<EntityCategory>()
        return relevantClassifications
            .map(\.category)
            .filter { seen.insert($0).inserted }
            .map(\.displayName)
    }

    var body: some View {
        AdaptiveStack(verticalAlignment: .top, spacing: Theme.Spacing.m) {
            // Decorative in a row: the name follows, and an artwork label would
            // make VoiceOver read "No artwork available" before every entry.
            EntityArtworkView(asset: entity.primaryImage, entityName: entity.name)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    Text(entity.name)
                        .font(.entityTitle)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    if isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.Palette.gold)
                            .accessibilityLabel("Favorite")
                    }
                }
                if entity.isFeatured {
                    FeaturedBadge()
                }
                Text(traditionsText)
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text(entity.summary)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(categoryNames, id: \.self) { CategoryChipView(text: $0) }
                }
                .padding(.top, Theme.Spacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Spacing.m)
        .cardSurface()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("entityRow.\(entity.id)")
    }
}

/// Toggles an entry's favourite state. Conveys state with the icon, label,
/// and `isSelected` trait rather than colour alone.
struct FavoriteButton: View {
    let isFavorite: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(
                isFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: isFavorite ? "heart.fill" : "heart"
            )
        }
        .tint(Theme.Palette.gold)
        .accessibilityAddTraits(isFavorite ? .isSelected : [])
        .accessibilityIdentifier("favoriteButton")
        .sensoryFeedback(.selection, trigger: isFavorite)
    }
}

extension View {
    /// Adds or removes a favourite from a list row: a context menu for touch,
    /// and a named accessibility action so VoiceOver users reach it from the
    /// Actions rotor without a long press.
    func favoriteContextMenu(isFavorite: Bool, toggle: @escaping () -> Void) -> some View {
        let title = isFavorite ? "Remove from Favorites" : "Add to Favorites"
        return contextMenu {
            Button(action: toggle) {
                Label(title, systemImage: isFavorite ? "heart.slash" : "heart")
            }
        }
        .accessibilityAction(named: Text(title), toggle)
    }
}
