import Foundation

/// Stable identifier for a religious tradition supported by the app.
///
/// Adding a tradition means adding a case here plus a record in `religions.json`;
/// screens are driven by data and should not need changes.
enum TraditionID: String, Codable, CaseIterable, Identifiable, Sendable {
    case christianity
    case judaism
    case islam
    case hinduism

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .christianity: "Christianity"
        case .judaism: "Judaism"
        case .islam: "Islam"
        case .hinduism: "Hinduism"
        }
    }
}
