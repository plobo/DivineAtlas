import Foundation

/// Combined filter and search criteria for entity lists.
///
/// Group, tradition, and category constraints must all be satisfied by the
/// *same* classification. This means that, for example, filtering the Demons
/// list to Judaism does not show a figure that only Christianity classifies as
/// adversarial.
struct EntityQuery: Equatable, Sendable {
    var group: EntityGroup?
    var tradition: TraditionID?
    var category: EntityCategory?
    var featuredOnly = false
    var searchText = ""
    var sortOrder: EntitySortOrder = .alphabetical

    var isSearching: Bool { !SearchNormalizer.Normalized(searchText).isEmpty }

    /// True when anything narrows the results (search included). Sorting does not count.
    var hasActiveFilters: Bool {
        tradition != nil || category != nil || featuredOnly || isSearching
    }

    /// Clears search and every filter, keeping `group` and `sortOrder`.
    mutating func resetFilters() {
        tradition = nil
        category = nil
        featuredOnly = false
        searchText = ""
    }

    func matches(_ entity: DivineEntity, index: EntitySearchIndex? = nil) -> Bool {
        matches(entity, needle: SearchNormalizer.Normalized(searchText), index: index)
    }

    /// Filters and sorts. Pass an `EntitySearchIndex` built from the same
    /// entities to avoid re-normalising their text on every call.
    func apply(to entities: [DivineEntity], index: EntitySearchIndex? = nil) -> [DivineEntity] {
        let needle = SearchNormalizer.Normalized(searchText)
        return entities.filter { matches($0, needle: needle, index: index) }.sorted { lhs, rhs in
            switch sortOrder {
            case .alphabetical:
                break
            case .featuredFirst where lhs.isFeatured != rhs.isFeatured:
                return lhs.isFeatured
            case .recentlyAdded where lhs.addedAt != rhs.addedAt:
                // Newest first; entries without a date sort last.
                return (lhs.addedAt ?? .distantPast) > (rhs.addedAt ?? .distantPast)
            default:
                break
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func matches(_ entity: DivineEntity, needle: SearchNormalizer.Normalized, index: EntitySearchIndex?) -> Bool {
        if featuredOnly && !entity.isFeatured { return false }
        let classificationMatches = entity.classifications.contains { classification in
            (group == nil || classification.group == group)
                && (tradition == nil || classification.traditionID == tradition)
                && (category == nil || classification.category == category)
        }
        guard classificationMatches else { return false }
        guard !needle.isEmpty else { return true }
        let haystack = index?.normalizedText(for: entity) ?? EntitySearchIndex.normalize(entity)
        return haystack.contains { $0.contains(needle) }
    }

    /// The fields search matches against: names, alternative names, summary,
    /// classification labels, category names, and tradition names.
    static func searchableText(of entity: DivineEntity) -> [String] {
        var text = [entity.name, entity.summary] + entity.alternativeNames
        for classification in entity.classifications {
            text.append(classification.label)
            text.append(classification.category.displayName)
            text.append(classification.traditionID.displayName)
        }
        return text
    }
}

/// Pre-normalised searchable text for a set of entities, built once when
/// content loads so each keystroke only normalises the query.
struct EntitySearchIndex: Sendable {
    private let entries: [String: [SearchNormalizer.Normalized]]

    init(_ entities: [DivineEntity]) {
        entries = Dictionary(entities.map { ($0.id, Self.normalize($0)) }, uniquingKeysWith: { first, _ in first })
    }

    /// Builds the index off the main actor; normalising a large dataset is
    /// measurable work (~0.3 s for 5,000 entries on the simulator).
    static func build(_ entities: [DivineEntity]) async -> EntitySearchIndex {
        await Task.detached(priority: .userInitiated) { EntitySearchIndex(entities) }.value
    }

    /// Falls back to normalising on the fly for entities not in the index.
    func normalizedText(for entity: DivineEntity) -> [SearchNormalizer.Normalized] {
        entries[entity.id] ?? Self.normalize(entity)
    }

    static func normalize(_ entity: DivineEntity) -> [SearchNormalizer.Normalized] {
        EntityQuery.searchableText(of: entity).map(SearchNormalizer.Normalized.init)
    }
}

enum EntitySortOrder: String, CaseIterable, Sendable {
    case alphabetical
    case featuredFirst
    case recentlyAdded

    var title: String {
        switch self {
        case .alphabetical: "Alphabetical"
        case .featuredFirst: "Featured First"
        case .recentlyAdded: "Recently Added"
        }
    }
}

/// Case-, diacritic-, and punctuation-insensitive matching so that spelling
/// and transliteration variants ("Mikha'el" / "Mikhael", "Viṣṇu" / "Visnu",
/// "Jibra'il" / "Jibrail") find each other. Variants that differ in letters
/// (e.g. "Vishnu" / "Visnu") rely on `alternativeNames`.
enum SearchNormalizer {
    struct Normalized: Sendable {
        let folded: String
        let compact: String

        init(_ text: String) {
            folded = text
                .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            compact = String(folded.unicodeScalars.filter(CharacterSet.alphanumerics.contains).map(Character.init))
        }

        var isEmpty: Bool { compact.isEmpty }

        func contains(_ other: Normalized) -> Bool {
            folded.contains(other.folded) || compact.contains(other.compact)
        }
    }
}
