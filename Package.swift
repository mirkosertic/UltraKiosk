// swift-tools-version:5.9
//
// This file exists solely as a manifest for Dependabot dependency tracking.
// It is NOT used by the Xcode build — dependencies are managed through
// UltraKiosk.xcodeproj (File → Packages in Xcode).
//
// When Dependabot opens a PR bumping a version here, apply the same update
// in Xcode via File → Packages → "Update to Latest Package Versions", or
// by editing the version requirement directly in the Xcode package settings.
//
import PackageDescription

let package = Package(
    name: "UltraKiosk",
    platforms: [.iOS(.v17)],
    dependencies: [
        // MQTT client
        .package(url: "https://github.com/emqx/CocoaMQTT.git", from: "2.1.7"),
        // Wake-word detection (Picovoice Porcupine)
        .package(url: "https://github.com/Picovoice/porcupine.git", from: "4.0.0"),
        // WebSocket transport (used by CocoaMQTT)
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.6"),
    ],
    // No build targets — this package is a dependency manifest only.
    targets: []
)
