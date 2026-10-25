// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Nullmere",
    // Nullmere needs Apple's on-device language model through the Foundation
    // Models framework, which arrived in macOS 26. The app is built for Apple
    // silicon only.
    platforms: [
        .macOS("26.0"),
    ],
    products: [
        .executable(name: "NullmereLauncher", targets: ["NullmereLauncher"]),
        .executable(name: "Nullmere", targets: ["Nullmere"]),
        .library(name: "NullmereCore", targets: ["NullmereCore"]),
    ],
    targets: [
        // Platform-independent launcher logic: settings, navigation, scene constants.
        .target(name: "LauncherCore"),
        // The SwiftUI/AppKit/Metal launcher interface.
        .target(name: "LauncherKit", dependencies: ["LauncherCore"]),
        // The "Nullmere Online" app entry point.
        .executableTarget(name: "NullmereLauncher", dependencies: ["LauncherKit"]),
        // The game's rules: world, economy, war and diplomacy. Pure Swift,
        // deterministic, and the same on every machine.
        .target(
            name: "NullmereCore",
            linkerSettings: [.linkedLibrary("m", .when(platforms: [.linux]))]
        ),
        // The game's interface: the Metal world, the panels, saving.
        .target(name: "NullmereKit", dependencies: ["NullmereCore", "LauncherCore", "LauncherKit"]),
        // The "Nullmere" game app entry point.
        .executableTarget(name: "Nullmere", dependencies: ["NullmereKit"]),
        .testTarget(name: "LauncherCoreTests", dependencies: ["LauncherCore"]),
        .testTarget(name: "NullmereCoreTests", dependencies: ["NullmereCore"]),
        .testTarget(name: "LauncherKitTests", dependencies: ["LauncherKit", "LauncherCore"]),
        .testTarget(name: "NullmereKitTests", dependencies: ["NullmereKit", "NullmereCore"]),
    ]
)
