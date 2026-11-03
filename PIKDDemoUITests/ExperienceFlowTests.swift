import XCTest
import PikdIOSCore
import PikdIOSUI
import PikdIOSAR
import PikdIOSExperience
import PikdIOSPartnerExperience

@MainActor final class ExperienceStateTests: XCTestCase {
    func testCdaSessionAndEngineCredentialsAreSeparated() async throws {
        let transport = PartnerTransport()
        var input = PIKDCdaConfiguration(baseURL: URL(string: "https://example.invalid/sdk/v1")!, sdkKey: "host-sdk-key", userRef: "host-user", locationProvider: TestLocation(), locale: .kk, transport: transport)
        input.deviceInfo = .init(deviceId: "fixture-device", fcmToken: "must-not-send")
        guard case .ready(let configuration) = try await PIKDCdaExperience.prepare(input) else { return XCTFail("Expected ready") }
        XCTAssertEqual(configuration.ar.userID, "host-user"); XCTAssertEqual(configuration.ar.authToken, "host-sdk-key")
        XCTAssertEqual(configuration.ar.language, "kk"); XCTAssertEqual(configuration.client.configuration.sessionToken, "session-only")
        XCTAssertEqual(configuration.campaign?.showPrizes, false); XCTAssertEqual(configuration.campaign?.leaderboardTenantScope, true)
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 2); XCTAssertEqual(requests[1].value(forHTTPHeaderField: "x-pikd-session"), "session-only")
        let body = try JSONSerialization.jsonObject(with: requests[0].httpBody!) as! [String: Any]
        XCTAssertNil((body["deviceInfo"] as? [String: Any])?["fcmToken"])
    }
    func testGenericConfigurationRejectsMixedIdentityAndOversizedRadius() throws {
        let client = PIKDClient(configuration: try .init(baseURL: URL(string: "https://example.invalid/sdk/v1")!, sdkKey: "fixture", userRef: "A", contentLanguage: "en"))
        let ar = ARPreviewConfiguration(userID: "A", apiBaseURL: URL(string: "https://example.invalid/sdk/v1")!, authToken: "fixture")
        XCTAssertThrowsError(try PIKDExperienceConfiguration(client: client, userRef: "B", contentLanguageRef: "en", ar: ar, locationProvider: TestLocation()))
        XCTAssertThrowsError(try PIKDExperienceConfiguration(client: client, userRef: "A", contentLanguageRef: "kk", ar: ar, locationProvider: TestLocation()))
        XCTAssertThrowsError(try PIKDExperienceConfiguration(client: client, userRef: "A", contentLanguageRef: "en", ar: ar, locationProvider: TestLocation(), collectRadiusMeters: 1e30))
        XCTAssertEqual(PIKDFormatting.duration(90, strings: .init(locale: .en)), "1m 30s")
    }
    func testNavigationRefreshAndBack() {
        let state = PIKDExperienceNavigation()
        state.routes.append(.challenge("one")); state.routes.append(.comments("one"))
        XCTAssertTrue(state.back()); XCTAssertEqual(state.routes, [.challenge("one")])
        state.select(.leaderboard); XCTAssertTrue(state.routes.isEmpty); XCTAssertEqual(state.leaderboardRevision, 1)
        state.collected(); XCTAssertEqual(state.profileRevision, 1); XCTAssertEqual(state.mapRevision, 1)
        state.showProfile(); XCTAssertEqual(state.tab, .profile)
    }
    func testCollectionDeduplicatesAndRefreshesOnce() async throws {
        let repository = ControlledCollection()
        let state = PIKDCollectionState(); var refreshes = 0
        state.collect(id: "item", repository: repository) { refreshes += 1 }
        state.collect(id: "item", repository: repository) { refreshes += 1 }
        try await Task.sleep(for: .milliseconds(150))
        let count = await repository.calls
        XCTAssertEqual(count, 1); XCTAssertEqual(refreshes, 1); XCTAssertEqual(state.result?.outcome, .collected)
    }
    func testCancelledCollectionCannotPublishOrRefresh() async throws {
        let state = PIKDCollectionState(); var refreshes = 0
        state.collect(id: "item", repository: ControlledCollection()) { refreshes += 1 }; state.cancel()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertNil(state.result); XCTAssertEqual(refreshes, 0)
    }
    func testAllSupportedLocalesHaveOutcomeAndLoadingCopy() {
        for locale in [PIKDStrings.Locale.en, .ru, .kk] {
            let s = PIKDStrings(locale: locale)
            for key in ["ar.itemCollected", "ar.collectUnconfirmed", "ar.alreadyCollected", "ar.preparingAr", "ar.cameraDescription", "error.outdatedAppVersion"] {
                XCTAssertNotEqual(s.text(key), key)
            }
            XCTAssertFalse(s.text("ar.loadingAssets", arguments: ["percent": "45"]).contains("{{"))
        }
    }
    func testCollectionUsesMeasuredLocationAndIntentAndDoesNotReplay() async throws {
        let transport = RecordingTransport(status: 503)
        let client = PIKDClient(configuration: try .init(baseURL: URL(string: "https://example.invalid/sdk/v1")!, sdkKey: "fixture", userRef: "host", maxGetRetries: 2), transport: transport)
        let repository = PIKDSDKCollectionRepository(client: client, userRef: "host", languageRef: "kk", location: { .init(latitude: 24, longitude: 54, accuracy: 3) })
        let result = try await repository.collect(id: "item", intentID: "intent-once")
        XCTAssertEqual(result.outcome, .unconfirmed)
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1); XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Idempotency-Key"), "intent-once")
        let body = try JSONSerialization.jsonObject(with: requests[0].httpBody!) as! [String: Any]
        XCTAssertEqual(body["accuracy"] as? Double, 3); XCTAssertEqual(body["languageRef"] as? String, "kk")
    }
    func testMissingMeasuredLocationDoesNotSubmit() async throws {
        let transport = RecordingTransport(status: 200)
        let client = PIKDClient(configuration: try .init(baseURL: URL(string: "https://example.invalid/sdk/v1")!, sdkKey: "fixture"), transport: transport)
        let result = try await PIKDSDKCollectionRepository(client: client, userRef: "host", languageRef: "en", location: { nil }).collect(id: "item", intentID: "once")
        XCTAssertEqual(result.outcome, .unconfirmed); let count = await transport.requests.count; XCTAssertEqual(count, 0)
    }
}
private actor ControlledCollection: PIKDCollectionRepository {
    var calls = 0
    func collect(id: String, intentID: String) async throws -> PIKDCollectionResult {
        calls += 1; try? await Task.sleep(for: .milliseconds(50)); return .init(.collected)
    }
}
private actor RecordingTransport: PIKDTransport {
    let status: Int
    var requests: [URLRequest] = []
    init(status: Int) { self.status = status }
    func send(_ request: URLRequest) async throws -> PIKDResponse {
        requests.append(request); return .init(data: Data("{}".utf8), status: status)
    }
}

