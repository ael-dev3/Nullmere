import AppKit
import NullmereKit
import SwiftUI

@main
struct NullmereGameApp: App {
    @NSApplicationDelegateAdaptor(GameAppDelegate.self) private var appDelegate
    @State private var app = GameApp()

    var body: some Scene {
        Window("Nullmere", id: "game") {
            GameRootView(app: app)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1440, height: 900)
        .commands {
            GameCommands(app: app)
        }

        Settings {
            GameSettingsView(app: app)
        }
    }
}

@MainActor
final class GameAppDelegate: NSObject, NSApplicationDelegate {
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
