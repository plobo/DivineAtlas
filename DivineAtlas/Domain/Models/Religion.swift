import Foundation

/// Landing-page content for a tradition.
struct Religion: Identifiable, Codable, Hashable, Sendable {
    let id: TraditionID
    var name: String
    var summary: String
    var introduction: String
    /// Explains that beliefs and interpretations vary within the tradition.
    var interpretiveNote: String
    var sourceIDs: [String]
}

extension Array where Element == Religion {
    /// Sorted in the declaration order of `TraditionID`, for a stable display order.
    func sortedByTraditionOrder() -> [Religion] {
        let order = TraditionID.allCases
        return sorted { (order.firstIndex(of: $0.id) ?? 0) < (order.firstIndex(of: $1.id) ?? 0) }
    }
}
