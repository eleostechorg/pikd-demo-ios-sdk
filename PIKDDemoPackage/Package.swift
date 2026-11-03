// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "PIKDDemoFeature", platforms: [.iOS(.v18)],
    products: [.library(name: "PIKDDemoFeature", targets: ["PIKDDemoFeature"])],
    dependencies: [.package(url: "https://github.com/eleostechorg/pikd-ios-sdk-distribution.git", exact: "0.8.0-beta.15")],
    targets: [.target(name: "PIKDDemoFeature", dependencies: [.product(name: "PikdIOSCore", package: "pikd-ios-sdk-distribution"), .product(name: "PikdIOSUI", package: "pikd-ios-sdk-distribution"), .product(name: "PikdIOSAR", package: "pikd-ios-sdk-distribution"), .product(name: "PikdIOSExperience", package: "pikd-ios-sdk-distribution"), .product(name: "PikdIOSPartnerExperience", package: "pikd-ios-sdk-distribution")],
        resources: [.process("Resources")])])
