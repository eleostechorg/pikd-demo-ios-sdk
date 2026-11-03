# Local setup

Run these steps from the public demo repository root. To add the SDK to your own app, use the [integration guide](INTEGRATING_INTO_EXISTING_APP.md).

## Prerequisites

| Requirement | Details |
|---|---|
| Mac and Xcode | Xcode 27.1 / Swift 6.4 for the current compiled release; install its command-line tools and iOS platform support |
| Python | Python 3; configuration preparation uses only the standard library |
| iPhone | ARKit-capable device running iOS 18 or later; an Apple development team and provisioning for your bundle identifier |
| PIKD access | SDK v1 base URL, tenant SDK key and a stable host user identifier; CDA needs exactly one active, named challenge |
| Maps | Enable Maps SDK for iOS and obtain a key restricted to your chosen bundle identifier |

The demo uses Swift Package Manager. Open its workspace to resolve the pinned `0.8.0-beta.15` release automatically; you do not need CocoaPods, Node or Flutter for this example.

## Install and configure

```sh
git clone https://github.com/eleostechorg/pikd-demo-ios-sdk.git
cd pikd-demo-ios-sdk
cp Config/pikd.example.json Config/pikd.local.json
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

Fill the four required values in `Config/pikd.local.json`: `PIKD_BASE`, `PIKD_SDK_KEY`, `PIKD_USER` and `PIKD_GOOGLE_MAPS_KEY`. Use the SDK base URL supplied by PIKD, including `/sdk/v1`; use your app's stable signed-in account ID as `PIKD_USER`.

In `Config/Local.xcconfig`, replace `YOUR_APPLE_TEAM_ID` and `com.yourcompany.pikddemo`. The Maps key's iOS application restriction must match the resulting app bundle identifier. Keep your local files out of source control.

```sh
python3 tools/prepare_config.py
open PIKDDemo.xcworkspace
```

The preparation step copies your local values to the app's ignored `PIKDDemo/DemoConfiguration.json`. Run it again whenever the JSON changes. You can select another local file explicitly:

```sh
python3 tools/prepare_config.py --source /path/to/your/pikd.local.json
```

The generated configuration is used by Debug and Release builds. The file is bundled into the app, so use only client configuration supplied by PIKD; your host's server secrets do not belong in an iOS app.

## iPhone signing and launch

1. In Xcode settings, add your Apple account and install the iOS platform support requested by Xcode.
2. Connect and unlock the iPhone. Trust/pair it with the Mac and enable Developer Mode on the device when prompted.
3. Open **Window → Devices and Simulators** and confirm Xcode can see the iPhone. For Wi-Fi deployment, pair it first and enable its network connection there; keep the Mac and phone on the same network.
4. Open `PIKDDemo.xcworkspace`. Select the **PIKDDemo** scheme and your iPhone as the run destination.
5. Check the app target's **Signing & Capabilities**: select your team, use your unique bundle identifier and automatic signing. Local xcconfig overrides must agree with the UI values.
6. Run. Allow camera and While Using the App location access when the chosen flow requests them.

Choose English, Russian or Kazakh, optionally enter a nickname, then tap **Open PIKD**. Close PIKD to return to the host entry screen.

## Configuration and branding

Optional keys supported by this demo:

| Key | Purpose |
|---|---|
| `PIKD_UI_LOCALE` | Initial interface language: `en` (default), `ru` or `kk` |
| `PIKD_LANGUAGE_REF` | Tenant content language; defaults to the selected UI language; use `en`, `ru` or `kk` supported by your content |
| `PIKD_EMAIL` | Optional email from the host account |
| `PIKD_PARTNER_LABEL` | Partner name on the host entry screen |
| `PIKD_PARTNER_APP_NAME` | App name used in partner presentation |
| `PIKD_PARTNER_ITEM_BRAND` | Brand name used in item instructions |
| `PIKD_DEMO_COLLECT_RADIUS_M` | Positive collection radius in meters; default `5`; backend campaign rules still apply |
| `PIKD_FONT_FAMILY` | Registered font family; this demo defaults to bundled Manrope |
| `PIKD_THEME` | Supported semantic color and typography overrides |

For example, merge these optional values into your local JSON:

```json
{
  "PIKD_PARTNER_LABEL": "Your brand",
  "PIKD_PARTNER_APP_NAME": "Your app",
  "PIKD_PARTNER_ITEM_BRAND": "Your brand",
  "PIKD_UI_LOCALE": "en",
  "PIKD_FONT_FAMILY": "Manrope",
  "PIKD_THEME": {
    "colors": {
      "primary": "#146B73",
      "onPrimary": "#FFFFFF",
      "primaryGradient": ["#146B73", "#11545B"]
    }
  }
}
```

Bundled font notices ship with the SDK. Register/license any additional font in your app before selecting it. The nickname is entered on the host screen. Camera/location permission descriptions follow the app's iOS language; SDK controls follow the selected SDK locale.

## Tests and simulator use

The public demo includes two host smoke tests: configuration guidance and English/Russian/Kazakh language selection. They use the blank example configuration and do not contact a tenant or open AR.

```sh
python3 tools/prepare_config.py --source Config/pikd.example.json
```

In Xcode's Test navigator, run **HostSmokeTests** in the **PIKDDemo** scheme. Prepare your own local configuration again before running the live campaign.

Use a physical iPhone to try campaign navigation, camera placement and live collection with your tenant configuration. This beta has a known AR dependency load issue on iOS 18.5 Simulator; use iOS 27 Simulator for host screen development.

## Troubleshooting

| Symptom | Check |
|---|---|
| Configuration required | Fill the required JSON values and rerun `prepare_config.py`; confirm `PIKDDemo/DemoConfiguration.json` exists locally |
| PIKD experience unavailable | Confirm SDK tenant access and exactly one active, named challenge; check the stable host user ID and supported content language |
| Blank map | Enable Maps SDK for iOS, provide the key and match its restriction to the app bundle identifier |
| No nearby objects | Search around the locations configured for your campaign; check location permission and device location services |
| Collect unavailable | Move within the configured collection radius and satisfy campaign eligibility rules |
| Signing/provisioning error | Check Apple account/team, unique app identifier, automatic signing and device trust/Developer Mode |
| iPhone missing over Wi-Fi | Confirm pairing, unlocked device, network connection in Devices and Simulators, and the same Wi-Fi network |
| Camera or location denied | Enable access in iOS Settings for your app and reopen the flow |
| Package resolution/build error | Confirm Xcode/Swift version, the exact public SDK dependency in `PIKDDemoPackage/Package.swift`, and network access to GitHub/GCS; resolve packages again in Xcode |

Use Xcode's debug console and test results when investigating an issue. Share reproduction steps, Xcode/iOS versions and redacted logs with your PIKD representative or [demo issue tracker](https://github.com/eleostechorg/pikd-demo-ios-sdk/issues).
