import XCTest

/// Captures README / App Store screenshots. Skipped in normal test runs; run with:
///
///     TEST_RUNNER_DIVINE_ATLAS_SCREENSHOTS=1 xcodebuild … test \
///       -only-testing:DivineAtlasUITests/ScreenshotUITests
///
/// Screenshots are kept as test attachments; export them with
/// `xcrun xcresulttool export attachments`.
@MainActor
final class ScreenshotUITests: XCTestCase {
    func testCaptureScreenshots() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["DIVINE_ATLAS_SCREENSHOTS"] == "1", "Screenshot capture only")

        let app = XCUIApplication.launchClean()
        XCTAssertTrue(app.element("entityRow.agni").waitForExistence(timeout: 10))
        waitForImages()
        capture(app, "01-gods-and-angels")

        app.openEntity("vishnu", searching: "Vishnu")
        waitForImages()
        capture(app, "02-entity-detail")
        app.swipeUp()
        capture(app, "03-entity-traditions")
        app.navigationBars.buttons.firstMatch.tap()

        app.tabBars.buttons["Demons"].tap()
        app.element("filter.tradition.hinduism").tap()
        waitForImages()
        capture(app, "04-demons-filtered")

        app.tabBars.buttons["Discover"].tap()
        waitForImages()
        capture(app, "06-discover")
    }

    /// Artwork downloads from Wikimedia on first view.
    private func waitForImages() {
        Thread.sleep(forTimeInterval: 4)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
