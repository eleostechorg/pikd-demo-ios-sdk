import XCTest

/// Opt-in real-host smoke check. Reads live tenant content; never presses Collect.
@MainActor final class LiveDeviceTests: XCTestCase {
    func testLiveHostMapProfileAndDirectARClose() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["PIKD_LIVE_DEVICE"] == "1" || env["TEST_RUNNER_PIKD_LIVE_DEVICE"] == "1" else {
            throw XCTSkip("Requires an authorized connected iPhone and private test configuration")
        }
        let app = XCUIApplication()
        app.launchArguments = ["--demo-locale", "en"]
        app.launch()
        XCTAssertTrue(app.buttons["demo-open-pikd"].waitForExistence(timeout: 15)); app.buttons["demo-open-pikd"].tap()
        XCTAssertTrue(app.buttons["experience-tab-ar"].waitForExistence(timeout: 30))
        let filter = app.buttons["explore.filter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 20)); filter.tap()
        XCTAssertTrue(app.buttons["Confirm"].waitForExistence(timeout: 5)); app.buttons["Confirm"].tap()
        app.buttons["explore.refresh"].tap(); app.buttons["explore.location"].tap()
        capture(app, "Live map controls")
        app.buttons["experience-tab-profile"].tap()
        XCTAssertTrue(app.buttons["cda-profile-other-tab"].waitForExistence(timeout: 15)); app.buttons["cda-profile-other-tab"].tap()
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 15))
        capture(app, "Live owned collectibles")
        for index in 0..<2 {
            app.buttons["experience-tab-ar"].tap()
            XCTAssertTrue(app.buttons["ar-close"].waitForExistence(timeout: 30))
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "ar-hud").firstMatch.waitForExistence(timeout: 40))
            capture(app, "Live direct AR \(index)")
            XCTAssertTrue(app.buttons["ar-collect"].waitForExistence(timeout: 20))
            let placed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: app.buttons["ar-collect"])
            XCTAssertEqual(XCTWaiter.wait(for: [placed], timeout: 60), .completed)
            XCTAssertFalse(app.staticTexts["Something went wrong. Please try again."].exists)
            XCTAssertFalse(app.buttons["ar-retry"].exists)
            app.buttons["ar-close"].tap()
            XCTAssertTrue(app.buttons["experience-tab-explore"].waitForExistence(timeout: 10))
        }
        app.buttons["experience-header-action"].tap()
        XCTAssertTrue(app.buttons["demo-open-pikd"].waitForExistence(timeout: 10))
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
}
