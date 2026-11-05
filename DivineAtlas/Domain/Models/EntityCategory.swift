import Foundation

/// A coarse category used for filtering and grouping.
///
/// Categories are deliberately *not* treated as equivalent across traditions:
/// every classification also carries a tradition-specific `label` and
/// `explanation`, which is what the UI presents as the primary description.
enum EntityCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case god
    case goddess
    case angel
    case archangel
    case prophet
    case spirit
    case jinn
    case demon
    case fallenAngel
    case asura
    case rakshasa
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .god: "God"
        case .goddess: "Goddess"
        case .angel: "Angel"
        case .archangel: "Archangel"
        case .prophet: "Prophet"
        case .spirit: "Spirit"
        case .jinn: "Jinn"
        case .demon: "Demon"
        case .fallenAngel: "Fallen angel"
        case .asura: "Asura"
        case .rakshasa: "Rakshasa"
        case .other: "Other"
        }
    }

    var pluralDisplayName: String {
        switch self {
        case .god: "Gods"
        case .goddess: "Goddesses"
        case .angel: "Angels"
        case .archangel: "Archangels"
        case .prophet: "Prophets"
        case .spirit: "Spirits"
        case .jinn: "Jinn"
        case .demon: "Demons"
        case .fallenAngel: "Fallen angels"
        case .asura: "Asuras"
        case .rakshasa: "Rakshasas"
        case .other: "Other figures"
        }
    }
}

/// The primary browse destination a classification appears under.
///
/// Assigned per tradition-specific classification instead of being derived from
/// `EntityCategory`, because a category is not uniformly benevolent or
/// adversarial (for example, the Qur'an describes both believing and
/// disbelieving jinn), and one figure may be understood very differently by
/// different traditions.
enum EntityGroup: String, Codable, CaseIterable, Sendable {
    case divineAndCelestial
    case adversarial
    case other

    var title: String {
        switch self {
        case .divineAndCelestial: "Gods & Angels"
        case .adversarial: "Demons"
        case .other: "Other Figures"
        }
    }
}
