import Foundation
import OSLog

/// Maps internal errors to short messages suitable for display, while logging
/// the full diagnostic for developers.
enum UserFacingError {
    private static let logger = Logger(subsystem: "com.divineatlas.DivineAtlas", category: "Errors")

    static func message(for error: any Error, context: String) -> String {
        logger.error("\(context, privacy: .public): \(String(describing: error), privacy: .public)")
        switch error {
        case is SeedDataError:
            return "The app's built-in content could not be loaded. Please reinstall the app or contact support."
        default:
            return "Something went wrong. Please try again."
        }
    }
}
