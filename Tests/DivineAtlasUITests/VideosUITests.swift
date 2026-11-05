import XCTest

/// Uses `-uiTestStubVideos`, so these tests never call the YouTube API.
@MainActor
final class VideosUITests: XCTestCase {
    func testDetailShowsStubbedYouTubeResultsAndFallback() {
        let app = XCUIApplication.launchClean(["-uiTestStubVideos"])
        app.openEntity("vishnu", searching: "Vishnu")

        let section = app.element("entityVideos")
        for _ in 0..<8 where !section.exists { app.swipeUp() }
        XCTAssertTrue(section.waitForExistence(timeout: 5), "Video section should appear when scrolled into view")

        let firstResult = app.element("videoResult.stub1")
        for _ in 0..<3 where !firstResult.isHittable { app.swipeUp() }
        XCTAssertTrue(firstResult.waitForExistence(timeout: 5))
        XCTAssertTrue(app.element("entityVideos.searchOnYouTube").exists)
    }

    func testWithoutVideoServiceOnlyFallbackIsShown() {
        // UI tests without the stub get no video service, like a build without an API key.
        let app = XCUIApplication.launchClean()
        app.openEntity("vishnu", searching: "Vishnu")

        let fallback = app.element("entityVideos.searchOnYouTube")
        for _ in 0..<8 where !fallback.exists { app.swipeUp() }
        XCTAssertTrue(fallback.waitForExistence(timeout: 5))
        XCTAssertTrue(app.element("entityVideos.unavailable").exists)
    }
}
