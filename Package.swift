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
    // A client of the realm being rebuilt (realm/): the rows of one
    // persistent world, pushed as they change, and the reducers a player
    // calls. Foundation only, so tested on Linux against a real server.
    .target(name: "NullmereLive", dependencies: ["NullmereRealm"]),
    .testTarget(name: "NullmereLiveTests", dependencies: ["NullmereLive", "NullmereRealm"]),
    // A keeper's phone on their realm, apart from its screens: linked by the
    // code their Mac shows, in as the keeper, their House as the phone
    // lists it and the orders it gives. Foundation only, so tested on Linux.
    .target(name: "NullmereCompanionCore", dependencies: ["NullmereCore", "NullmereRealm"]),
    .testTarget(name: "NullmereCompanionCoreTests", dependencies: ["NullmereCompanionCore", "NullmereCore", "NullmereRealm", "NullmereTestSupport"]),
    .testTarget(name: "NullmereCoreTests", dependencies: ["NullmereCore"]),
    // The world's shapes: the land's relief and mesh, and every model in
    // it, built from solids in code, with the rigs that move them. Pure
    // Swift, so every shape is built and tested on Linux too.
    .target(name: "NullmereModels", dependencies: ["NullmereCore"]),
    .testTarget(name: "NullmereModelsTests", dependencies: ["NullmereModels", "NullmereCore"]),
    // The world as the GPU draws it, apart from the GPU: the camera, the
    // shaders' source, the data they read and how a frame's models are
    // gathered. Pure Swift, so tested on Linux too.
    .target(name: "NullmereWorld", dependencies: ["NullmereCore", "NullmereModels"]),
    .testTarget(name: "NullmereWorldTests", dependencies: ["NullmereWorld", "NullmereModels", "NullmereCore"]),
    // The game's sound, apart from the Mac's audio engine: the synthesiser,
    // its instruments, its hall and the score written as it plays. Pure
    // Swift, so every sound is rendered and measured on Linux too.
    .target(name: "NullmereSound", dependencies: ["NullmereCore"]),
    .testTarget(name: "NullmereSoundTests", dependencies: ["NullmereSound", "NullmereCore"]),
    // The trailer, apart from the GPU: its world, its shots and what moves
    // in them, and its score. Pure Swift, so every shot is staged and the
    // score rendered on Linux too; the Mac draws and encodes it.
    .target(name: "NullmereTrailer", dependencies: ["NullmereCore", "NullmereModels", "NullmereWorld", "NullmereSound"]),
    .testTarget(name: "NullmereTrailerTests", dependencies: ["NullmereTrailer", "NullmereCore", "NullmereModels", "NullmereWorld", "NullmereSound"]),
    // SpacetimeDB in memory, and credentials kept in memory, for tests of
    // the realm across the network: the realm's and the app's.
    .target(name: "NullmereTestSupport", dependencies: ["NullmereRealm", "NullmereCore"], path: "Tests/NullmereTestSupport"),
    .testTarget(name: "NullmereRealmTests", dependencies: ["NullmereRealm", "NullmereCore", "NullmereModels", "NullmereWorld", "NullmereCompanionCore", "NullmereTestSupport"]),
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
    // Counsel of a House's commanders, spoken by Apple's on-device model
    // through the Foundation Models framework: the Mac's and the companion's.
    .target(name: "NullmereCounsel", dependencies: ["NullmereCore"]),
    .testTarget(name: "NullmereCounselTests", dependencies: ["NullmereCounsel", "NullmereCore"]),
    // The world's interface: the front door, the Metal world, the panels.
    .target(name: "NullmereKit", dependencies: ["NullmereCore", "NullmereModels", "NullmereWorld", "NullmereRealm", "NullmereSound", "NullmereCounsel",
                                                "NullmereCompanionCore", "LauncherCore", "LauncherKit"]),
    // The "Nullmere Online" app: the launcher, and through Play, the realm.
    .executableTarget(name: "NullmereLauncher", dependencies: ["LauncherCore", "LauncherKit", "NullmereKit", "NullmereCounsel"]),
    // Nullmere Companion, the keeper's iPhone app: its SwiftUI screens over
    // the companion's core. Built for iOS by scripts/build-companion.sh,
    // which bundles it; on the Mac it builds too, to be checked as the rest is.
    .executableTarget(name: "NullmereCompanion", dependencies: ["NullmereCompanionCore", "NullmereCounsel", "NullmereCore", "NullmereRealm"]),
    .testTarget(name: "LauncherKitTests", dependencies: ["LauncherKit", "LauncherCore", "NullmereTestSupport"]),
    .testTarget(name: "NullmereKitTests", dependencies: ["NullmereKit", "NullmereCore", "NullmereModels", "NullmereWorld", "NullmereRealm", "NullmereSound", "NullmereCounsel", "NullmereCompanionCore", "LauncherCore", "LauncherKit", "NullmereTestSupport"]),
]
// The trailer drawn by the game's own renderers and written to a film,
// built only when scripts/render-trailer.sh asks for it: then the trailer's
// are the only tests built, over an optimised build of the game, and its
// drawing is left unoptimised, as Swift 6.3.3's optimiser crashes on it.
if Context.environment["NULLMERE_TRAILER"] != nil {
    targets.removeAll { $0.type == .test && $0.name != "NullmereTrailerTests" }
    targets.append(.testTarget(name: "TrailerRenderTests",
                               dependencies: ["NullmereTrailer", "NullmereKit", "NullmereCore", "NullmereModels", "NullmereWorld", "NullmereSound",
                                              "LauncherCore", "LauncherKit"],
                               swiftSettings: [.unsafeFlags(["-Onone"])]))
}
#endif

let package = Package(
    name: "Nullmere",
    // Nullmere Online needs Apple's on-device language model through the
    // Foundation Models framework, which arrived in macOS 26. The app is
    // built for Apple silicon only.
    platforms: [
        .macOS("26.0"),
        // The keeper's companion on their iPhone.
        .iOS("26.0"),
    ],
    products: products,
    targets: targets
)
