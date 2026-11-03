import SwiftUI
import GoogleMaps
import PikdIOSCore
import PikdIOSUI
import PikdIOSAR
import PikdIOSExperience
import PikdIOSPartnerExperience

/// An existing partner host app: SDK entry is an explicit launch action.
public struct DemoHostView: View {
    @State private var locale: PIKDStrings.Locale
    @State private var nickname = ""
    @State private var opening = false
    @State private var launch: DemoLaunch?
    @State private var error: String?
    @State private var work: Task<Void, Never>?
    private let values: [String: String]
    private var theme: PIKDTheme {
        var theme = PIKDTheme()
        theme.brandName = values["PIKD_PARTNER_ITEM_BRAND"] ?? values["PIKD_PARTNER_LABEL"] ?? "CDA"
        let primary = Color(red: 0.008, green: 0.604, blue: 0.647)
        theme.background = Color(red: 15/255, green: 15/255, blue: 16/255)
        theme.surface = Color(red: 26/255, green: 27/255, blue: 29/255)
        theme.colors.surfaceVariant = Color(red: 45/255, green: 47/255, blue: 50/255)
        theme.colors.border = theme.colors.surfaceVariant; theme.colors.navAccent = theme.colors.surfaceVariant
        theme.colors.glass = theme.colors.surfaceVariant.opacity(0.5)
        theme.secondaryText = Color(white: 0.6); theme.colors.textMuted = Color(white: 110/255)
        theme.colors.primary = primary; theme.colors.activeAccent = primary
        theme.colors.primaryGradient = [primary, primary]; theme.colors.onPrimary = theme.background
        theme.typography = .init(fontFamily: values["PIKD_FONT_FAMILY"] ?? "Manrope")
        if let json = values["PIKD_THEME"], let data = json.data(using: .utf8), let custom = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let colors = custom["colors"] as? [String: Any] ?? [:]
            let keys: [String: WritableKeyPath<PIKDColors, Color>] = ["primary": \.primary, "onPrimary": \.onPrimary, "background": \.background, "surface": \.surface, "surfaceVariant": \.surfaceVariant, "activeAccent": \.activeAccent, "glass": \.glass, "navAccent": \.navAccent, "mapSurface": \.mapSurface, "onMapSurface": \.onMapSurface, "textPrimary": \.textPrimary, "textSecondary": \.textSecondary, "textMuted": \.textMuted, "border": \.border, "success": \.success, "warning": \.warning, "error": \.error, "info": \.info, "rank1": \.rank1, "rank2": \.rank2, "rank3": \.rank3]
            for (name, path) in keys { if let raw = colors[name] as? String, let color = demoColor(raw) { theme.colors[keyPath: path] = color } }
            if let gradient = colors["primaryGradient"] as? [String] { let colors = gradient.compactMap(demoColor); if !colors.isEmpty { theme.colors.primaryGradient = colors } }
            if values["PIKD_FONT_FAMILY"] == nil, let family = (custom["typography"] as? [String: Any])?["fontFamily"] as? String { theme.typography = .init(fontFamily: family) }
        }
        return theme
    }
    private func demoColor(_ raw: String) -> Color? {
        let hex = raw.replacingOccurrences(of: "#", with: "")
        guard [6, 8].contains(hex.count), let value = UInt64(hex, radix: 16) else { return nil }
        let rgb = hex.count == 8 ? value >> 8 : value
        return Color(red: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255,
                     blue: Double(rgb & 255) / 255, opacity: hex.count == 8 ? Double(value & 255) / 255 : 1)
    }
    public init() {
        var values = DemoInputs.load()
        #if DEBUG
        if DemoFixtures.enabled {
            values["PIKD_BASE"] = "https://example.invalid/sdk/v1"; values["PIKD_SDK_KEY"] = "fixture-key"; values["PIKD_USER"] = "fixture-host"
            values["PIKD_LANGUAGE_REF"] = nil
            values["PIKD_DEMO_COLLECT_RADIUS_M"] = "5"
            values["PIKD_PARTNER_LABEL"] = "CDA"; values["PIKD_PARTNER_ITEM_BRAND"] = "CDA"; values["PIKD_PARTNER_APP_NAME"] = "CDA"
            values["PIKD_FONT_FAMILY"] = nil; values["PIKD_THEME"] = nil
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "--demo-locale"), args.indices.contains(i + 1) { values["PIKD_UI_LOCALE"] = args[i + 1] }
        }
        #endif
        self.values = values
        _locale = State(initialValue: PIKDStrings.Locale(rawValue: values["PIKD_UI_LOCALE"] ?? "en") ?? .en)
        if let key = values["PIKD_GOOGLE_MAPS_KEY"], !key.isEmpty { PIKDMapServices.configure(apiKey: key) }
    }
    public var body: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--demo-components") { DemoComponentCatalogue() }
        else { host }
        #else
        host
        #endif
    }
    private var host: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Spacer()
                        Picker(text("language"), selection: $locale) {
                            Text("English").tag(PIKDStrings.Locale.en)
                            Text("Русский").tag(PIKDStrings.Locale.ru)
                            Text("Қазақша").tag(PIKDStrings.Locale.kk)
                        }.accessibilityIdentifier("demo-language").disabled(opening).tint(theme.text)
                            .padding(.horizontal, 16).padding(.vertical, 8).background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.colors.border))
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(values["PIKD_PARTNER_LABEL"] ?? "CDA").font(theme.typography.font(.headingL)).foregroundStyle(theme.accent)
                        Text(text("welcomeTitle")).pikdTextStyle(.headingL, theme: theme).padding(.top, 20)
                        Text(text("experienceDescription")).pikdTextStyle(.bodyMuted, theme: theme).padding(.top, 8)
                        if missing.isEmpty {
                            Text(text("nicknameLabel")).pikdTextStyle(.label, theme: theme).padding(.top, 24)
                            TextField(text("nicknamePlaceholder"), text: $nickname).textInputAutocapitalization(.never).autocorrectionDisabled()
                                .padding(16).background(theme.background, in: RoundedRectangle(cornerRadius: 12)).padding(.top, 8)
                                .disabled(opening).accessibilityIdentifier("demo-nickname")
                            Button { open() } label: {
                                HStack { if opening { ProgressView() }; Text(text("openPikd")) }.frame(maxWidth: .infinity)
                            }.buttonStyle(PIKDActionButtonStyle(theme: theme)).padding(.top, 28).disabled(opening)
                                .accessibilityIdentifier("demo-open-pikd")
                        } else {
                            Text(text("configurationRequired")).pikdTextStyle(.headingM, theme: theme).padding(.top, 24)
                            Text(text("configurationDescription")).pikdTextStyle(.bodyMuted, theme: theme)
                            ForEach(missing, id: \.self) { Text($0).pikdTextStyle(.body, theme: theme) }
                        }
                    }.padding(28).background(theme.surface, in: RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(theme.colors.border))
                }.padding(24)
            }.background(theme.background).foregroundStyle(theme.text).navigationTitle(text("appTitle")).navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(theme.background, for: .navigationBar)
        }.preferredColorScheme(.dark)
            .fullScreenCover(item: $launch, onDismiss: cleanup) { route in
                PIKDCdaExperienceView(launch: route.value) {
                    launch = nil
                }
            }
            .overlay {
                if let error { PIKDLaunchDialog(title: text("experienceUnavailable"), message: error, close: text("close"), theme: theme) { self.error = nil } }
            }.onDisappear { if launch == nil { work?.cancel() } }

    }
    private var missing: [String] { ["PIKD_BASE", "PIKD_SDK_KEY", "PIKD_USER"].filter { values[$0]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false } }
    private func text(_ key: String) -> String {
        let url = Bundle.module.url(forResource: locale.rawValue, withExtension: "json")!
        let strings = (try? JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))) ?? [:]
        return (strings[key] ?? key).replacingOccurrences(of: "{{partner}}", with: values["PIKD_PARTNER_LABEL"] ?? "CDA")
    }
    private func open() {
        guard !opening, missing.isEmpty, let base = URL(string: values["PIKD_BASE"] ?? "") else { return }
        opening = true; error = nil
        work = Task { @MainActor in
            do {
                var config = PIKDCdaConfiguration(baseURL: base, sdkKey: values["PIKD_SDK_KEY"]!, userRef: values["PIKD_USER"]!,
                    locationProvider: PIKDDeviceLocationProvider(), locale: locale,
                    itemBrand: values["PIKD_PARTNER_ITEM_BRAND"] ?? values["PIKD_PARTNER_LABEL"] ?? "CDA",
                    appName: values["PIKD_PARTNER_APP_NAME"] ?? values["PIKD_PARTNER_LABEL"] ?? "CDA",
                    collectRadiusMeters: Double(values["PIKD_DEMO_COLLECT_RADIUS_M"] ?? "5") ?? .nan, theme: theme)
                config.email = values["PIKD_EMAIL"]; config.nickName = nickname
                config.contentLanguageRef = values["PIKD_LANGUAGE_REF"]
                #if DEBUG
                if DemoFixtures.enabled { DemoFixtures.configure(&config) }
                #endif
                let value = try await PIKDCdaExperience.prepare(config)
                guard !Task.isCancelled else { if case .ready(let c) = value { await c.client.invalidate() }; return }
                launch = .init(value: value); opening = false
            } catch is CancellationError { opening = false }
            catch {
                opening = false
                switch error {
                case PIKDPartnerLaunchError.noActiveChallenge, PIKDPartnerLaunchError.multipleActiveChallenges, PIKDPartnerLaunchError.unnamedActiveChallenge:
                    self.error = text("singleActiveChallengeRequired")
                default: self.error = text("tryAgainLater")
                }
            }
        }
    }
    private func cleanup() { work?.cancel(); work = nil; opening = false }
}
private struct DemoLaunch: Identifiable { let id = UUID(); let value: PIKDCdaLaunch }
private enum DemoInputs {
    static func load() -> [String: String] {
        guard let url = Bundle.main.url(forResource: "DemoConfiguration", withExtension: "json"),
              let data = try? Data(contentsOf: url), let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return raw.reduce(into: [:]) { result, pair in
            if let string = pair.value as? String { result[pair.key] = string }
            else if let number = pair.value as? NSNumber { result[pair.key] = number.stringValue }
            else if JSONSerialization.isValidJSONObject(pair.value), let data = try? JSONSerialization.data(withJSONObject: pair.value) { result[pair.key] = String(data: data, encoding: .utf8) }
        }
    }
}
