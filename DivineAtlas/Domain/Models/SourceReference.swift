import Foundation

enum SourceType: String, Codable, CaseIterable, Sendable {
    case primaryText
    case commentary
    case scholarship
    case referenceWork
    case folklore
    case other

    var displayName: String {
        switch self {
        case .primaryText: "Primary text"
        case .commentary: "Commentary"
        case .scholarship: "Scholarship"
        case .referenceWork: "Reference work"
        case .folklore: "Folklore"
        case .other: "Other"
        }
    }
}

/// A work that claims in the app can be traced back to.
struct SourceReference: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var title: String
    var author: String?
    var publisher: String?
    var publicationDate: String?
    var url: URL?
    var sourceType: SourceType
    var notes: String?
}

/// A pointer from a claim to a source, optionally narrowed to a passage
/// (for example "Daniel 10:13" within the Tanakh).
struct Citation: Codable, Hashable, Sendable {
    var sourceID: String
    var locator: String?
}
