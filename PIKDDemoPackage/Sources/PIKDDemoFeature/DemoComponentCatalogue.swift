#if DEBUG
import SwiftUI
import PikdIOSCore
import PikdIOSUI
import PikdIOSAR
import PikdIOSExperience
import PikdIOSPartnerExperience

/// Secondary deterministic visual host. The normal entry remains the partner launch journey.
struct DemoComponentCatalogue: View {
    private let ids = ["RADAR", "SUCCESS", "COOLDOWN", "UNCONFIRMED", "OUTDATED", "LAUNCH", "TOAST", "CARD", "FAR_CARD", "CDA", "PERMISSION", "OWNED", "FILTER", "LONG"]
    @State private var selected = "RADAR"
    init() {
        let args = ProcessInfo.processInfo.arguments
        let name = args.firstIndex(of: "--demo-component").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } ?? "RADAR"
        _selected = State(initialValue: name)
        let locale = args.firstIndex(of: "--demo-component-locale").flatMap { args.indices.contains($0 + 1) ? PIKDStrings.Locale(rawValue: args[$0 + 1]) : nil } ?? .en
        strings = PIKDStrings(locale: locale)
    }
    private let theme = PIKDTheme()
    private let strings: PIKDStrings
    var body: some View {
        GeometryReader { _ in
            if selected == "LONG" { component.frame(maxWidth: .infinity, maxHeight: .infinity) }
            else { VStack(spacing: 0) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 4), spacing: 0) {
                    ForEach(ids, id: \.self) { id in Button(id) { selected = id }.font(.system(size: 11)).frame(height: 30).accessibilityIdentifier("show-" + id) }
                }.frame(height: 98.333)
                ZStack {
                    theme.background
                    component.id(selected)
                }.frame(height: 742).accessibilityElement(children: .contain).accessibilityIdentifier("capture-" + selected)
                Spacer(minLength: 0)
            }.frame(width: 402).background(theme.background) }
        }.overlay { if selected == "LAUNCH" { launchDialog } }.ignoresSafeArea().statusBarHidden(true).preferredColorScheme(.dark)
    }
    @ViewBuilder private var component: some View {
        switch selected {
        case "FILTER": DemoFilterPreview(theme: theme, strings: strings)
        case "RADAR":
            if let config = configuration { loading(configuration: config) }
        case "LONG": result(.collected, long: true)
        case "SUCCESS": result(.collected)
        case "COOLDOWN": result(.cooldown)
        case "UNCONFIRMED": result(.unconfirmed)
        case "OUTDATED": result(.outdated)
        case "LAUNCH": Color.clear
        case "TOAST": VStack { PIKDWarningToast(title: strings.text("ar.collectFailed"), description: strings.text("ar.genericError"), theme: theme) {}; Spacer() }
        case "CARD", "FAR_CARD":
            VStack { Spacer(); ExploreMarkerDetailCard(asset: .init(id: "reference", title: "Reference ARtefact", latitude: selected == "CARD" ? 24.4539 : 24.4549, longitude: 54.3773, points: 30), position: .init(latitude: 24.4539, longitude: 54.3773), theme: theme, strings: strings, onClose: {}, onGo: {}, onCollect: { _ in }).padding(.horizontal, 16).padding(.bottom, 40) }
        case "CDA":
            if let configuration { PIKDCdaProfileView(configuration: configuration, onOpenAsset: { _ in }, onExplore: {}) }
        case "OWNED":
            if let configuration, let repository = try? PIKDSDKProfileRepository(client: configuration.client, userRef: configuration.userRef) {
                MyCollectionsView(repository: repository, theme: theme, strings: strings, onOpenAsset: { _ in })
            }
        case "PERMISSION":
            if let configuration { permission(configuration: configuration) }
        default: EmptyView()
        }
    }
    private func loading(configuration supplied: PIKDExperienceConfiguration) -> some View {
        var config = supplied
        config.arSessionFactory = { DemoFixtureAR(scenario: "loading") }
        return PIKDExperienceARView(configuration: config, item: .init(id: "reference", title: "Reference ARtefact", latitude: 24.4539, longitude: 54.3773, iosUrl: "https://example.invalid/model.usdz"), mode: .collect, onClose: {}, onProfile: {}, onRefresh: {})
    }
    private var launchDialog: some View {
        PIKDLaunchDialog(title: "PIKD experience unavailable", message: "PIKD could not open right now. Please try again later.", close: strings.text("common.close"), theme: theme) { selected = "RADAR" }
    }
    private func permission(configuration supplied: PIKDExperienceConfiguration) -> some View {
        var configuration = supplied
        configuration.arSessionFactory = { DemoFixtureAR(scenario: "permission") }
        return PIKDExperienceARView(configuration: configuration, item: nil, mode: .nearby, onClose: {}, onProfile: {}, onRefresh: {})
    }
    private var configuration: PIKDExperienceConfiguration? {
        guard let value = try? PIKDConfiguration(baseURL: URL(string: "https://example.invalid/sdk/v1")!, sdkKey: "fixture", userRef: "fixture", contentLanguage: strings.locale.rawValue) else { return nil }
        return try? .init(client: PIKDClient(configuration: value, transport: DemoFixtureTransport(scenario: "success")), userRef: "fixture", contentLanguageRef: strings.locale.rawValue,
            ar: .init(userID: "fixture", apiBaseURL: value.baseURL, authToken: "fixture"), locationProvider: DemoFixtureLocation(), theme: theme, strings: strings)
    }
    private func result(_ outcome: PIKDCollectionOutcome, long: Bool = false) -> some View {
        let success = outcome == .collected
        let title = success ? "ar.itemCollected" : outcome == .unconfirmed ? "ar.collectUnconfirmed" : "ar.alreadyCollected"
        let description = success ? "ar.itemCollectedDescription" : outcome == .unconfirmed ? "ar.collectUnconfirmedDescription" : outcome == .outdated ? "error.outdatedAppVersion" : "ar.alreadyCollectedDescription"
        return PIKDResultOverlay(success: success, title: outcome == .outdated ? nil : strings.text(title), message: long ? String(repeating: "Reference message. ", count: 80) : strings.text(description),
            primary: strings.text(success ? "ar.goToProfile" : "common.close"), cancel: success ? strings.text("common.cancel") : nil, theme: theme, action: {}, onCancel: {})
    }
}
private struct DemoFilterPreview: View {
    let theme: PIKDTheme
    let strings: PIKDStrings
    @State private var presented = true
    var body: some View {
        theme.background.sheet(isPresented: $presented) {
            ExploreFilterSheet(sortBy: .all, endsIn: .d10, supportedSortBy: [.all], defaultEndsIn: .d10, theme: theme, strings: strings) { _, _ in }
        }
    }
}
#endif