@MainActor final class DemoJourneyTests: XCTestCase {
    private func open(_ scenario: String = "success", locale: String = "en", largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--demo-fixture", "--demo-scenario", scenario, "--demo-locale", locale]
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch(); XCTAssertTrue(app.buttons["demo-open-pikd"].waitForExistence(timeout: 10)); app.buttons["demo-open-pikd"].tap()
        return app
    }
    func testPartnerLaunchFiveTabsDashboardAndHostReturn() {
        let app = open()
        XCTAssertTrue(app.buttons["experience-tab-profile"].waitForExistence(timeout: 15)); app.buttons["experience-tab-profile"].tap()
        XCTAssertTrue(app.scrollViews["cda-dashboard"].waitForExistence(timeout: 10))
        app.buttons["experience-tab-challenges"].tap(); app.buttons["experience-tab-leaderboard"].tap()
        app.buttons["experience-header-action"].tap()
        XCTAssertTrue(app.buttons["demo-open-pikd"].waitForExistence(timeout: 5))
    }
    func testNearbyARCollectionSuccessThenProfile() {
        let app = open(); XCTAssertTrue(app.buttons["experience-tab-ar"].waitForExistence(timeout: 15)); app.buttons["experience-tab-ar"].tap()
        XCTAssertTrue(app.buttons["ar-collect"].waitForExistence(timeout: 10)); app.buttons["ar-collect"].tap()
        XCTAssertTrue(app.buttons["ar-result-primary"].waitForExistence(timeout: 5)); app.buttons["ar-result-primary"].tap()
        XCTAssertTrue(app.scrollViews["cda-dashboard"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["cda-stat-collected"].label, "1")
    }
    func testDirectARTabCloseReturnsToMapAndCanReopen() {
        let app = open()
        for _ in 0..<2 {
            XCTAssertTrue(app.buttons["experience-tab-ar"].waitForExistence(timeout: 15)); app.buttons["experience-tab-ar"].tap()
            XCTAssertTrue(app.buttons["ar-collect"].waitForExistence(timeout: 10))
            app.buttons["ar-close"].tap()
            XCTAssertTrue(app.buttons["experience-tab-explore"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["demo-open-pikd"].isHittable)
        }
    }
    func testFailedPinnedNearbySearchCanRetryWithoutClosingAR() {
        let app = open("nearby-retry")
        let marker = app.buttons.matching(NSPredicate(format: "label == %@", "Reference ARtefact")).firstMatch
        XCTAssertTrue(marker.waitForExistence(timeout: 15)); marker.tap()
        XCTAssertTrue(app.buttons["explore-collect"].waitForExistence(timeout: 5)); app.buttons["explore-collect"].tap()
        XCTAssertTrue(app.buttons["ar-search-nearby"].waitForExistence(timeout: 10)); app.buttons["ar-search-nearby"].tap()
        XCTAssertTrue(app.buttons["ar-search-empty"].waitForExistence(timeout: 10))
        let retry = app.buttons["ar-search-empty"]
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: retry)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 10), .completed)
        retry.tap()
        XCTAssertTrue(app.buttons["ar-collect"].waitForExistence(timeout: 10)); XCTAssertTrue(app.buttons["ar-collect"].isEnabled)
        app.buttons["ar-close"].tap()
        XCTAssertTrue(app.buttons["experience-tab-explore"].waitForExistence(timeout: 5))
    }
    func testPinnedNativeRetryResetsSecondNearbySelection() {
        let app = open("second-model-retry")
        let marker = app.buttons.matching(NSPredicate(format: "label == %@", "Reference ARtefact")).firstMatch
        XCTAssertTrue(marker.waitForExistence(timeout: 15)); marker.tap()
        XCTAssertTrue(app.buttons["explore-collect"].waitForExistence(timeout: 5)); app.buttons["explore-collect"].tap()
        XCTAssertTrue(app.buttons["ar-search-nearby"].waitForExistence(timeout: 10)); app.buttons["ar-search-nearby"].tap()
        let next = app.buttons["Available: 2 · 2/2"]
        XCTAssertTrue(next.waitForExistence(timeout: 10)); next.tap()
        XCTAssertTrue(app.buttons["ar-retry"].waitForExistence(timeout: 5)); app.buttons["ar-retry"].tap()
        XCTAssertTrue(app.buttons["ar-collect"].waitForExistence(timeout: 10)); XCTAssertTrue(app.buttons["ar-collect"].isEnabled)
        XCTAssertTrue(app.staticTexts["1 asset"].exists)
        XCTAssertFalse(next.exists)
        app.buttons["ar-close"].tap()
        XCTAssertTrue(app.buttons["experience-tab-explore"].waitForExistence(timeout: 5))
    }
    func testEmptyNearbyARShowsZeroWithoutInvalidPositionAndCloses() {
        let app = open("empty")
        XCTAssertTrue(app.buttons["experience-tab-ar"].waitForExistence(timeout: 15)); app.buttons["experience-tab-ar"].tap()
        XCTAssertTrue(app.staticTexts["Available: 0"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Available: 0 · 1/0"].exists)
        XCTAssertTrue(app.buttons["ar-search-empty"].exists)
        app.buttons["ar-close"].tap()
        XCTAssertTrue(app.buttons["experience-tab-explore"].waitForExistence(timeout: 5))
    }
    func testMapControlsOpenFilterRefreshAndRecenter() {
        let app = open()
        let filter = app.buttons["explore.filter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 15)); XCTAssertTrue(filter.isHittable); filter.tap()
        XCTAssertTrue(app.buttons["Confirm"].waitForExistence(timeout: 5))
        let clear = app.buttons["Clear all"], confirm = app.buttons["Confirm"]
        XCTAssertEqual(clear.frame.width, confirm.frame.width, accuracy: 1)
        XCTAssertEqual(clear.frame.minY, confirm.frame.minY, accuracy: 1)
        XCTAssertEqual(clear.frame.minX, app.buttons["All"].frame.minX, accuracy: 1)
        XCTAssertLessThan(app.scrollViews["explore-filter-sheet"].frame.height, app.frame.height * 0.5)
        confirm.tap()
        XCTAssertTrue(app.buttons["explore.refresh"].waitForExistence(timeout: 5)); app.buttons["explore.refresh"].tap()
        XCTAssertTrue(app.buttons["explore.location"].waitForExistence(timeout: 5)); app.buttons["explore.location"].tap()
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
    }
    func testCdaLaunchFailureUsesDialogAndStaysInHost() {
        let app = open("launch-error")
        XCTAssertTrue(app.otherElements["partner-launch-dialog"].waitForExistence(timeout: 10)); XCTAssertFalse(app.buttons["experience-tab-ar"].exists)
    }
    func testMapMarkerOpensCardThenCollectsDirectly() {
        let app = open()
        let marker = app.buttons.matching(NSPredicate(format: "label == %@", "Reference ARtefact")).firstMatch
        XCTAssertTrue(marker.waitForExistence(timeout: 15)); marker.tap()
        XCTAssertTrue(app.buttons["explore-collect"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["asset-view-ar"].exists)
        app.buttons["explore-collect"].tap()
        XCTAssertTrue(app.buttons["ar-collect"].waitForExistence(timeout: 10)); app.buttons["ar-collect"].tap()
        XCTAssertTrue(app.buttons["ar-result-primary"].waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Map collection result"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["ar-result-cancel"].tap()
        XCTAssertTrue(app.buttons["experience-tab-profile"].waitForExistence(timeout: 10))
    }
    func testFarMarkerGoKeepsMapAndDoesNotOpenAssetDetail() {
        let app = open("far")
        let marker = app.buttons.matching(NSPredicate(format: "label == %@", "Reference ARtefact")).firstMatch
        XCTAssertTrue(marker.waitForExistence(timeout: 15)); marker.tap()
        XCTAssertTrue(app.buttons["explore-go"].waitForExistence(timeout: 5)); XCTAssertFalse(app.buttons["explore-collect"].exists)
        app.buttons["explore-go"].tap(); XCTAssertFalse(app.buttons["asset-view-ar"].exists)
        XCTAssertTrue(app.buttons["experience-tab-profile"].exists)
    }
    func testOwnedPreviewAndBackRetainsCollectiblesTab() {
        let app = open("tap"); XCTAssertTrue(app.buttons["experience-tab-profile"].waitForExistence(timeout: 15)); app.buttons["experience-tab-profile"].tap()
        app.buttons["cda-profile-other-tab"].tap()
        let tile = app.buttons["owned-asset-owned-asset-0"]
        XCTAssertTrue(tile.waitForExistence(timeout: 10)); XCTAssertFalse(app.buttons["profile-sort"].exists); tile.tap()
        XCTAssertFalse(app.buttons["experience-tab-ar"].exists)
                XCTAssertTrue(app.buttons["asset-view-ar"].waitForExistence(timeout: 5)); app.buttons["asset-view-ar"].tap()
        XCTAssertTrue(app.buttons["ar-close"].waitForExistence(timeout: 10)); XCTAssertFalse(app.buttons["ar-collect"].exists)
        XCTAssertFalse(app.buttons["ar-result-primary"].waitForExistence(timeout: 1))
        app.buttons["ar-close"].tap(); XCTAssertTrue(app.buttons["asset-view-ar"].waitForExistence(timeout: 5))
        app.buttons["experience-header-action"].tap()
        XCTAssertTrue(tile.waitForExistence(timeout: 5)); XCTAssertFalse(app.scrollViews["cda-dashboard"].isHittable)
    }
    func testCooldownAndUnconfirmedResultDialogs() {
        for scenario in ["cooldown", "unconfirmed"] {
            let app = open(scenario)
            XCTAssertTrue(app.buttons["experience-tab-ar"].waitForExistence(timeout: 15)); app.buttons["experience-tab-ar"].tap()
            XCTAssertTrue(app.buttons["ar-collect"].waitForExistence(timeout: 10)); app.buttons["ar-collect"].tap()
            XCTAssertTrue(app.buttons["ar-result-primary"].waitForExistence(timeout: 5)); app.buttons["ar-result-primary"].tap()
            XCTAssertEqual(app.buttons["ar-collect"].isEnabled, scenario == "cooldown")
            app.terminate()
        }
    }
    func testCameraDenialHasSettingsRetryAndSafeHostReturn() {
        let app = open("permission"); XCTAssertTrue(app.buttons["experience-tab-ar"].waitForExistence(timeout: 15)); app.buttons["experience-tab-ar"].tap()
        XCTAssertTrue(app.buttons["ar-retry"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["ar-secondary"].exists); app.buttons["ar-close"].tap()
        XCTAssertTrue(app.buttons["experience-tab-explore"].waitForExistence(timeout: 5))
    }
    func testLongCollectionMessageKeepsActionsVisibleInSupportedLocales() {
        for locale in ["en", "ru", "kk"] {
            let app = open("message", locale: locale)
            XCTAssertTrue(app.buttons["experience-tab-ar"].waitForExistence(timeout: 15)); app.buttons["experience-tab-ar"].tap()
            XCTAssertTrue(app.buttons["ar-collect"].waitForExistence(timeout: 10)); app.buttons["ar-collect"].tap()
            let primary = app.buttons["ar-result-primary"]
            XCTAssertTrue(primary.waitForExistence(timeout: 5)); XCTAssertTrue(primary.isHittable)
            let cancel = app.buttons["ar-result-cancel"]
            let usable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: cancel)
            let ready = XCTWaiter.wait(for: [usable], timeout: 5)
            if ready != .completed {
                let info = XCTAttachment(string: cancel.debugDescription + "\n" + app.debugDescription); info.name = "Long result hit regions " + locale; info.lifetime = .keepAlways; add(info)
            }
            XCTAssertEqual(ready, .completed)
            let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Long collection message " + locale; shot.lifetime = .keepAlways; add(shot)
            if locale == "en" {
                cancel.tap(); XCTAssertTrue(app.buttons["experience-tab-explore"].waitForExistence(timeout: 10))
            } else {
                primary.tap(); XCTAssertTrue(app.scrollViews["cda-dashboard"].waitForExistence(timeout: 10))
            }
            app.terminate()
        }
    }
    func testLongCollectionMessageWithAccessibilityTextKeepsActionsReachable() {
        let app = open("message", largeText: true)
        XCTAssertTrue(app.buttons["experience-tab-ar"].waitForExistence(timeout: 15)); app.buttons["experience-tab-ar"].tap()
        XCTAssertTrue(app.buttons["ar-collect"].waitForExistence(timeout: 10)); app.buttons["ar-collect"].tap()
        XCTAssertTrue(app.buttons["ar-result-primary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ar-result-primary"].isHittable)
        XCTAssertTrue(app.buttons["ar-result-cancel"].isHittable)
        let content = app.scrollViews["ar-result-content"]
        XCTAssertTrue(content.exists); XCTAssertGreaterThan(content.frame.height, 100)
        content.swipeUp()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Reference message.")).firstMatch.exists)
        XCTAssertTrue(app.buttons["ar-result-primary"].isHittable); XCTAssertTrue(app.buttons["ar-result-cancel"].isHittable)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Long result accessibility text"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["ar-result-cancel"].tap()
        XCTAssertTrue(app.buttons["experience-tab-explore"].waitForExistence(timeout: 10))
    }
    func testRussianAndKazakhPartnerLaunch() {
        for locale in ["ru", "kk"] {
            let app = open(locale: locale)
            XCTAssertTrue(app.buttons["experience-tab-profile"].waitForExistence(timeout: 15))
            app.buttons["experience-tab-profile"].tap(); XCTAssertTrue(app.scrollViews["cda-dashboard"].waitForExistence(timeout: 5))
            let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "CDA dashboard \(locale)"; shot.lifetime = .keepAlways; add(shot)
            app.terminate()
        }
    }
}

@MainActor private final class TestLocation: PIKDExploreLocationProvider {
    func checkPermission() async -> PIKDLocationPermission { .granted }
    func requestPermission() async -> PIKDLocationPermission { .granted }
    func getCurrentLocation() async -> PIKDGeoPoint? { .init(latitude: 24, longitude: 54) }
}
private actor PartnerTransport: PIKDTransport {
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> PIKDResponse {
        requests.append(request)
        let json = request.url!.path.hasSuffix("/auth/token")
            ? "{\"opaqueUserId\":\"opaque-user\",\"sessionToken\":\"session-only\",\"expiresAt\":2000000000}"
            : "[{\"id\":\"campaign\",\"name\":\"CDA fixture\",\"type\":\"item_collection\",\"isActive\":true}]"
        return .init(data: Data(json.utf8), status: 200)
    }
}
