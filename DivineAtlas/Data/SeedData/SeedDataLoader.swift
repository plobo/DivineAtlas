import Foundation

/// The complete bundled dataset.
struct SeedContent: Equatable, Sendable {
    var religions: [Religion]
    var entities: [DivineEntity]
    var sources: [SourceReference]

    static let empty = SeedContent(religions: [], entities: [], sources: [])
}

/// On-disk envelope for every seed file, versioned so the schema can evolve.
struct SeedFile<Record: Decodable>: Decodable {
    let schemaVersion: Int
    let records: [Record]
}

/// Decodes and validates the bundled seed JSON.
struct SeedDataLoader: Sendable {
    static let supportedSchemaVersion = 1

    enum File: String, CaseIterable, Sendable {
        case religions
        case entities
        case sources

        var fileName: String { "\(rawValue).json" }
    }

    private let readData: @Sendable (File) throws -> Data

    init(readData: @escaping @Sendable (File) throws -> Data) {
        self.readData = readData
    }

    /// Reads seed files from the given bundle's resources.
    static func bundled(in bundle: Bundle = .main) -> SeedDataLoader {
        // Resolve URLs eagerly so the loader captures only Sendable values.
        let urls = Dictionary(uniqueKeysWithValues: File.allCases.map {
            ($0, bundle.url(forResource: $0.rawValue, withExtension: "json"))
        })
        return SeedDataLoader { file in
            guard let url = urls[file] ?? nil else { throw SeedDataError.missingFile(file.fileName) }
            return try Data(contentsOf: url)
        }
    }

    func load() throws -> SeedContent {
        let content = SeedContent(
            religions: try decode(.religions),
            entities: try decode(.entities),
            sources: try decode(.sources)
        )
        let issues = SeedDataValidator.validate(content)
        guard issues.isEmpty else { throw SeedDataError.validationFailed(issues) }
        return content
    }

    private func decode<Record: Decodable>(_ file: File) throws -> [Record] {
        let data: Data
        do {
            data = try readData(file)
        } catch let error as SeedDataError {
            throw error
        } catch {
            throw SeedDataError.unreadableFile(file.fileName, reason: error.localizedDescription)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope: SeedFile<Record>
        do {
            envelope = try decoder.decode(SeedFile<Record>.self, from: data)
        } catch {
            throw SeedDataError.decodingFailed(file.fileName, reason: Self.describe(error))
        }
        guard envelope.schemaVersion == Self.supportedSchemaVersion else {
            throw SeedDataError.unsupportedSchemaVersion(file.fileName, found: envelope.schemaVersion)
        }
        return envelope.records
    }

    /// Turns a `DecodingError` into a message that names the failing JSON path.
    private static func describe(_ error: any Error) -> String {
        func path(_ codingPath: [any CodingKey]) -> String {
            let components = codingPath.map { key in key.intValue.map { "[\($0)]" } ?? ".\(key.stringValue)" }
            return components.isEmpty ? "<root>" : components.joined()
        }
        guard let decodingError = error as? DecodingError else { return error.localizedDescription }
        switch decodingError {
        case .keyNotFound(let key, let context):
            return "Missing key '\(key.stringValue)' at \(path(context.codingPath))"
        case .typeMismatch(let type, let context):
            return "Type mismatch (expected \(type)) at \(path(context.codingPath)): \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "Missing value (expected \(type)) at \(path(context.codingPath))"
        case .dataCorrupted(let context):
            return "Invalid data at \(path(context.codingPath)): \(context.debugDescription)"
        @unknown default:
            return decodingError.localizedDescription
        }
    }
}

enum SeedDataError: Error, Equatable, LocalizedError {
    case missingFile(String)
    case unreadableFile(String, reason: String)
    case decodingFailed(String, reason: String)
    case unsupportedSchemaVersion(String, found: Int)
    case validationFailed([SeedValidationIssue])

    var errorDescription: String? {
        switch self {
        case .missingFile(let file):
            "Seed file \(file) is missing from the app bundle."
        case .unreadableFile(let file, let reason):
            "Seed file \(file) could not be read: \(reason)"
        case .decodingFailed(let file, let reason):
            "Seed file \(file) could not be decoded. \(reason)"
        case .unsupportedSchemaVersion(let file, let found):
            "Seed file \(file) has schema version \(found); expected \(SeedDataLoader.supportedSchemaVersion)."
        case .validationFailed(let issues):
            "Seed data failed validation:\n" + issues.map { "• \($0)" }.joined(separator: "\n")
        }
    }
}
