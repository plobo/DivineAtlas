import XCTest
@testable import DivineAtlas

final class SeedDataLoaderTests: XCTestCase {
    // MARK: Bundled data

    func testBundledSeedDataLoadsAndValidates() throws {
        let content = try SeedDataLoader.bundled(in: .main).load()

        XCTAssertEqual(Set(content.religions.map(\.id)), Set(TraditionID.allCases))
        XCTAssertFalse(content.entities.isEmpty)
        XCTAssertFalse(content.entities.filter { !$0.classifications(in: .divineAndCelestial).isEmpty }.isEmpty)
        XCTAssertFalse(content.entities.filter { !$0.classifications(in: .adversarial).isEmpty }.isEmpty)
    }

    func testBundledSeedDataMeetsContentTargets() throws {
        let content = try SeedDataLoader.bundled(in: .main).load()

        XCTAssertTrue((60...80).contains(content.entities.count), "Expected 60–80 entries, found \(content.entities.count)")
        for tradition in TraditionID.allCases {
            let count = content.entities.filter { $0.traditionIDs.contains(tradition) }.count
            XCTAssertGreaterThanOrEqual(count, 10, "\(tradition) has only \(count) entries")
        }
        XCTAssertFalse(content.entities.filter(\.isFeatured).isEmpty)
    }

    func testBundledEntriesAreDatedAndEveryClassificationIsCited() throws {
        let content = try SeedDataLoader.bundled(in: .main).load()
        for entity in content.entities {
            XCTAssertNotNil(entity.addedAt, "\(entity.id) has no addedAt")
            for classification in entity.classifications {
                XCTAssertFalse(classification.citations.isEmpty, "\(entity.id) / \(classification.traditionID) is uncited")
            }
        }
    }

    func testBundledSourcesAreAllUsed() throws {
        let content = try SeedDataLoader.bundled(in: .main).load()
        let cited = Set(content.entities.flatMap(\.allCitations).map(\.sourceID))
            .union(content.religions.flatMap(\.sourceIDs))
        XCTAssertEqual(Set(content.sources.map(\.id)).subtracting(cited), [])
    }

    func testBundledMediaIsLicenceReviewedAndAllowlisted() throws {
        // Images ship only after a person has approved the licence (see
        // docs/MEDIA_LICENSING.md). The validator enforces this too; this test
        // states the rule explicitly for the bundled data.
        let content = try SeedDataLoader.bundled(in: .main).load()
        for entity in content.entities {
            for asset in entity.imageAssets {
                XCTAssertNotNil(asset.reviewedAt, "\(asset.id) has not been licence-reviewed")
                XCTAssertTrue(MediaLicense.isAccepted(asset.license ?? ""), "\(asset.id) licence not accepted: \(asset.license ?? "none")")
                XCTAssertEqual(asset.sourceURL?.host(), "commons.wikimedia.org", "\(asset.id) should link to its Commons file page")
            }
            XCTAssertTrue(entity.videoLinks.isEmpty, "\(entity.id) has curated videos; none have been reviewed yet")
        }
    }

    func testDepictionPolicy() throws {
        // No image of the Prophet Muhammad (docs/CONTENT_GUIDELINES.md).
        let content = try SeedDataLoader.bundled(in: .main).load()
        let muhammad = try XCTUnwrap(content.entities.first { $0.id == "muhammad" })
        XCTAssertTrue(muhammad.imageAssets.isEmpty)
    }

    func testMediaLicenseAllowlist() {
        for accepted in ["Public domain", "PD-old-100", "CC0", "CC BY 4.0", "CC BY-SA 3.0", "CC BY-SA 2.5 in", "CC BY 2.0"] {
            XCTAssertTrue(MediaLicense.isAccepted(accepted), accepted)
        }
        for rejected in ["CC BY-NC 4.0", "CC BY-ND 4.0", "CC BY-NC-SA 3.0", "All rights reserved", "GFDL", "", "CC BY 1.0"] {
            XCTAssertFalse(MediaLicense.isAccepted(rejected), rejected)
        }
    }

    func testDecodesExtendedMediaFields() throws {
        let entities = """
        { "schemaVersion": 1, "records": [ {
            "id": "x", "name": "X", "summary": "S",
            "classifications": [ { "traditionID": "islam", "category": "angel", "group": "divineAndCelestial", "label": "Angel" } ],
            "imageAssets": [ {
                "id": "x-image", "url": "https://upload.wikimedia.org/a.jpg", "altText": "Alt",
                "creator": "Artist", "license": "CC BY-SA 4.0", "licenseURL": "https://creativecommons.org/licenses/by-sa/4.0",
                "sourceURL": "https://commons.wikimedia.org/wiki/File:A.jpg", "dateText": "c. 1900",
                "isArtisticReconstruction": false, "reviewedAt": "2026-11-04T00:00:00Z"
            } ]
        } ] }
        """
        let asset = try XCTUnwrap(loader(entities: entities).load().entities.first?.primaryImage)
        XCTAssertEqual(asset.dateText, "c. 1900")
        XCTAssertEqual(asset.licenseURL?.host(), "creativecommons.org")
        XCTAssertNotNil(asset.reviewedAt)
        XCTAssertEqual(asset.creditLine, "Artist, c. 1900 · CC BY-SA 4.0")
    }

