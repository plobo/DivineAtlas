import XCTest

/// Automated accessibility audits (iOS 17+) of the main screens, at the
/// default text size and at the largest accessibility size. These complement,
/// but do not replace, the manual VoiceOver review in docs/QUALITY_REVIEW.md.
@MainActor
final class AccessibilityUITests: XCTestCase {
    private static let largestTextSize = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]

    func testAuditMainScreens() throws {
        let app = XCUIApplication.launchClean()
        try auditEachScreen(app)
    }

    func testAuditMainScreensAtLargestTextSize() throws {
        let app = XCUIApplication.launchClean(Self.largestTextSize)
        try auditEachScreen(app)
    }

    func testDetailScreenAtLargestTextSizeShowsKeyContent() {
        let app = XCUIApplication.launchClean(Self.largestTextSize)
        app.openEntity("michael", searching: "Michael")

        XCTAssertTrue(app.buttons["favoriteButton"].exists)
        XCTAssertTrue(app.staticTexts["Judaism"].exists)
    }

    private func auditEachScreen(_ app: XCUIApplication) throws {
        XCTAssertTrue(app.element("entityRow.agni").waitForExistence(timeout: 5))
        try audit(app, "Gods & Angels")

        app.tabBars.buttons["Demons"].tap()
        XCTAssertTrue(app.element("entityRow.asmodeus").waitForExistence(timeout: 5))
        try audit(app, "Demons")

        app.tabBars.buttons["Religions"].tap()
        XCTAssertTrue(app.element("religionCard.islam").waitForExistence(timeout: 5))
        try audit(app, "Religions")

        app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(app.staticTexts["FEATURED"].firstMatch.waitForExistence(timeout: 5) || app.staticTexts["Featured"].firstMatch.exists)
        try audit(app, "Discover")

        app.tabBars.buttons["Gods & Angels"].tap()
        app.openEntity("gabriel", searching: "Gabriel")
        try audit(app, "Entity detail")
    }

    private func audit(_ app: XCUIApplication, _ screen: String) throws {
        try app.performAccessibilityAudit { issue in
            // Issues without an element originate in system chrome we do not control.
            guard let element = issue.element else { return true }
            XCTContext.runActivity(named: "\(screen): \(issue.auditType) — \(issue.compactDescription) [\(element.identifier)]") { _ in }
            return false
        }
    }
}
