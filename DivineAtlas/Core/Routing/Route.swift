import Foundation

/// Typed in-tab navigation destinations. Feature views push routes; the
/// composition root decides how to build each destination.
enum Route: Hashable, Sendable {
    case entity(id: String)
    case religion(TraditionID)
    case favorites
}