    // MARK: Decoding

    func testOptionalCollectionsDefaultToEmpty() throws {
        let entities = """
        { "schemaVersion": 1, "records": [ {
            "id": "x", "name": "X", "summary": "S",
            "classifications": [ { "traditionID": "islam", "category": "angel", "group": "divineAndCelestial", "label": "Angel" } ]
        } ] }
        """
        let content = try loader(entities: entities).load()
        let entity = try XCTUnwrap(content.entities.first)
        XCTAssertEqual(entity.imageAssets, [])
        XCTAssertEqual(entity.videoLinks, [])
        XCTAssertEqual(entity.relationships, [])
        XCTAssertEqual(entity.alternativeNames, [])
        XCTAssertFalse(entity.isFeatured)
        XCTAssertEqual(entity.reviewStatus, .draft)
        XCTAssertNil(entity.primaryImage)
        XCTAssertNil(entity.addedAt)
    }

    func testDecodesAddedAtDate() throws {
        let entities = """
        { "schemaVersion": 1, "records": [ {
            "id": "x", "name": "X", "summary": "S", "addedAt": "2026-11-04T00:00:00Z",
            "classifications": [ { "traditionID": "islam", "category": "angel", "group": "divineAndCelestial", "label": "Angel" } ]
        } ] }
        """
        let entity = try XCTUnwrap(loader(entities: entities).load().entities.first)
        XCTAssertEqual(entity.addedAt, ISO8601DateFormatter().date(from: "2026-11-04T00:00:00Z"))
    }

    func testDecodingFailureNamesFileAndPath() {
        let entities = """
        { "schemaVersion": 1, "records": [ { "id": "x", "summary": "S", "classifications": [] } ] }
        """
        XCTAssertThrowsError(try loader(entities: entities).load()) { error in
            guard case .decodingFailed(let file, let reason) = error as? SeedDataError else {
                return XCTFail("Unexpected error \(error)")
            }
            XCTAssertEqual(file, "entities.json")
            XCTAssertTrue(reason.contains("name"), reason)
            XCTAssertTrue(reason.contains("records"), reason)
        }
    }

    func testUnknownCategoryFailsDecoding() {
        let entities = """
        { "schemaVersion": 1, "records": [ { "id": "x", "name": "X", "summary": "S",
          "classifications": [ { "traditionID": "islam", "category": "dragon", "group": "other", "label": "L" } ] } ] }
        """
        XCTAssertThrowsError(try loader(entities: entities).load()) { error in
            guard case .decodingFailed = error as? SeedDataError else { return XCTFail("Unexpected error \(error)") }
        }
    }

