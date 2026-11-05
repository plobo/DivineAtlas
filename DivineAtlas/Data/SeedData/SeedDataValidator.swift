import Foundation

enum SeedValidationIssue: Equatable, Sendable, CustomStringConvertible {
    case duplicateID(kind: String, id: String)
    case emptyField(recordID: String, field: String)
    case missingClassification(entityID: String)
    case missingReligion(TraditionID, referencedBy: String)
    case unknownRelationshipTarget(entityID: String, relationshipID: String, targetID: String)
    case selfRelationship(entityID: String, relationshipID: String)
    case unknownSource(recordID: String, sourceID: String)
    case insecureURL(recordID: String, url: String)
    case uncitedClaim(entityID: String, traditionID: TraditionID)
    case incompleteMediaAttribution(assetID: String, missing: String)
    case duplicateRelationshipID(entityID: String, relationshipID: String)
    case unacceptedLicense(assetID: String, license: String)
    case unreviewedMedia(assetID: String)

    var description: String {
        switch self {
        case .duplicateID(let kind, let id):
            "Duplicate \(kind) ID '\(id)'"
        case .emptyField(let recordID, let field):
            "'\(recordID)' has an empty \(field)"
        case .missingClassification(let entityID):
            "Entity '\(entityID)' has no classifications"
        case .missingReligion(let tradition, let recordID):
            "'\(recordID)' references tradition '\(tradition.rawValue)', which has no religion record"
        case .unknownRelationshipTarget(let entityID, let relationshipID, let targetID):
            "Relationship '\(relationshipID)' on '\(entityID)' points to unknown entity '\(targetID)'"
        case .selfRelationship(let entityID, let relationshipID):
            "Relationship '\(relationshipID)' on '\(entityID)' points to itself"
        case .unknownSource(let recordID, let sourceID):
            "'\(recordID)' cites unknown source '\(sourceID)'"
        case .insecureURL(let recordID, let url):
            "'\(recordID)' contains a non-HTTPS URL: \(url)"
        case .uncitedClaim(let entityID, let traditionID):
            "'\(entityID)' has an explanation for \(traditionID.rawValue) with no citation"
        case .incompleteMediaAttribution(let assetID, let missing):
            "Media '\(assetID)' is missing \(missing)"
        case .duplicateRelationshipID(let entityID, let relationshipID):
            "'\(entityID)' has more than one relationship with ID '\(relationshipID)'"
        case .unacceptedLicense(let assetID, let license):
            "Media '\(assetID)' has a licence that is not accepted: \(license)"
        case .unreviewedMedia(let assetID):
            "Media '\(assetID)' has no reviewedAt date; images must be licence-reviewed before shipping"
        }
    }
}

