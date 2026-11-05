import XCTest
@testable import DivineAtlas

/// Editorial rules from docs/CONTENT_GUIDELINES.md that can be checked
/// mechanically against the bundled seed data.
final class ContentLintTests: XCTestCase {
    private var content: SeedContent!

    override func setUpWithError() throws {
        content = try SeedDataLoader.bundled(in: .main).load()
    }

    func testNoDirectQuotations() {
        // Wording must be paraphrase until a quotation has been checked
        // against a specific, cited translation.
        let quoteMarks = CharacterSet(charactersIn: "\"“”")
        for entity in content.entities {
            let texts = [entity.summary]
                + entity.classifications.flatMap { [$0.label, $0.explanation ?? ""] }
                + entity.relationships.map(\.explanation)
                + entity.sections.map(\.body)
            for text in texts where text.rangeOfCharacter(from: quoteMarks) != nil {
                XCTFail("\(entity.id) contains quotation marks: \(text.prefix(60))…")
            }
        }
    }

    func testSummariesAreShort() {
        for entity in content.entities {
            XCTAssertLessThanOrEqual(entity.summary.count, 160, "\(entity.id) summary is too long for a list card")
        }
    }

    func testAlternativeNamesAreDistinct() {
        for entity in content.entities {
            let names = entity.alternativeNames.map { $0.lowercased() }
            XCTAssertEqual(Set(names).count, names.count, "\(entity.id) repeats an alternative name")
            XCTAssertFalse(names.contains(entity.name.lowercased()), "\(entity.id) lists its own name as an alternative")
        }
    }

    func testRelationshipIDsArePrefixedWithTheirEntity() {
        for entity in content.entities {
            for relationship in entity.relationships {
                XCTAssertTrue(relationship.id.hasPrefix("\(entity.id)-"), "\(relationship.id) should start with \(entity.id)-")
            }
        }
    }

    func testEverySourceStatesItsEditionStatus() {
        for source in content.sources {
            XCTAssertFalse((source.notes ?? "").isEmpty, "\(source.id) has no notes on edition or numbering")
        }
    }

    func testEveryReligionHasEntriesAndSources() {
        for religion in content.religions {
            XCTAssertFalse(religion.sourceIDs.isEmpty, "\(religion.id) lists no sources")
            let overview = ReligionOverview(religion: religion, allEntities: content.entities, allSources: content.sources)
            XCTAssertFalse(overview.groups.isEmpty, "\(religion.id) has no entries")
        }
    }
}
