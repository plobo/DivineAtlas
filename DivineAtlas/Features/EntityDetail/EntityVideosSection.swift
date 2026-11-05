import SwiftUI

/// "Videos on YouTube": live, unreviewed search results for an entity, with an
/// always-available link to YouTube's own search.
struct EntityVideosSection: View {
    let viewModel: EntityVideosViewModel

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionHeaderView(title: "Videos on YouTube")
            Label("Results from a YouTube search. Not reviewed by Divine Atlas. Views expressed may not represent the tradition.", systemImage: "exclamationmark.bubble")
                .font(.caption)
                .foregroundStyle(Theme.Palette.textSecondary)

            content

            Button {
                openURL(viewModel.fallbackURL)
            } label: {
                Label("Search “\(viewModel.query.text)” on YouTube", systemImage: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.bordered)
            .tint(Theme.Palette.gold)
            .accessibilityHint("Opens YouTube search outside the app")
            .accessibilityIdentifier("entityVideos.searchOnYouTube")
        }
        .task { await viewModel.loadIfNeeded() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("entityVideos")
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            HStack(spacing: Theme.Spacing.s) {
                ProgressView().tint(Theme.Palette.gold)
                Text("Loading videos…")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .accessibilityElement(children: .combine)
        case .loaded(let results) where results.isEmpty:
            Text("No videos found.")
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.textSecondary)
        case .loaded(let results):
            ForEach(results) { VideoSearchResultRow(result: $0) }
        case .unavailable(let message):
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.textSecondary)
                .accessibilityIdentifier("entityVideos.unavailable")
        }
    }
}

struct VideoSearchResultRow: View {
    let result: VideoSearchResult

    @Environment(\.openURL) private var openURL
    @State private var showsOpenFailure = false

    var body: some View {
        Button {
            openURL(result.watchURL) { accepted in
                if !accepted { showsOpenFailure = true }
            }
        } label: {
            AdaptiveStack(verticalAlignment: .top, spacing: Theme.Spacing.m) {
                VideoThumbnailView(url: result.thumbnailURL)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(result.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    Text("\(result.channelTitle) · YouTube")
                        .font(.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.Spacing.s)
            .cardSurface()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(result.title), \(result.channelTitle), YouTube video")
        .accessibilityHint("Opens in YouTube")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("videoResult.\(result.videoID)")
        .alert("Video Unavailable", isPresented: $showsOpenFailure) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This video could not be opened.")
        }
    }
}

/// 16:9 thumbnail loaded through the shared image pipeline (cached, size-bucketed).
struct VideoThumbnailView: View {
    let url: URL?

    @Environment(\.imageLoader) private var imageLoader
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    private static let size = CGSize(width: 128, height: 72)

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.s, style: .continuous)
            .fill(Theme.Palette.surfaceRaised)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "play.rectangle")
                        .font(.title2)
                        .foregroundStyle(Theme.Palette.gold.opacity(0.8))
                }
            }
            .frame(width: Self.size.width, height: Self.size.height)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.s, style: .continuous))
            .accessibilityHidden(true)
            .task(id: url) {
                image = nil
                guard let url else { return }
                image = try? await imageLoader.image(for: url, maxPixelSize: Int((Self.size.width * displayScale).rounded(.up)))
            }
    }
}
