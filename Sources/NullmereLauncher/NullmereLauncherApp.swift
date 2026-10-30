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
        #if DEBUG
        // scripts/check-voices.sh: the voices heard from this Mac's own
        // model, asked by the app as it runs on a keeper's Mac, each line
        // held to the voices' rules; the report written, the app goes.
        if let path = ProcessInfo.processInfo.environment["NULLMERE_VOICES_REPORT"], !path.isEmpty {
            Task { @MainActor in
                let report = await VoiceCheck.run(OnDeviceVoice(), source: "Apple's on-device model on this Mac, \(OnDeviceVoice.availability)")
                try? report.text.write(toFile: path, atomically: true, encoding: .utf8)
                exit(report.failures.isEmpty ? 0 : 1)
            }
            return
        }
        #endif
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

    /// Orders still on their way to the realm get a moment to arrive, and
    /// the sound fades out rather than stopping dead.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let app = GameApp.current else { return .terminateNow }
        let fade = app.ambience.fadeForQuitting()
        if app.ordersWaiting > 0 {
            app.sendWaiting(within: 3) { NSApp.reply(toApplicationShouldTerminate: true) }
            return .terminateLater
        }
        guard fade > 0 else { return .terminateNow }
        DispatchQueue.main.asyncAfter(deadline: .now() + fade) { NSApp.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}
