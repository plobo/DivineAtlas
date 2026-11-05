import SwiftUI

/// Selectable chip. Selection is shown by fill, a checkmark, and the
/// `isSelected` accessibility trait — never by colour alone.
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .frame(minHeight: 44)
            .foregroundStyle(isSelected ? Theme.Palette.background : Theme.Palette.textPrimary)
            .background(isSelected ? Theme.Palette.gold : Theme.Palette.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Theme.Palette.border, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Horizontally scrolling single-selection chip row with an "All" option.
struct FilterChipBar<Option: Hashable>: View {
    let accessibilityTitle: String
    let allTitle: String
    let options: [Option]
    let selection: Option?
    let title: (Option) -> String
    let identifier: (Option) -> String
    let onSelect: (Option?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s) {
                FilterChip(title: allTitle, isSelected: selection == nil) { onSelect(nil) }
                ForEach(options, id: \.self) { option in
                    FilterChip(title: title(option), isSelected: selection == option) {
                        // Tapping the selected chip clears it.
                        onSelect(selection == option ? nil : option)
                    }
                    .accessibilityIdentifier(identifier(option))
                }
            }
        }
        .scrollClipDisabled()
        // Chips scroll horizontally; beyond this size a single chip fills the
        // screen. Text still grows well past the default size.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityTitle)
    }
}

struct TraditionFilterView: View {
    let traditions: [TraditionID]
    let selection: TraditionID?
    let onSelect: (TraditionID?) -> Void

    var body: some View {
        FilterChipBar(
            accessibilityTitle: "Tradition filter",
            allTitle: "All traditions",
            options: traditions,
            selection: selection,
            title: \.displayName,
            identifier: { "filter.tradition.\($0.rawValue)" },
            onSelect: onSelect
        )
    }
}

struct CategoryFilterView: View {
    let categories: [EntityCategory]
    let selection: EntityCategory?
    let onSelect: (EntityCategory?) -> Void

    var body: some View {
        FilterChipBar(
            accessibilityTitle: "Category filter",
            allTitle: "All categories",
            options: categories,
            selection: selection,
            title: \.displayName,
            identifier: { "filter.category.\($0.rawValue)" },
            onSelect: onSelect
        )
    }
}

/// Result count, active filters, and a reset action.
struct ActiveFilterSummaryView: View {
    let summary: String
    let filters: [String]
    let onReset: () -> Void

    var body: some View {
        AdaptiveStack(verticalAlignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(summary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                if !filters.isEmpty {
                    Text(filters.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            Button("Reset", action: onReset)
                .font(.subheadline.weight(.semibold))
                .tint(Theme.Palette.gold)
                .accessibilityLabel("Reset filters")
                .accessibilityIdentifier("filters.reset")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("filters.summary")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        TraditionFilterView(traditions: TraditionID.allCases, selection: .islam) { _ in }
        CategoryFilterView(categories: [.angel, .archangel, .jinn], selection: nil) { _ in }
        ActiveFilterSummaryView(summary: "Showing 1 of 6 entries", filters: ["Islam"]) {}
    }
    .padding()
    .themedScreenBackground()
}
