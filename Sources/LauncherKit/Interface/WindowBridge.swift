import AppKit
import LauncherCore
import SwiftUI

/// Reaches the hosting `NSWindow`: styles it for the launcher, enters full
/// screen at launch when asked, and routes navigation keys to the model.
///
/// Keys are read with a local event monitor rather than SwiftUI focus, so
/// arrows, Return and Escape work no matter which control was last clicked.
/// With keyboard navigation turned on, Space is left to the control that
/// has focus.
struct WindowBridge: NSViewRepresentable {
    var startsInFullScreen: Bool
    var onKey: (KeyCommand) -> Void

    func makeNSView(context: Context) -> WindowBridgeView {
        WindowBridgeView(startsInFullScreen: startsInFullScreen, onKey: onKey)
    }

    func updateNSView(_ view: WindowBridgeView, context: Context) {
        view.onKey = onKey
    }
}

final class WindowBridgeView: NSView {
    var onKey: (KeyCommand) -> Void

    private let startsInFullScreen: Bool
    private weak var configuredWindow: NSWindow?
    private var keyMonitor: Any?

    init(startsInFullScreen: Bool, onKey: @escaping (KeyCommand) -> Void) {
        self.startsInFullScreen = startsInFullScreen
        self.onKey = onKey
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else {
            removeKeyMonitor()
            return
        }
        configure(window)
        installKeyMonitor()
    }

    private func configure(_ window: NSWindow) {
        guard configuredWindow !== window else { return }
        configuredWindow = window
        window.backgroundColor = .black
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        if startsInFullScreen {
            // Toggle once the window has finished setting up, and look again
            // then: macOS may already have restored it in full screen.
            DispatchQueue.main.async {
                if !window.styleMask.contains(.fullScreen) {
                    window.toggleFullScreen(nil)
                }
            }
        }
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  event.window === self.window,
                  !event.modifierFlags.containsCommandKeys,
                  let command = KeyCommand(keyCode: event.keyCode, keyboardNavigation: NSApp.isFullKeyboardAccessEnabled)
            else { return event }
            if !event.isARepeat || command.repeatsWhenHeld {
                self.onKey(command)
            }
            return nil
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
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
