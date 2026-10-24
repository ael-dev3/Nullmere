// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Nullmere",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "NullmereLauncher", targets: ["NullmereLauncher"]),
    ],
    targets: [
        // Platform-independent launcher logic: settings, navigation, scene constants.
        .target(name: "LauncherCore"),
        // The SwiftUI/AppKit/Metal launcher interface.
        .target(name: "LauncherKit", dependencies: ["LauncherCore"]),
        // The "Nullmere Online" app entry point.
        .executableTarget(name: "NullmereLauncher", dependencies: ["LauncherKit"]),
        .testTarget(name: "LauncherCoreTests", dependencies: ["LauncherCore"]),
        .testTarget(name: "LauncherKitTests", dependencies: ["LauncherKit", "LauncherCore"]),
    ]
)
