import SwiftUI

/// A curated external video. Opens the original URL with the system handler
/// (Safari or the provider's app); nothing is downloaded or embedded.
struct VideoLinkCard: View {
    let video: VideoLink

    @Environment(\.openURL) private var openURL
    @State private var showsOpenFailure = false

    private var metadata: String {
        [video.channelName, video.provider].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        Button {
            openURL(video.url) { accepted in
                if !accepted { showsOpenFailure = true }
            }
        } label: {
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                Image(systemName: "play.rectangle")
                    .font(.title2)
                    .foregroundStyle(Theme.Palette.gold)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(video.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(metadata)
                        .font(.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(Theme.Spacing.m)
            .cardSurface()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the video outside the app")
        .alert("Video Unavailable", isPresented: $showsOpenFailure) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This video could not be opened. It may have been removed or be unavailable in your region.")
        }
    }
}

/// Creator, licence, and source details for a piece of artwork.
struct MediaAttributionView: View {
    let asset: MediaAsset

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(asset.altText)
                    if asset.isArtisticReconstruction {
                        Label("Modern artistic interpretation, not a historical depiction.", systemImage: "paintbrush")
                    }
                }
                Section("Credit") {
                    if let creator = asset.creator { LabeledContent("Creator", value: creator) }
                    if let dateText = asset.dateText { LabeledContent("Date", value: dateText) }
                    if let license = asset.license {
                        if let licenseURL = asset.licenseURL {
                            LabeledContent("Licence") {
                                Link(license, destination: licenseURL)
                            }
                        } else {
                            LabeledContent("Licence", value: license)
                        }
                    }
                    if let attribution = asset.attributionText { Text(attribution) }
                    if asset.creator == nil && asset.license == nil && asset.attributionText == nil {
                        Text("No credit information recorded.")
                            .foregroundStyle(.secondary)
                    }
                }
                if let sourceURL = asset.sourceURL {
                    Section("Source") {
                        Link(destination: sourceURL) {
                            Label(sourceURL.host() ?? sourceURL.absoluteString, systemImage: "arrow.up.right.square")
                        }
                    }
                }
            }
            .navigationTitle("Image Credit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("mediaAttribution.\(asset.id)")
    }
}
