import XCTest

@MainActor
final class SearchAndFilterUITests: XCTestCase {
    func testFilterDemonsByTraditionAndReset() {
        let app = XCUIApplication.launchClean()
        app.tabBars.buttons["Demons"].tap()
        XCTAssertTrue(app.element("entityRow.asmodeus").waitForExistence(timeout: 5))

        app.element("filter.tradition.islam").tap()

        XCTAssertTrue(app.element("entityRow.iblis").waitForExistence(timeout: 5))
        XCTAssertFalse(app.element("entityRow.asmodeus").exists)
        XCTAssertTrue(app.element("filters.summary").exists)

        app.element("filters.reset").tap()

        XCTAssertTrue(app.element("entityRow.asmodeus").waitForExistence(timeout: 5))
        XCTAssertFalse(app.element("filters.summary").exists)
    }

    func testBrowseSearchShowsNoMatchesStateAndResets() {
        let app = XCUIApplication.launchClean()

        app.search("zzzz")

        XCTAssertTrue(app.element("state.empty").waitForExistence(timeout: 5))
        app.buttons["Reset Filters"].firstMatch.tap()

        XCTAssertTrue(app.element("entityRow.agni").waitForExistence(timeout: 5))
    }

    func testGlobalSearchFindsEntityByAlternativeName() {
        let app = XCUIApplication.launchClean()
        app.tabBars.buttons["Discover"].tap()

        app.search("Jibril")

        let row = app.element("entityRow.gabriel")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.element("entityDetail.gabriel").waitForExistence(timeout: 5))
    }

    func testRelatedEntityNavigation() {
        let app = XCUIApplication.launchClean()
        app.search("Durga")
        let row = app.element("entityRow.durga")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.element("entityDetail.durga").waitForExistence(timeout: 5))

        let related = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Mahishasura'")).firstMatch
        for _ in 0..<5 where !related.isHittable { app.swipeUp() }
        related.tap()

        XCTAssertTrue(app.element("entityDetail.mahishasura").waitForExistence(timeout: 5))
    }

    func testEmptyContentScenario() {
        let app = XCUIApplication.launchClean(["-uiTestEmptyContent"])

        XCTAssertTrue(app.element("state.empty").waitForExistence(timeout: 5))
    }

    func testFailingContentScenarioShowsErrorWithRetry() {
        let app = XCUIApplication.launchClean(["-uiTestFailingContent"])

        XCTAssertTrue(app.element("state.error").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Try Again"].exists)
    }
}
