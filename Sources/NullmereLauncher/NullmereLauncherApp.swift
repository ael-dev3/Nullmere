import AppKit
import LauncherKit
import NullmereKit
import SwiftUI

@main
struct NullmereOnlineApp: App {
    @NSApplicationDelegateAdaptor(OnlineAppDelegate.self) private var appDelegate
    @State private var shell = OnlineShell()

    var body: some Scene {
        Window("Nullmere Online", id: "nullmere-online") {
            NullmereOnlineView(shell: shell)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1440, height: 900)
        .commands {
            LauncherCommands(model: shell.launcher, settings: { shell.showSettings() })
            GameCommands(app: shell.app)
        }
    }
}

@MainActor
final class OnlineAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // A copy already running: it comes forward, and this one goes.
        if SingleInstance.handOver() {
            NSApp.terminate(nil)
            return
        }
        // `swift run` starts a bare executable rather than an app bundle;
        // make sure it still behaves like a regular, frontmost Mac app.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Orders still on their way to the realm get a moment to arrive.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let app = GameApp.current, app.ordersWaiting > 0 else { return .terminateNow }
        app.sendWaiting(within: 3) { NSApp.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}
