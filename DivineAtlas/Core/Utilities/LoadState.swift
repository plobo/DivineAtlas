import Foundation

/// Async loading state for a screen. "Empty" is a `loaded` value with no
/// content and is decided by the view model, since emptiness is screen-specific.
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(message: String)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var isLoaded: Bool { value != nil }
}

extension LoadState: Equatable where Value: Equatable {}
extension LoadState: Sendable where Value: Sendable {}
