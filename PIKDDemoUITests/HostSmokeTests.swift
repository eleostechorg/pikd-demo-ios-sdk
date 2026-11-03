import XCTest

/// Run with the blank example configuration; no tenant or camera access required.
@MainActor final class HostSmokeTests: XCTestCase {
    func testMissingConfigurationShowsGuidance() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["PIKD_BASE"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["PIKD_SDK_KEY"].exists)
        XCTAssertTrue(app.staticTexts["PIKD_USER"].exists)
        XCTAssertFalse(app.buttons["demo-open-pikd"].exists)
    }

    func testHostLanguageSelection() {
        let app = XCUIApplication()
        app.launch()
        let language = app.buttons["demo-language"]
        XCTAssertTrue(language.waitForExistence(timeout: 15))
        language.tap()
        app.buttons["Русский"].tap()
        XCTAssertTrue(app.staticTexts["Требуется настройка"].waitForExistence(timeout: 5))
        language.tap()
        app.buttons["Қазақша"].tap()
        XCTAssertTrue(app.staticTexts["Конфигурация қажет"].waitForExistence(timeout: 5))
    }
}
