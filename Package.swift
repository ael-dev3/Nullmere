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
        .library(name: "NullmereCore", targets: ["NullmereCore"]),
    ],
    targets: [
        // Platform-independent launcher logic: settings, navigation, scene constants.
        .target(name: "LauncherCore"),
        // The SwiftUI/AppKit/Metal launcher interface.
        .target(name: "LauncherKit", dependencies: ["LauncherCore"]),
        // The "Nullmere Online" app: the launcher, and through Play, the realm.
        .executableTarget(name: "NullmereLauncher", dependencies: ["LauncherKit", "NullmereKit"]),
        // The game's rules: world, economy, war and diplomacy. Pure Swift,
        // deterministic, and the same on every machine.
        .target(
            name: "NullmereCore",
            linkerSettings: [.linkedLibrary("m", .when(platforms: [.linux]))]
        ),
        // The realm: the line between a keeper's client and the world it
        // shares with every other keeper, and a realm hosted in-process.
        // Foundation only, so it builds and tests on Linux too.
        .target(name: "NullmereRealm", dependencies: ["NullmereCore"]),
        // The game's interface: the Metal world, the panels, the front door.
        .target(name: "NullmereKit", dependencies: ["NullmereCore", "NullmereRealm", "LauncherCore", "LauncherKit"]),
        .testTarget(name: "LauncherCoreTests", dependencies: ["LauncherCore"]),
        .testTarget(name: "NullmereCoreTests", dependencies: ["NullmereCore"]),
        .testTarget(name: "NullmereRealmTests", dependencies: ["NullmereRealm", "NullmereCore"]),
        .testTarget(name: "LauncherKitTests", dependencies: ["LauncherKit", "LauncherCore"]),
        .testTarget(name: "NullmereKitTests", dependencies: ["NullmereKit", "NullmereCore", "NullmereRealm", "LauncherCore"]),
    ]
)
