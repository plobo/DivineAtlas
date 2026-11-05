import XCTest

@MainActor
final class TabShellUITests: XCTestCase {
    func testAppLaunchesWithFourTabs() {
        let app = XCUIApplication.launchClean()

        for title in ["Gods & Angels", "Demons", "Religions", "Discover"] {
            XCTAssertTrue(app.tabBars.buttons[title].waitForExistence(timeout: 5), "Missing tab \(title)")
        }
    }

    func testBrowseGodsAndAngelsAndOpenDetail() {
        let app = XCUIApplication.launchClean()
        XCTAssertTrue(app.element("entityRow.agni").waitForExistence(timeout: 5), "First alphabetical entry should be visible")

        app.search("Michael")
        let row = app.element("entityRow.michael")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        XCTAssertTrue(app.element("entityDetail.michael").waitForExistence(timeout: 5))
    }

    func testEntryWithoutArtworkShowsPlaceholder() {
        // Muhammad never has an image (depiction policy), so this stays
        // deterministic as artwork is added to other entries.
        let app = XCUIApplication.launchClean()
        app.tabBars.buttons["Discover"].tap()
        app.search("Muhammad")
        let row = app.element("entityRow.muhammad")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        XCTAssertTrue(app.element("entityDetail.muhammad").waitForExistence(timeout: 5))
        XCTAssertTrue(app.element("No artwork available for Muhammad").exists)
    }

    func testBrowseDemons() {
        let app = XCUIApplication.launchClean()

        app.tabBars.buttons["Demons"].tap()

        XCTAssertTrue(app.element("entityRow.asmodeus").waitForExistence(timeout: 5))
    }

    func testReligionLandingPage() {
        let app = XCUIApplication.launchClean()

        app.tabBars.buttons["Religions"].tap()
        let card = app.element("religionCard.islam")
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()

        XCTAssertTrue(app.element("entityRow.allah").waitForExistence(timeout: 5))
    }
}
