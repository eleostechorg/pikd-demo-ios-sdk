# Integrating PIKD into an existing iOS app

Your app keeps its login, navigation and entry button. Supply the signed-in user and tenant configuration, prepare the PIKD launch, present its view, and dismiss it when the user closes PIKD. This guide uses the CDA partner experience shown in the public demo.

## 1. Choose and install the SDK products

Install **0.8.0-beta.15** from:

```text
https://github.com/eleostechorg/pikd-ios-sdk-distribution.git
```

In Xcode choose **File → Add Package Dependencies**, select that exact version, then add the products your target uses. For the SwiftUI sample below, select `PikdIOSPartnerExperience` and `PikdIOSUI`. Their SDK dependencies resolve automatically.

| Product | Use it for |
|---|---|
| `PikdIOSCore` | Typed SDK API/session calls with your own UI |
| `PikdIOSUI` | Individual prebuilt screens in your navigation |
| `PikdIOSAR` | Native AR view/session integration |
| `PikdIOSExperience` | The generic complete five-tab experience |
| `PikdIOSPartnerExperience` | CDA campaign preparation, presentation and Dashboard/Collectibles composition |

Keep the same SDK version across all selected products. CocoaPods installation is also available in the [SDK README](https://github.com/eleostechorg/pikd-ios-sdk-distribution#cocoapods).

Use Xcode 27.1 / Swift 6.4 for the current compiled release, target iOS 18+, and use an ARKit-capable physical iPhone for camera collection. See [demo local setup](https://github.com/eleostechorg/pikd-demo-ios-sdk/blob/main/docs/LOCAL_SETUP.md) to run the reference app first.

## 2. Configure Maps and permissions

Enable Maps SDK for iOS and restrict your key to your app's bundle identifier. Configure Maps once, before presenting an Explore map:

```swift
import PikdIOSUI

// Call on the main actor during your app's startup, using your own configuration.
PIKDMapServices.configure(apiKey: googleMapsAPIKey)
```

Add these keys to your app target's Info.plist (or the equivalent generated Info.plist build settings), using descriptions appropriate to your app:

```xml
<key>NSCameraUsageDescription</key>
<string>Use the camera to view and collect PIKD objects in augmented reality.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Use your location to find nearby PIKD objects and check collection range.</string>
```

Localize permission descriptions through your app's `InfoPlist.strings`. For a complete reference see the demo's [configuration](https://github.com/eleostechorg/pikd-demo-ios-sdk/tree/main/Config) and [app language resources](https://github.com/eleostechorg/pikd-demo-ios-sdk/tree/main/PIKDDemo). The SDK includes `PIKDDeviceLocationProvider`; supply your own `PIKDExploreLocationProvider` if your app already owns location services.

## 3. Present from an existing SwiftUI screen

Add this view to your app and place `PIKDEntryButton` inside your existing signed-in screen. Its inputs come from your app; no tenant credentials are hardcoded in the example.

<!-- compile:swiftui-entry -->
```swift
import SwiftUI
import PikdIOSUI
import PikdIOSPartnerExperience

@MainActor
struct PIKDEntryButton: View {
    let baseURL: URL
    let sdkKey: String
    let userRef: String
    var locale: PIKDStrings.Locale = .en
    var itemBrand = "Your brand"
    var appName = "Your app"
    var email: String? = nil
    var theme = PIKDTheme()

    @State private var route: PIKDEntryRoute?
    @State private var prepared: PIKDCdaLaunch?
    @State private var work: Task<Void, Never>?
    @State private var opening = false
    @State private var message: String?

    var body: some View {
        Button(action: open) {
            HStack {
                if opening { ProgressView() }
                Text("Open PIKD")
            }
        }
        .disabled(opening || userRef.isEmpty)
        .fullScreenCover(item: $route, onDismiss: reset) { route in
            PIKDCdaExperienceView(launch: route.launch) { self.route = nil }
        }
        .alert("Unable to open PIKD", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("OK", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
        .onChange(of: userRef) { _, _ in reset() }
        .onDisappear { if route == nil { reset() } }
    }

    private func open() {
        guard !opening else { return }
        opening = true
        message = nil
        work = Task { @MainActor in
            do {
                var configuration = PIKDCdaConfiguration(
                    baseURL: baseURL, sdkKey: sdkKey, userRef: userRef,
                    locationProvider: PIKDDeviceLocationProvider(), locale: locale,
                    itemBrand: itemBrand, appName: appName, theme: theme
                )
                configuration.email = email
                let launch = try await PIKDCdaExperience.prepare(configuration)
                guard !Task.isCancelled else {
                    invalidate(launch)
                    return
                }
                prepared = launch
                route = PIKDEntryRoute(launch: launch)
            } catch is CancellationError {
                // The host cancelled this launch, for example during account switching.
            } catch {
                if !Task.isCancelled {
                    message = "PIKD could not be opened. Please try again or contact support."
                }
            }
            if !Task.isCancelled { opening = false; work = nil }
        }
    }

    private func reset() {
        work?.cancel()
        work = nil
        opening = false
        route = nil
        if let prepared { invalidate(prepared) }
        prepared = nil
    }

    private func invalidate(_ launch: PIKDCdaLaunch) {
        if case .ready(let configuration) = launch {
            Task { await configuration.client.invalidate() }
        }
    }
}

private struct PIKDEntryRoute: Identifiable {
    let id = UUID()
    let launch: PIKDCdaLaunch
}
```

Pass your current account ID as `userRef`, the PIKD SDK v1 base URL and tenant key, and your chosen branding. Localize the host button/error messages using your app's localization system. `locale` controls SDK copy (`.en`, `.ru`, `.kk`). The [demo host](https://github.com/eleostechorg/pikd-demo-ios-sdk/blob/main/PIKDDemoPackage/Sources/PIKDDemoFeature/DemoHostView.swift) also shows nickname input and configurable branding.

Preparation exchanges a fresh session and resolves exactly one active, named challenge for the tenant. An empty/invalid host user can return an outdated-app launch state; tenant/challenge/session/network problems throw an error. Present `PIKDCdaExperienceView` for a returned launch and show a localized host error for a thrown failure.

## 4. Present from UIKit

Use `UIHostingController` to present the SDK from your existing view controller. The caller should retain and cancel its preparation task on logout/account changes; dismiss an open experience before replacing the host account.

<!-- compile:uikit-presenter -->
```swift
import UIKit
import SwiftUI
import PikdIOSPartnerExperience

@MainActor
func presentPIKD(from host: UIViewController, configuration: PIKDCdaConfiguration) async throws {
    let launch = try await PIKDCdaExperience.prepare(configuration)
    if Task.isCancelled {
        if case .ready(let value) = launch { await value.client.invalidate() }
        throw CancellationError()
    }
    let view = PIKDCdaExperienceView(launch: launch) { [weak host] in
        host?.dismiss(animated: true) {
            if case .ready(let value) = launch {
                Task { await value.client.invalidate() }
            }
        }
    }
    let controller = UIHostingController(rootView: view)
    controller.modalPresentationStyle = .fullScreen
    host.present(controller, animated: true)
}
```

Call this function from a main-actor task in your button action, supplying the same `PIKDCdaConfiguration` as the SwiftUI example. Handle a thrown launch error in your app's UI. Keep your existing root view controller and app navigation.

## 5. Identity, language and branding

- Use a stable, opaque identifier for the signed-in host user. Dismiss/cancel PIKD before logout or account changes; prepare a fresh launch for the new account.
- `email`, `nickName`, `signature` and `deviceInfo` are optional host inputs. Supply only values your integration uses. Session exchange is managed by `prepare`; it does not persist a session token for a later launch.
- `contentLanguageRef` selects backend content independently of UI language. Use the tenant-supported `en`, `ru` or `kk`; omit it to follow `locale`.
- Pass `itemBrand`, `appName` and `PIKDTheme` to match your app. For example set `theme.colors.primary`, `theme.colors.onPrimary` and `theme.typography.fontFamily` before creating the configuration.
- The default collection radius is 5 m. `collectRadiusMeters` is a positive host setting; PIKD's backend still applies campaign eligibility and collection rules.

Let the SDK handle navigation within the experience and AR lifecycle while mounted. Use the dismissal callback to remove the experience and return to your host. SDK collection results refresh the campaign views. Opening an owned item with View in AR previews it without making a collection request.

## 6. Try the integration

Run with your tenant configuration, open PIKD, select a map marker and check Go/Collect, collect in AR, review the result/collection, then close back to your host. Test denied camera/location access and your app's account-switching flow on a physical iPhone. Use your own team, bundle identifier, Maps restrictions and production tenant configuration for your app's release.

## License and help

PIKD SDK use requires a written agreement with ELEOS WORLD LTD. Preserve the SDK's [LICENSE](https://github.com/eleostechorg/pikd-ios-sdk-distribution/blob/main/LICENSE) and third-party notices. Contact your PIKD representative for access/configuration or report a reproducible issue with redacted diagnostics.
