import SwiftUI

struct LoadingView: View {
    var message = "Loading…"

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            ProgressView()
                .tint(Theme.Palette.gold)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("state.loading")
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    var systemImage = "books.vertical"
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
                .font(.displayTitle)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .tint(Theme.Palette.gold)
            }
        }
        .foregroundStyle(Theme.Palette.textSecondary)
        .accessibilityIdentifier("state.empty")
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Unable to Load", systemImage: "exclamationmark.triangle")
                .font(.displayTitle)
        } description: {
            Text(message)
        } actions: {
            Button("Try Again", action: retry)
                .buttonStyle(.bordered)
                .tint(Theme.Palette.gold)
        }
        .foregroundStyle(Theme.Palette.textSecondary)
        .accessibilityIdentifier("state.error")
    }
}

#Preview("States") {
    VStack {
        LoadingView()
        EmptyStateView(title: "No Entries", message: "Nothing to show yet.")
        ErrorStateView(message: "Something went wrong.") {}
    }
    .themedScreenBackground()
}
