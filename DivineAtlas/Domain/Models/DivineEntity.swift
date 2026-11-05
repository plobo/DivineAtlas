import Foundation

/// A religious, mythological, or supernatural figure.
///
/// One shared model is used for every kind of figure; how a figure is understood
/// is expressed through tradition-specific `classifications`.
struct DivineEntity: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    var alternativeNames: [String]
    var summary: String
    var classifications: [EntityClassification]
    var imageAssets: [MediaAsset]
    var sections: [EntityContentSection]
    var relationships: [EntityRelationship]
    var videoLinks: [VideoLink]
    var isFeatured: Bool
    var reviewStatus: ReviewStatus
    var lastReviewedAt: Date?
    /// When the entry was added to the dataset; drives "recently added".
    var addedAt: Date?

    init(
        id: String,
        name: String,
        alternativeNames: [String] = [],
        summary: String,
        classifications: [EntityClassification],
        imageAssets: [MediaAsset] = [],
        sections: [EntityContentSection] = [],
        relationships: [EntityRelationship] = [],
        videoLinks: [VideoLink] = [],
        isFeatured: Bool = false,
        reviewStatus: ReviewStatus = .draft,
        lastReviewedAt: Date? = nil,
        addedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.alternativeNames = alternativeNames
        self.summary = summary
        self.classifications = classifications
        self.imageAssets = imageAssets
        self.sections = sections
        self.relationships = relationships
        self.videoLinks = videoLinks
        self.isFeatured = isFeatured
        self.reviewStatus = reviewStatus
        self.lastReviewedAt = lastReviewedAt
        self.addedAt = addedAt
    }

    /// Traditions in which this figure appears, in classification order.
    /// Derived from classifications so the two can never disagree.
    var traditionIDs: [TraditionID] {
        var seen = Set<TraditionID>()
        return classifications.map(\.traditionID).filter { seen.insert($0).inserted }
    }

    var primaryImage: MediaAsset? { imageAssets.first }

    func classifications(in group: EntityGroup) -> [EntityClassification] {
        classifications.filter { $0.group == group }
    }

    /// Every citation made anywhere in the entry.
    var allCitations: [Citation] {
        classifications.flatMap(\.citations)
            + sections.flatMap(\.citations)
            + relationships.flatMap(\.citations)
    }
}

extension DivineEntity {
    enum CodingKeys: String, CodingKey {
        case id, name, alternativeNames, summary, classifications, imageAssets, sections
        case relationships, videoLinks, isFeatured, reviewStatus, lastReviewedAt, addedAt
    }

    /// Optional collections may be omitted from seed JSON and decode as empty.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            alternativeNames: try container.decodeIfPresent([String].self, forKey: .alternativeNames) ?? [],
            summary: try container.decode(String.self, forKey: .summary),
            classifications: try container.decode([EntityClassification].self, forKey: .classifications),
            imageAssets: try container.decodeIfPresent([MediaAsset].self, forKey: .imageAssets) ?? [],
            sections: try container.decodeIfPresent([EntityContentSection].self, forKey: .sections) ?? [],
            relationships: try container.decodeIfPresent([EntityRelationship].self, forKey: .relationships) ?? [],
            videoLinks: try container.decodeIfPresent([VideoLink].self, forKey: .videoLinks) ?? [],
            isFeatured: try container.decodeIfPresent(Bool.self, forKey: .isFeatured) ?? false,
            reviewStatus: try container.decodeIfPresent(ReviewStatus.self, forKey: .reviewStatus) ?? .draft,
            lastReviewedAt: try container.decodeIfPresent(Date.self, forKey: .lastReviewedAt),
            addedAt: try container.decodeIfPresent(Date.self, forKey: .addedAt)
        )
    }
}

/// Editorial state of an entry. Draft content is shown with a visible notice.
enum ReviewStatus: String, Codable, Sendable {
    case draft
    case reviewed
}

