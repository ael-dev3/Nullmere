import AppKit
import LauncherCore
import SwiftUI

/// Reaches the hosting `NSWindow`: styles it for the launcher, enters full
/// screen at launch when asked, and routes navigation keys and clicks to the
/// model.
///
/// Keys are read with a local event monitor rather than SwiftUI focus, so
/// arrows, Return and Escape work no matter which control was last clicked.
/// With keyboard navigation turned on, Space is left to the control that
/// has focus. Clicks are only observed: each one still reaches the window,
/// which may start dragging it, or the control under the pointer.
struct WindowBridge: NSViewRepresentable {
    var startsInFullScreen: Bool
    var onKey: (KeyCommand) -> Void
    var onClick: () -> Void

    func makeNSView(context: Context) -> WindowBridgeView {
        WindowBridgeView(startsInFullScreen: startsInFullScreen, onKey: onKey, onClick: onClick)
    }

    func updateNSView(_ view: WindowBridgeView, context: Context) {
        view.onKey = onKey
        view.onClick = onClick
    }

    /// Crossing to the realm takes the launcher out of the window, and
    /// SwiftUI tears this bridge down with it. Take it out of the view tree
    /// here too: left in a detached tree, the bridge (and the event monitor
    /// it holds) would outlive the window it was made for.
    static func dismantleNSView(_ view: WindowBridgeView, coordinator: ()) {
        view.removeFromSuperview()
    }
}

final class WindowBridgeView: NSView {
    var onKey: (KeyCommand) -> Void
    var onClick: () -> Void

    private let startsInFullScreen: Bool
    /// How the window enters full screen; tests watch it instead.
    var enterFullScreen: (NSWindow) -> Void = { $0.toggleFullScreen(nil) }
    private weak var configuredWindow: NSWindow?
    /// The windows already opened once. Full screen is entered only as a
    /// window first opens: a bridge made anew (as on coming back from the
    /// realm) leaves the window as the player has since left it.
    private static let opened = NSHashTable<NSWindow>.weakObjects()
    private var eventMonitor: Any?

    init(startsInFullScreen: Bool, onKey: @escaping (KeyCommand) -> Void, onClick: @escaping () -> Void) {
        self.startsInFullScreen = startsInFullScreen
        self.onKey = onKey
        self.onClick = onClick
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    isolated deinit {
        removeEventMonitor()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else {
            removeEventMonitor()
            return
        }
        configure(window)
        installEventMonitor()
    }

    private func configure(_ window: NSWindow) {
        guard configuredWindow !== window else { return }
        configuredWindow = window
        window.backgroundColor = .black
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        let opening = !Self.opened.contains(window)
        Self.opened.add(window)
        if startsInFullScreen, opening {
            // Toggle once the window has finished setting up, and look again
            // then: macOS may already have restored it in full screen.
            DispatchQueue.main.async { [enterFullScreen] in
                if !window.styleMask.contains(.fullScreen) {
                    enterFullScreen(window)
                }
            }
        }
    }

    private func installEventMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { [weak self] event in
            guard let self else { return event }
            var passed: NSEvent? = event
            MainActor.assumeIsolated { passed = self.monitored(event) }
            return passed
        }
    }

    /// An event in this window, seen before the window has it: a click is
    /// told and passed on; a navigation key is taken for the model, held
    /// keys repeating only where they should. Anything else passes on.
    func monitored(_ event: NSEvent, keyboardNavigation: Bool = NSApp.isFullKeyboardAccessEnabled) -> NSEvent? {
        guard event.window === window else { return event }
        if event.type == .leftMouseDown {
            onClick()
            return event
        }
        guard !event.modifierFlags.containsCommandKeys,
              let command = KeyCommand(keyCode: event.keyCode, keyboardNavigation: keyboardNavigation)
        else { return event }
        if !event.isARepeat || command.repeatsWhenHeld {
            onKey(command)
        }
        return nil
    }

    var isMonitoring: Bool { eventMonitor != nil }

    private func removeEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}

private extension NSEvent.ModifierFlags {
    /// Command, Option or Control is held. Arrow keys always carry the
    /// function and numeric-pad flags, so those (and Shift) don't count.
    var containsCommandKeys: Bool {
        !intersection([.command, .option, .control]).isEmpty
    }
}
