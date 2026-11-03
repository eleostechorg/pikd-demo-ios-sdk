# PIKD iOS partner host demo

A standalone example of a partner launching `PikdIOSPartnerExperience` from an existing app and returning to its host screen. It demonstrates the CDA facade over the generic Core, UI, AR and Experience products.

## Setup

1. Obtain access to the exact SDK release referenced by `PIKDDemoPackage/Package.swift`. Commercial SDK access/distribution is supplied separately; this public demo does not redistribute the SDK implementation.
2. Copy `Config/pikd.example.json` to the ignored `Config/pikd.local.json`. Set your `/sdk/v1` URL, SDK key and host user reference. Supply a Google Maps key valid for your bundle identifier. CDA needs one active challenge.
3. Run `python3 tools/prepare_config.py` before the first build.
4. Open `PIKDDemo.xcworkspace`, choose **PIKDDemo**, configure your own bundle identifier/signing team and run on an AR-capable iPhone. Optional local signing overrides belong in ignored `Config/Local.xcconfig`.

English, Russian and Kazakh are built in. The host picker controls UI language; optional `PIKD_LANGUAGE_REF` controls backend content language independently. Optional branding, email/nickname, font/theme and collection-radius inputs follow `Config/pikd.example.json` and the host source. Default branding is CDA and default collection radius is5m.

The host's **Open PIKD** button performs partner preparation and presents the package. Closing PIKD restores the host. SDK screens and business/session orchestration live in the SDK packages, not duplicate host implementations.

Explore markers open a details card. Go selects navigation; Collect opens AR collection directly. Collection results refresh the appropriate SDK data. Owned-item View in AR is preview only. The demo includes original loading radar/firework and result assets through SDK resources.

Camera/location permission descriptions follow the iOS app language; SDK/host controls follow the selected UI locale. Generated configuration is bundled for Debug and Release, but populated local input and generated files stay untracked. Never commit a developer's tenant values, Maps key or signing configuration.

The exported Xcode tests use public SDK APIs and explicit Debug-only fixtures without tenant writes or a camera. `--demo-components` opens a secondary component catalogue; normal launch remains the partner host journey. SDK-internal native-session tests and the external RN comparison harness are not exported. A simulator cannot establish real camera placement or live collection correctness.

This repository is an export of a reviewed host demo. Do not copy SDK source into it. Dependencies must resolve independently at the selected exact release. See `LICENSE` for commercial terms and the SDK's third-party notices for bundled fonts/icons/animation runtime.