/// Checks referential integrity and basic content rules for seed data.
/// Returns every issue found (in a deterministic order) rather than stopping
/// at the first, so content editors can fix a file in one pass.
enum SeedDataValidator {
    static func validate(_ content: SeedContent) -> [SeedValidationIssue] {
        var issues: [SeedValidationIssue] = []

        issues += duplicates(in: content.religions.map(\.id.rawValue), kind: "religion")
        issues += duplicates(in: content.entities.map(\.id), kind: "entity")
        issues += duplicates(in: content.sources.map(\.id), kind: "source")

        let entityIDs = Set(content.entities.map(\.id))
        let sourceIDs = Set(content.sources.map(\.id))
        let religionIDs = Set(content.religions.map(\.id))

        func checkCitations(_ citations: [Citation], recordID: String) {
            for citation in citations where !sourceIDs.contains(citation.sourceID) {
                issues.append(.unknownSource(recordID: recordID, sourceID: citation.sourceID))
            }
        }

        func checkURL(_ url: URL?, recordID: String) {
            guard let url, url.scheme?.lowercased() != "https" else { return }
            issues.append(.insecureURL(recordID: recordID, url: url.absoluteString))
        }

        for source in content.sources {
            if source.title.isBlank { issues.append(.emptyField(recordID: source.id, field: "title")) }
            checkURL(source.url, recordID: source.id)
        }

        for religion in content.religions {
            let recordID = religion.id.rawValue
            if religion.name.isBlank { issues.append(.emptyField(recordID: recordID, field: "name")) }
            if religion.introduction.isBlank { issues.append(.emptyField(recordID: recordID, field: "introduction")) }
            checkCitations(religion.sourceIDs.map { Citation(sourceID: $0) }, recordID: recordID)
        }

        for entity in content.entities {
            if entity.name.isBlank { issues.append(.emptyField(recordID: entity.id, field: "name")) }
            if entity.summary.isBlank { issues.append(.emptyField(recordID: entity.id, field: "summary")) }
            if entity.classifications.isEmpty { issues.append(.missingClassification(entityID: entity.id)) }

            for tradition in entity.traditionIDs where !religionIDs.contains(tradition) {
                issues.append(.missingReligion(tradition, referencedBy: entity.id))
            }
            for classification in entity.classifications {
                if classification.label.isBlank {
                    issues.append(.emptyField(recordID: entity.id, field: "classification label"))
                }
                // Explanations make claims, and claims must be traceable.
                if classification.explanation?.isBlank == false && classification.citations.isEmpty {
                    issues.append(.uncitedClaim(entityID: entity.id, traditionID: classification.traditionID))
                }
            }
            var relationshipIDs = Set<String>()
            for relationship in entity.relationships where !relationshipIDs.insert(relationship.id).inserted {
                issues.append(.duplicateRelationshipID(entityID: entity.id, relationshipID: relationship.id))
            }
            for relationship in entity.relationships {
                if relationship.relatedEntityID == entity.id {
                    issues.append(.selfRelationship(entityID: entity.id, relationshipID: relationship.id))
                } else if !entityIDs.contains(relationship.relatedEntityID) {
                    issues.append(.unknownRelationshipTarget(
                        entityID: entity.id,
                        relationshipID: relationship.id,
                        targetID: relationship.relatedEntityID
                    ))
                }
                if relationship.explanation.isBlank {
                    issues.append(.emptyField(recordID: relationship.id, field: "explanation"))
                }
            }
            checkCitations(entity.allCitations, recordID: entity.id)

            for asset in entity.imageAssets {
                checkURL(asset.url, recordID: asset.id)
                checkURL(asset.sourceURL, recordID: asset.id)
                if asset.altText.isBlank { issues.append(.emptyField(recordID: asset.id, field: "altText")) }
                if let license = asset.license, !license.isBlank {
                    if !MediaLicense.isAccepted(license) {
                        issues.append(.unacceptedLicense(assetID: asset.id, license: license))
                    }
                } else {
                    issues.append(.incompleteMediaAttribution(assetID: asset.id, missing: "license"))
                }
                if asset.reviewedAt == nil {
                    issues.append(.unreviewedMedia(assetID: asset.id))
                }
                checkURL(asset.licenseURL, recordID: asset.id)
                if asset.sourceURL == nil {
                    issues.append(.incompleteMediaAttribution(assetID: asset.id, missing: "sourceURL"))
                }
                if (asset.creator?.isBlank ?? true) && (asset.attributionText?.isBlank ?? true) {
                    issues.append(.incompleteMediaAttribution(assetID: asset.id, missing: "creator or attributionText"))
                }
            }
            for video in entity.videoLinks {
                if video.title.isBlank { issues.append(.emptyField(recordID: video.id, field: "title")) }
                if video.provider.isBlank { issues.append(.emptyField(recordID: video.id, field: "provider")) }
                checkURL(video.url, recordID: video.id)
                checkURL(video.thumbnailURL, recordID: video.id)
            }
        }

        return issues
    }

    private static func duplicates(in ids: [String], kind: String) -> [SeedValidationIssue] {
        var seen = Set<String>()
        var reported = Set<String>()
        return ids.compactMap { id in
            guard !seen.insert(id).inserted, reported.insert(id).inserted else { return nil }
            return .duplicateID(kind: kind, id: id)
        }
    }
}

private extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
