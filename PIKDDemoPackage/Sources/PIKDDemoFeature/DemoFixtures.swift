#if DEBUG
import SwiftUI
import PikdIOSCore
import PikdIOSUI
import PikdIOSAR
import PikdIOSExperience
import PikdIOSPartnerExperience

/// Explicit test mode only. The live launch never uses a fabricated tenant or position.
@MainActor enum DemoFixtures {
    static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("--demo-fixture") }
    static var scenario: String {
        let args = ProcessInfo.processInfo.arguments
        return args.firstIndex(of: "--demo-scenario").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } ?? "success"
    }
    static func configure(_ c: inout PIKDCdaConfiguration) {
        c.transport = DemoFixtureTransport(scenario: scenario)
        c.locationProvider = DemoFixtureLocation()
        c.arSessionFactory = { DemoFixtureAR(scenario: scenario) }
    }
}
@MainActor final class DemoFixtureLocation: PIKDExploreLocationProvider {
    func checkPermission() async -> PIKDLocationPermission { .granted }
    func requestPermission() async -> PIKDLocationPermission { .granted }
    func getCurrentLocation() async -> PIKDGeoPoint? { .init(latitude: 24.4539, longitude: 54.3773, accuracy: 3) }
    func getLastKnownLocation() -> PIKDGeoPoint? { .init(latitude: 24.4539, longitude: 54.3773, accuracy: 3) }
}
@MainActor @Observable final class DemoFixtureAR: PIKDARSession {
    let scenario: String
    var ready = false
    var placed = false
    var progress: Double?
    var error: String?
    var permissionDenied = false
    var onAssetTap: (() -> Void)?
    var rendersNativeSurface: Bool { false }
    init(scenario: String) { self.scenario = scenario }
    func open(url: URL?, configuration: ARPreviewConfiguration) async {
        if scenario == "permission" { permissionDenied = true; error = "denied"; return }
        if scenario == "ar-error" { error = "failed"; return }
        ready = true
        if scenario == "loading" { progress = 0.45; return }
        placed = url != nil
        if scenario == "tap", placed { Task { [weak self] in try? await Task.sleep(for: .milliseconds(100)); self?.onAssetTap?() } }
    }
    func selectModel(_ url: URL) {
        if scenario == "second-model-retry", url.lastPathComponent == "second.usdz" { placed = false; error = "Synthetic model failure" }
        else { placed = true }
    }
    func clearModel() { placed = false }
    func pause() {}
    func resume() {}
    func close() { ready = false; placed = false }
}
actor DemoFixtureTransport: PIKDTransport {
    let scenario: String
    var collected = false
    var nearbyReads = 0
    init(scenario: String) { self.scenario = scenario }
    func send(_ request: URLRequest) async throws -> PIKDResponse {
        try Task.checkCancellation()
        let path = request.url!.path
        let asset: [String: Any] = ["id": "demo-asset", "title": "Reference ARtefact", "latitude": scenario == "far" ? 24.4549 : 24.4539, "longitude": 54.3773,
                                   "iosUrl": "https://example.invalid/model.usdz", "points": 30]
        let value: Any
        var status = 200
        if path.hasSuffix("/auth/token") {
            value = ["opaqueUserId": "demo-user", "sessionToken": "fixture-session", "expiresAt": 2000000000]
        } else if path.hasSuffix("/collect") {
            if scenario == "unconfirmed" { status = 503; value = ["message": "fixture"] }
            else { collected = scenario != "cooldown"; value = ["collectibleId": "demo-asset", "status": collected ? "collected" : "cooldown", "message": scenario == "message" ? String(repeating: "Reference message. ", count: 80) : ""] }
        } else if path.hasSuffix("/nearby-within") {
            value = ["assets": collected ? [] : [asset], "page": 1, "pages": 1, "per_page": 100, "total_entries": collected ? 0 : 1]
        } else if path.hasSuffix("/nearby") {
            nearbyReads += 1
            if scenario == "nearby-retry", nearbyReads <= 3 { status = 503; value = ["message": "Synthetic transient discovery failure"] }
            else if scenario == "second-model-retry" {
                var second = asset; second["id"] = "second-asset"; second["iosUrl"] = "https://example.invalid/second.usdz"
                value = [asset, second]
            }
            else { value = collected || scenario == "empty" ? [] : [asset] }
        }
        else if path.hasSuffix("/challenges") {
            value = scenario == "launch-error" ? [] : [["id": "demo-challenge", "name": "CDA reference trail", "type": "item_collection", "isActive": true]]
        } else if path.contains("/challenges/") {
            value = ["id": "demo-challenge", "name": "CDA reference trail", "type": "item_collection", "isActive": true, "description": "Reference campaign"]
        } else if path.hasSuffix("/profile/me") {
            value = ["user": ["id": "demo-user", "username": "Demo partner"], "collectibles": collected ? 1 : 0, "points": collected ? 30 : 0,
                     "collectionsCount": collected ? 1 : 0, "collectionTimeSeconds": 90, "assetVisits": []]
        } else if path.hasSuffix("/inventory") {
            value = [["id": "owned-asset", "name": "Owned ARtefact", "imageUrl": Bundle.module.url(forResource: "InventoryFixture", withExtension: "png")!.absoluteString, "collectionId": "demo-challenge", "ios_url": "https://example.invalid/model.usdz", "points": 30]]
        } else if path.contains("/collections/") {
            value = ["id": "demo-challenge", "name": "CDA reference trail", "owned": 1, "total": 1]
        } else if path.hasSuffix("/leaderboard/me") { status = 404; value = [:] }
        else if path.contains("/leaderboard") { value = [] }
        else if path.contains("/telemetry/") { value = [:] }
        else { status = 404; value = [:] }
        return .init(data: try JSONSerialization.data(withJSONObject: value), status: status)
    }
}
#endif
