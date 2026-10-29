import AppKit
import LauncherCore
import SwiftUI
import XCTest
@testable import LauncherKit

/// What keeps an AppKit view that SwiftUI has let go of, held to no figure.
/// The hosted launcher's lake and window bridge outlive the launcher in a
/// test (`LauncherHostTests`): taken out of every view, yet held, and their
/// hosting view held too. This hosts a plain view in each of the ways the
/// launcher is hosted, takes it out, lets the host go, then the window, and
/// says after each step what is still held, so the cause can be read off.
@MainActor
final class HostedReleaseDiagnostics: XCTestCase {
    func testWhatKeepsAHostedViewOnceItGoes() {
        let middle = NSPoint(x: 200, y: 150)
        let launcherSize = NSSize(width: 960, height: 600), centre = NSPoint(x: 480, y: 300)
        let quiet = launcherModel()
        let pressed = launcherModel()
        let clicked = launcherModel()
        let changed = launcherModel()
        let lines = [
            probe("a plain view, set up outside a pool", AnyView(Probe()), pooled: false),
            probe("a plain view alone", AnyView(Probe())),
            probe("a plain view, clicked", AnyView(Probe()), touch: { self.click(at: middle, in: $0) }),
            probe("beside a hover", AnyView(ZStack { Probe(); Color.white.opacity(0.01).onHover { _ in } })),
            probe("beside a hover, clicked", AnyView(ZStack { Probe(); Color.white.opacity(0.01).onHover { _ in } }),
                  touch: { self.click(at: middle, in: $0) }),
            probe("beside a continuous hover, clicked", AnyView(ZStack { Probe(); Color.white.opacity(0.01).onContinuousHover { _ in } }),
                  touch: { self.click(at: middle, in: $0) }),
            probe("with a scene's focused value", AnyView(Probe().focusedSceneValue(\.launcherIsGated, false))),
            probe("hearing a notice", AnyView(Probe().onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in })),
            probe("the launcher, untouched", AnyView(LauncherRootView(model: quiet)), size: launcherSize, watched: Self.lakeAndBridge),
            probe("the launcher, a key pressed", AnyView(LauncherRootView(model: pressed)), size: launcherSize,
                  touch: { self.press(keyCode: 125, in: $0) }, watched: Self.lakeAndBridge),
            probe("the launcher, clicked", AnyView(LauncherRootView(model: clicked)), size: launcherSize,
                  touch: { self.click(at: centre, in: $0) }, watched: Self.lakeAndBridge),
            probe("the launcher, its model changed once it was out", AnyView(LauncherRootView(model: changed)), size: launcherSize,
                  afterTakingOut: { _ in changed.show(.news) }, watched: Self.lakeAndBridge),
        ]
        for line in lines {
            print(line)
        }
        XCTAssertEqual(lines.count, 12)
    }

    /// Hosts `content` in a window, as the launcher is hosted, and takes it
    /// out; then lets its host go and closes the window; then lets the
    /// window go. Says how many of the views `watched` finds are still held
    /// after each, and whether the host is. `pooled`, it is set up and
    /// touched in a pool of its own, as the app's loop empties its pool
    /// after each event; otherwise what AppKit set aside as it was shown
    /// stays in the test's own pool until the test ends.
    private func probe(_ name: String, _ content: AnyView, size: NSSize = NSSize(width: 400, height: 300), pooled: Bool = true,
                       touch: @MainActor (NSWindow) -> Void = { _ in }, afterTakingOut: @MainActor (NSWindow) -> Void = { _ in },
                       watched: (@MainActor (NSView) -> [NSView])? = nil) -> String {
        let watched = watched ?? { Self.views(ProbeView.self, in: $0) as [NSView] }
        var window: NSWindow?
        var host: NSHostingView<AnyView>?
        let found = NSHashTable<NSView>.weakObjects()
        func show() {
            window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
            window?.isReleasedWhenClosed = false
            host = NSHostingView(rootView: content)
            window?.contentView = host
            window?.orderFrontRegardless()
            spin(0.3)
            if let host {
                for view in watched(host) { found.add(view) }
            }
            if let window { touch(window) }
        }
        if pooled { autoreleasepool { show() } } else { show() }
        weak let hosting = host
        func held() -> Int { found.allObjects.count }
        let shown = held()

        autoreleasepool { host?.rootView = AnyView(Color.black) }
        if let window { afterTakingOut(window) }
        wait { held() == 0 }
        let takenOut = held()

        autoreleasepool {
            window?.contentView = nil
            host = nil
            window?.close()
        }
        wait { held() == 0 && hosting == nil }
        let hostLetGo = held(), hostHeldThen = hosting != nil

        autoreleasepool { window = nil }
        wait { held() == 0 && hosting == nil }
        return "RETAIN \(name): \(shown) watched; taken out, \(takenOut) held; host let go and window closed, \(hostLetGo) held"
            + " and the host \(hostHeldThen ? "held" : "gone"); window let go, \(held()) held and the host \(hosting == nil ? "gone" : "held")"
    }

    private func spin(_ seconds: Double) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func wait(_ done: () -> Bool) {
        let until = Date().addingTimeInterval(2)
        while !done(), Date() < until {
            autoreleasepool { spin(0.05) }
        }
    }

    /// A whole click, its mouse-up sent as the app's loop would send it.
    private func click(at point: NSPoint, in window: NSWindow) {
        let app = NSApplication.shared
        let down = NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0,
                                      windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        let up = NSEvent.mouseEvent(with: .leftMouseUp, location: point, modifierFlags: [], timestamp: 0,
                                    windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 0)!
        app.postEvent(up, atStart: false)
        app.sendEvent(down)
        while let pending = app.nextEvent(matching: .leftMouseUp, until: Date(), inMode: .default, dequeue: true) {
            app.sendEvent(pending)
        }
    }

    private func press(keyCode: UInt16, in window: NSWindow) {
        let down = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                                    context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: keyCode)!
        NSApplication.shared.sendEvent(down)
    }

    /// A launcher model as the hosted launcher test makes one: ready, with
    /// nothing to download and settings of its own.
    private func launcherModel() -> LauncherModel {
        let suite = "HostedReleaseDiagnostics.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let environment = LauncherEnvironment(
            modelReadiness: { .ready },
            systemSavesEnergy: { false },
            downloadNews: { throw URLError(.notConnectedToInternet) },
            open: { _ in true },
            terminate: {}
        )
        let model = LauncherModel(defaults: defaults, environment: environment)
        model.refreshReadiness()
        return model
    }

    private static func lakeAndBridge(_ host: NSView) -> [NSView] {
        (views(LakeMetalView.self, in: host) as [NSView]) + (views(WindowBridgeView.self, in: host) as [NSView])
    }

    private static func views<T: NSView>(_ type: T.Type, in view: NSView) -> [T] {
        view.subviews.flatMap { child -> [T] in ((child as? T).map { [$0] } ?? []) + views(type, in: child) }
    }
}

/// A plain AppKit view, hosted as the launcher hosts its lake and bridge.
private final class ProbeView: NSView {}

private struct Probe: NSViewRepresentable {
    func makeNSView(context: Context) -> ProbeView {
        ProbeView(frame: .zero)
    }

    func updateNSView(_ view: ProbeView, context: Context) {}
}
