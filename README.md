# PIKD iOS demo

A native SwiftUI example of adding PIKD to an existing iOS app. Launch a branded campaign from your app, explore its map, collect objects in AR, view your collection and follow the leaderboard. This demo uses the CDA partner experience.

The app installs compiled SDK **0.8.0-beta.15** through Swift Package Manager. You need PIKD tenant access and a Google Maps SDK for iOS key to use live content.

## Get started

1. Install Xcode 27.1 with Swift 6.4, its iOS platform support, and Python 3. Use an ARKit-capable physical iPhone for camera collection.
2. Clone and configure the app:

   ```sh
   git clone https://github.com/eleostechorg/pikd-demo-ios-sdk.git
   cd pikd-demo-ios-sdk
   cp Config/pikd.example.json Config/pikd.local.json
   cp Config/Local.xcconfig.example Config/Local.xcconfig
   ```

3. Edit `Config/pikd.local.json`:

   | Setting | Your value |
   |---|---|
   | `PIKD_BASE` | SDK v1 base URL supplied by PIKD, including `/sdk/v1` |
   | `PIKD_SDK_KEY` | Your tenant's SDK key |
   | `PIKD_USER` | Stable identifier for the signed-in user in your app |
   | `PIKD_GOOGLE_MAPS_KEY` | Maps SDK for iOS key restricted to your app's bundle identifier |

4. Edit `Config/Local.xcconfig` with your Apple development team and a unique bundle identifier. Restrict the Maps key to that same identifier.
5. Prepare configuration and open the workspace:

   ```sh
   python3 tools/prepare_config.py
   open PIKDDemo.xcworkspace
   ```

6. In Xcode, select **PIKDDemo**, choose your connected iPhone, confirm its signing team, and run. Xcode resolves the SDK packages automatically. Choose a language and tap **Open PIKD**.

Your tenant must have exactly one active, named challenge for this CDA launch flow. PIKD supplies your tenant access and campaign configuration.

For device pairing, signing, language/branding options and troubleshooting, see [Local setup](docs/LOCAL_SETUP.md). The demo uses SwiftPM; Node, Flutter and CocoaPods are not required to run this app.

## Add PIKD to your own app

Follow [Integrating into an existing app](docs/INTEGRATING_INTO_EXISTING_APP.md) for product selection, SwiftPM/CocoaPods installation, Maps, permissions, SwiftUI and UIKit presentation, account identity and cleanup.

Your app keeps its own navigation and login. It supplies the current user and opens PIKD from a button or route; closing PIKD returns to your app. See [DemoHostView.swift](PIKDDemoPackage/Sources/PIKDDemoFeature/DemoHostView.swift) for the launch/configuration example and [SDK documentation](https://github.com/eleostechorg/pikd-ios-sdk-distribution) for installation.

## Try the experience

- **Map:** find campaign objects; select a marker for Go or Collect.
- **Info:** read campaign details and instructions.
- **AR:** use the camera to view and collect nearby objects.
- **Leaderboard:** see campaign rankings and trail statistics.
- **Profile:** switch between Dashboard and Collectibles; preview an owned item with View in AR.

English, Russian and Kazakh are included. Collection uses the device location and your campaign's eligibility/range rules. Search near locations configured for your tenant.

## Configuration and development

Local tenant values, generated configuration and signing overrides are ignored by Git. Run `python3 tools/prepare_config.py` again after changing local JSON. See [configuration and branding](docs/LOCAL_SETUP.md#configuration-and-branding) and [tests](docs/LOCAL_SETUP.md#tests-and-simulator-use).

## License and support

PIKD SDK use requires a written agreement with ELEOS WORLD LTD. See [LICENSE](LICENSE) and preserve the SDK's third-party notices.

Contact your PIKD representative for tenant access. Report reproducible demo issues through [GitHub Issues](https://github.com/eleostechorg/pikd-demo-ios-sdk/issues), with tool versions and steps to reproduce; remove credentials and personal data from attachments.
