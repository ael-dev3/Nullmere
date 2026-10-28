// swift-tools-version: 5.9
import PackageDescription

// The rules, the realm and the launcher's own logic build anywhere Swift
// does, Linux included: the steward runs on a server. The app needs the Mac.
var products: [Product] = [
    .executable(name: "NullmereSteward", targets: ["NullmereSteward"]),
    .library(name: "NullmereCore", targets: ["NullmereCore"]),
]
var targets: [Target] = [
    // The game's rules and the realm's authority: world, economy, war,
    // diplomacy, keepers, watches and ages. Pure Swift, deterministic, and
    // the same on every machine.
    .target(
        name: "NullmereCore",
        linkerSettings: [.linkedLibrary("m", .when(platforms: [.linux]))]
    ),
    // The realm: the line between a keeper's client and the world it shares
    // with every other keeper, over SpacetimeDB or hosted in-process, and the
    // steward that runs the rules beside SpacetimeDB. Foundation only.
    .target(name: "NullmereRealm", dependencies: ["NullmereCore"]),
    // The steward's command-line entry point.
    .executableTarget(name: "NullmereSteward", dependencies: ["NullmereRealm", "NullmereCore"]),
    .testTarget(name: "NullmereCoreTests", dependencies: ["NullmereCore"]),
    // SpacetimeDB in memory, and credentials kept in memory, for tests of
    // the realm across the network: the realm's and the app's.
    .target(name: "NullmereTestSupport", dependencies: ["NullmereRealm"], path: "Tests/NullmereTestSupport"),
    .testTarget(name: "NullmereRealmTests", dependencies: ["NullmereRealm", "NullmereCore", "NullmereTestSupport"]),
    // Platform-independent launcher logic: settings, navigation, scene
    // constants, the news feed and the moon's veil. Pure Swift, so it is
    // tested on Linux too.
    .target(name: "LauncherCore"),
    .testTarget(name: "LauncherCoreTests", dependencies: ["LauncherCore"]),
]

#if os(macOS)
products.append(.executable(name: "NullmereLauncher", targets: ["NullmereLauncher"]))
targets += [
    // The SwiftUI/AppKit/Metal launcher interface.
    .target(name: "LauncherKit", dependencies: ["LauncherCore"]),
    // The world's interface: the front door, the Metal world, the panels.
    .target(name: "NullmereKit", dependencies: ["NullmereCore", "NullmereRealm", "LauncherCore", "LauncherKit"]),
    // The "Nullmere Online" app: the launcher, and through Play, the realm.
    .executableTarget(name: "NullmereLauncher", dependencies: ["LauncherKit", "NullmereKit"]),
    .testTarget(name: "LauncherKitTests", dependencies: ["LauncherKit", "LauncherCore", "NullmereTestSupport"]),
    .testTarget(name: "NullmereKitTests", dependencies: ["NullmereKit", "NullmereCore", "NullmereRealm", "LauncherCore", "NullmereTestSupport"]),
]
#endif

let package = Package(
    name: "Nullmere",
    // Nullmere Online needs Apple's on-device language model through the
    // Foundation Models framework, which arrived in macOS 26. The app is
    // built for Apple silicon only.
    platforms: [
        .macOS("26.0"),
    ],
    products: products,
    targets: targets
)
