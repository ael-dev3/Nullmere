import AppKit
import LauncherKit
import SwiftUI

@main
struct NullmereLauncherApp: App {
    @NSApplicationDelegateAdaptor(LauncherAppDelegate.self) private var appDelegate
    @State private var model = LauncherModel()

    var body: some Scene {
        Window("Nullmere Online", id: "launcher") {
            LauncherRootView(model: model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1280, height: 800)
        .commands {
            LauncherCommands(model: model)
        }
    }
}

@MainActor
final class LauncherAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // `swift run` starts a bare executable rather than an app bundle;
        // make sure it still behaves like a regular, frontmost Mac app.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