    func testUnsupportedSchemaVersion() {
        XCTAssertThrowsError(try loader(sources: #"{ "schemaVersion": 99, "records": [] }"#).load()) { error in
            XCTAssertEqual(error as? SeedDataError, .unsupportedSchemaVersion("sources.json", found: 99))
        }
    }

    func testMissingFile() {
        let loader = SeedDataLoader { file in throw SeedDataError.missingFile(file.fileName) }
        XCTAssertThrowsError(try loader.load()) { error in
            XCTAssertEqual(error as? SeedDataError, .missingFile("religions.json"))
        }
    }

    // MARK: Validation

    func testValidFixturesHaveNoIssues() {
        XCTAssertEqual(SeedDataValidator.validate(TestFixtures.content), [])
    }

    func testDetectsDuplicateEntityIDs() {
        var content = TestFixtures.content
        content.entities.append(TestFixtures.alpha)
        content.entities.append(TestFixtures.alpha)
        XCTAssertEqual(SeedDataValidator.validate(content), [.duplicateID(kind: "entity", id: "alpha")])
    }

    func testDetectsUnknownAndSelfRelationships() {
        var content = TestFixtures.content
        content.entities[0].relationships = [
            TestFixtures.relationship("r1", to: "missing"),
            TestFixtures.relationship("r2", to: "alpha"),
        ]
        XCTAssertEqual(SeedDataValidator.validate(content), [
            .unknownRelationshipTarget(entityID: "alpha", relationshipID: "r1", targetID: "missing"),
            .selfRelationship(entityID: "alpha", relationshipID: "r2"),
        ])
    }

    func testDetectsUnknownSources() {
        var content = TestFixtures.content
        content.entities[0].classifications[0].citations = [Citation(sourceID: "nope")]
        XCTAssertEqual(SeedDataValidator.validate(content), [.unknownSource(recordID: "alpha", sourceID: "nope")])
    }

    func testDetectsMissingReligionAndClassification() {
        var content = TestFixtures.content
        content.religions.removeAll { $0.id == .islam }
        content.entities.append(TestFixtures.entity("empty", classifications: []))
        XCTAssertEqual(SeedDataValidator.validate(content), [
            .missingReligion(.islam, referencedBy: "gamma"),
            .missingClassification(entityID: "empty"),
        ])
    }

    func testDetectsInsecureMediaURL() throws {
        var content = TestFixtures.content
        content.entities[0].imageAssets = [MediaAsset(
            id: "img", url: try XCTUnwrap(URL(string: "http://example.com/a.jpg")), altText: "Alt",
            creator: "Creator", license: "CC0", sourceURL: URL(string: "https://example.com/file"),
            isArtisticReconstruction: false, reviewedAt: Date()
        )]
        XCTAssertEqual(SeedDataValidator.validate(content), [.insecureURL(recordID: "img", url: "http://example.com/a.jpg")])
    }

    func testDetectsIncompleteMediaAttribution() throws {
        var content = TestFixtures.content
        content.entities[0].imageAssets = [MediaAsset(
            id: "img", url: try XCTUnwrap(URL(string: "https://example.com/a.jpg")), altText: "Alt",
            isArtisticReconstruction: false
        )]
        XCTAssertEqual(SeedDataValidator.validate(content), [
            .incompleteMediaAttribution(assetID: "img", missing: "license"),
            .unreviewedMedia(assetID: "img"),
            .incompleteMediaAttribution(assetID: "img", missing: "sourceURL"),
            .incompleteMediaAttribution(assetID: "img", missing: "creator or attributionText"),
        ])
    }

    func testRejectsNonFreeLicences() throws {
        var content = TestFixtures.content
        content.entities[0].imageAssets = [MediaAsset(
            id: "img", url: try XCTUnwrap(URL(string: "https://example.com/a.jpg")), altText: "Alt",
            creator: "Creator", license: "CC BY-NC 4.0", sourceURL: URL(string: "https://example.com/file"),
            isArtisticReconstruction: false, reviewedAt: Date()
        )]
        XCTAssertEqual(SeedDataValidator.validate(content), [.unacceptedLicense(assetID: "img", license: "CC BY-NC 4.0")])
    }

    func testDetectsUncitedClaims() {
        var content = TestFixtures.content
        content.entities[0].classifications[0].explanation = "An unsourced claim."
        content.entities[0].classifications[0].citations = []
        XCTAssertEqual(SeedDataValidator.validate(content), [.uncitedClaim(entityID: "alpha", traditionID: .judaism)])
    }

    func testDetectsDuplicateRelationshipIDs() {
        var content = TestFixtures.content
        content.entities[0].relationships.append(TestFixtures.relationship("alpha-beta", to: "beta"))
        XCTAssertEqual(SeedDataValidator.validate(content), [.duplicateRelationshipID(entityID: "alpha", relationshipID: "alpha-beta")])
    }

    func testValidationErrorIsThrownByLoader() {
        let entities = """
        { "schemaVersion": 1, "records": [ { "id": "x", "name": "X", "summary": "S",
          "classifications": [ { "traditionID": "islam", "category": "angel", "group": "other", "label": "L" } ],
          "relationships": [ { "id": "r", "relatedEntityID": "ghost", "relationshipType": "t", "explanation": "e" } ] } ] }
        """
        XCTAssertThrowsError(try loader(entities: entities).load()) { error in
            XCTAssertEqual(error as? SeedDataError, .validationFailed([
                .unknownRelationshipTarget(entityID: "x", relationshipID: "r", targetID: "ghost"),
            ]))
            XCTAssertTrue((error as? LocalizedError)?.errorDescription?.contains("ghost") == true)
        }
    }

    // MARK: Helpers

    private func loader(
        religions: String = SeedDataLoaderTests.religionsJSON,
        entities: String = #"{ "schemaVersion": 1, "records": [] }"#,
        sources: String = #"{ "schemaVersion": 1, "records": [] }"#
    ) -> SeedDataLoader {
        let files: [SeedDataLoader.File: String] = [.religions: religions, .entities: entities, .sources: sources]
        return SeedDataLoader { file in Data(files[file, default: ""].utf8) }
    }

    private static let religionsJSON = """
    { "schemaVersion": 1, "records": [
      { "id": "islam", "name": "Islam", "summary": "S", "introduction": "I", "interpretiveNote": "N", "sourceIDs": [] }
    ] }
    """
}