/// How one tradition classifies a figure.
struct EntityClassification: Codable, Hashable, Sendable {
    var traditionID: TraditionID
    var category: EntityCategory
    var group: EntityGroup
    /// Tradition-specific wording, shown in preference to `category`.
    var label: String
    var explanation: String?
    var citations: [Citation]

    init(
        traditionID: TraditionID,
        category: EntityCategory,
        group: EntityGroup,
        label: String,
        explanation: String? = nil,
        citations: [Citation] = []
    ) {
        self.traditionID = traditionID
        self.category = category
        self.group = group
        self.label = label
        self.explanation = explanation
        self.citations = citations
    }
}

extension EntityClassification {
    enum CodingKeys: String, CodingKey {
        case traditionID, category, group, label, explanation, citations
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            traditionID: try container.decode(TraditionID.self, forKey: .traditionID),
            category: try container.decode(EntityCategory.self, forKey: .category),
            group: try container.decode(EntityGroup.self, forKey: .group),
            label: try container.decode(String.self, forKey: .label),
            explanation: try container.decodeIfPresent(String.self, forKey: .explanation),
            citations: try container.decodeIfPresent([Citation].self, forKey: .citations) ?? []
        )
    }
}

/// Declaration order is the display order on the detail screen.
enum SectionKind: String, Codable, CaseIterable, Sendable {
    case overview
    case history
    case roles
    case symbols
    case texts
    case interpretations
    case other
}

struct EntityContentSection: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var title: String
    var body: String
    var kind: SectionKind
    var citations: [Citation]
}

struct EntityRelationship: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var relatedEntityID: String
    var relationshipType: String
    var explanation: String
    var citations: [Citation]
}

struct MediaAsset: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var url: URL
    var altText: String
    var creator: String?
    var license: String?
    var sourceURL: URL?
    var attributionText: String?
    var isArtisticReconstruction: Bool
    /// Link to the licence deed, e.g. a Creative Commons page.
    var licenseURL: URL?
    /// When the work was made, as recorded by the source (e.g. "c. 1910").
    var dateText: String?
    /// When a person verified the licence and approved the image. Licence
    /// review is separate from the entry's content review.
    var reviewedAt: Date?

    /// Short credit for display under the image, e.g. "Raja Ravi Varma, c. 1910 · Public domain".
    var creditLine: String {
        let who = [creator, dateText].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        return [who.isEmpty ? nil : who, license].compactMap { $0 }.joined(separator: " · ")
    }
}

/// Licences acceptable for images shipped in the app: public domain, CC0,
/// and Creative Commons BY / BY-SA (versions 2.0–4.0). NonCommercial and
/// NoDerivatives licences are not accepted.
enum MediaLicense {
    static func isAccepted(_ license: String) -> Bool {
        let normalized = license.lowercased().trimmingCharacters(in: .whitespaces)
        if normalized == "public domain" || normalized.hasPrefix("pd-") || normalized.hasPrefix("cc0") {
            return true
        }
        return normalized.range(of: #"^cc by(-sa)? [234]\.[05]( [a-z]+)?$"#, options: .regularExpression) != nil
    }
}

struct VideoLink: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var title: String
    var url: URL
    var provider: String
    var channelName: String?
    var thumbnailURL: URL?
    var reviewedAt: Date?
}

extension EntityContentSection {
    enum CodingKeys: String, CodingKey {
        case id, title, body, kind, citations
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        kind = try container.decode(SectionKind.self, forKey: .kind)
        citations = try container.decodeIfPresent([Citation].self, forKey: .citations) ?? []
    }
}

extension EntityRelationship {
    enum CodingKeys: String, CodingKey {
        case id, relatedEntityID, relationshipType, explanation, citations
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        relatedEntityID = try container.decode(String.self, forKey: .relatedEntityID)
        relationshipType = try container.decode(String.self, forKey: .relationshipType)
        explanation = try container.decode(String.self, forKey: .explanation)
        citations = try container.decodeIfPresent([Citation].self, forKey: .citations) ?? []
    }
}
