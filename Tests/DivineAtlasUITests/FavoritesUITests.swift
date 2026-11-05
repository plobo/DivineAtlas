import XCTest

@MainActor
final class FavoritesUITests: XCTestCase {
    func testAddAndRemoveFavoriteFromDetail() {
        let app = XCUIApplication.launchClean()
        app.openEntity("michael", searching: "Michael")

        let button = app.buttons["favoriteButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertEqual(button.label, "Add to Favorites")

        button.tap()
        XCTAssertEqual(button.label, "Remove from Favorites")

        button.tap()
        XCTAssertEqual(button.label, "Add to Favorites")
    }

    func testFavoritesPersistAcrossLaunchesAndAppearInDiscover() {
        let app = XCUIApplication.launchClean()
        app.openEntity("gabriel", searching: "Gabriel")
        app.buttons["favoriteButton"].tap()
        app.terminate()

        // Relaunch without resetting user data.
        let relaunched = XCUIApplication()
        relaunched.launch()
        relaunched.tabBars.buttons["Discover"].tap()

        XCTAssertTrue(relaunched.element("discover.favorites").waitForExistence(timeout: 5))
        relaunched.element("discover.seeAllFavorites").tap()
        XCTAssertTrue(relaunched.element("entityRow.gabriel").waitForExistence(timeout: 5))
    }

    func testFavoritesScreenEmptyState() {
        let app = XCUIApplication.launchClean()
        app.tabBars.buttons["Discover"].tap()
        app.element("discover.favoritesButton").tap()

        XCTAssertTrue(app.element("state.empty").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No Favorites Yet"].exists)
    }

    func testRecentlyViewedAppearsInDiscover() {
        let app = XCUIApplication.launchClean()
        app.openEntity("michael", searching: "Michael")

        app.tabBars.buttons["Discover"].tap()

        let section = app.element("discover.recentlyViewed")
        XCTAssertTrue(section.waitForExistence(timeout: 5))
        XCTAssertTrue(section.descendants(matching: .any)["entityRow.michael"].exists)
    }

    func testSelectedTabIsRestoredOnRelaunch() {
        let app = XCUIApplication.launchClean()
        app.tabBars.buttons["Religions"].tap()
        XCTAssertTrue(app.element("religionCard.islam").waitForExistence(timeout: 5))
        app.terminate()

        let relaunched = XCUIApplication()
        relaunched.launch()

        XCTAssertTrue(relaunched.element("religionCard.islam").waitForExistence(timeout: 5))
    }
}
