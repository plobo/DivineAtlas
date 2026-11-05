import XCTest

extension XCUIApplication {
    /// Launches with favorites, history, and preferences cleared, so tests do
    /// not depend on each other's state.
    static func launchClean(_ extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestResetUserData"] + extraArguments
        app.launch()
        return app
    }

    /// Opens an entity's detail screen from the Gods & Angels or Demons tab via search.
    func openEntity(_ id: String, searching text: String) {
        search(text)
        let row = element("entityRow.\(id)")
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Row \(id) not found")
        row.tap()
        XCTAssertTrue(element("entityDetail.\(id)").waitForExistence(timeout: 5))
    }

    func element(_ identifier: String) -> XCUIElement {
        descendants(matching: .any)[identifier].firstMatch
    }

    /// Types into the current screen's search field. Lists are lazy, so tests
    /// search for an entry instead of assuming it is on screen.
    func search(_ text: String) {
        let field = searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Search field not found")
        field.tap()
        field.typeText(text)
    }
}
