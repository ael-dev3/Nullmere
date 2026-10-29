import AppKit
import SwiftUI

/// The game's keys, read from the window's key events while no text field
/// is being typed in.
enum GameKey: Equatable {
    case nextUnit
    case fortify
    case found
    case home
    case escape
    case pan(dx: Double, dy: Double)
    case zoom(Double)
    case houses
    case chronicle
    case guide
}

extension GameSession {
    /// What a key does in the world. False leaves the key to the window.
    func handle(_ key: GameKey) -> Bool {
        switch key {
        case .nextUnit:
            selectNextReadyUnit()
        case .fortify:
            guard let unit = selectedUnit, unit.owner == player else { return false }
            perform(.fortify(unit: unit.id))
        case .found:
            guard let unit = selectedUnit, unit.owner == player, unit.kind == .founder else { return false }
            perform(.found(unit: unit.id))
        case .home:
            focusOnSeat()
        case .escape:
            if seatBriefing != nil {
                dismissSeatBriefing()
            } else if awayReport != nil {
                dismissAwayReport()
            } else if panel != nil {
                panel = nil
            } else if selection != Selection.none {
                selection = Selection.none
            } else {
                return false
            }
        case .pan(let dx, let dy):
            camera.pan(dx: dx, dy: dy)
            camera.clamp(toRadius: state.map.radius)
        case .zoom(let factor):
            camera.zoom(by: factor, around: .zero, in: .zero)
        case .houses:
            panel = panel == .houses ? nil : .houses
        case .chronicle:
            panel = panel == .chronicle ? nil : .chronicle
        case .guide:
            panel = panel == .guide ? nil : .guide
        }
        return true
    }
}

struct KeyBridge: NSViewRepresentable {
    let onKey: (GameKey) -> Bool

    func makeNSView(context: Context) -> KeyBridgeView {
        let view = KeyBridgeView()
        view.onKey = onKey
        return view
    }

    func updateNSView(_ view: KeyBridgeView, context: Context) {
        view.onKey = onKey
    }
}

final class KeyBridgeView: NSView {
    var onKey: ((GameKey) -> Bool)?
    private(set) var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let handled = MainActor.assumeIsolated { self.handle(event) }
            return handled ? nil : event
        }
    }

    override func removeFromSuperview() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        super.removeFromSuperview()
    }

    func handle(_ event: NSEvent, keyboardNavigation: Bool = NSApp.isFullKeyboardAccessEnabled) -> Bool {
        guard let window, event.window === window else { return false }
        // Leave typing, and anything with ⌘ or ⌃, to the controls and menus.
        if window.firstResponder is NSText { return false }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option])
        guard modifiers.isEmpty, let key = Self.key(for: event) else { return false }
        // With keyboard navigation on, a control with focus keeps Tab, to
        // move focus on, and the arrows, to step its value or its choice.
        if keyboardNavigation, Self.movesFocus(key), Self.controlHasFocus(in: window) { return false }
        return onKey?(key) ?? false
    }

    private static func movesFocus(_ key: GameKey) -> Bool {
        switch key {
        case .nextUnit: return true
        case .pan: return true
        default: return false
        }
    }

    /// A control of its own has the keyboard: not the window, the view the
    /// whole interface is drawn in, nor the map, which takes it when clicked.
    static func controlHasFocus(in window: NSWindow) -> Bool {
        guard let responder = window.firstResponder, responder !== window, responder !== window.contentView,
              !(responder is WorldMetalView) else { return false }
        return responder is NSView
    }

    static func key(for event: NSEvent) -> GameKey? {
        let step = event.modifierFlags.contains(.shift) ? 240.0 : 90.0
        switch event.specialKey {
        case .tab?: return .nextUnit
        case .upArrow?: return .pan(dx: 0, dy: step)
        case .downArrow?: return .pan(dx: 0, dy: -step)
        case .leftArrow?: return .pan(dx: step, dy: 0)
        case .rightArrow?: return .pan(dx: -step, dy: 0)
        default: break
        }
        if event.keyCode == 53 { return .escape }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "f": return .fortify
        case "b": return .found
        case "h": return .home
        case "=", "+": return .zoom(1.25)
        case "-", "_": return .zoom(0.8)
        case "w": return .pan(dx: 0, dy: step)
        case "s": return .pan(dx: 0, dy: -step)
        case "a": return .pan(dx: step, dy: 0)
        case "d": return .pan(dx: -step, dy: 0)
        case "1": return .houses
        case "2": return .chronicle
        case "?", "/": return .guide
        default: return nil
        }
    }
}

/// Fits the window inside its screen when it first appears, so a display
/// smaller than the default size never hides the edges of the interface.
struct WindowFitter: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowFitterView { WindowFitterView() }
    func updateNSView(_ view: WindowFitterView, context: Context) {}
}

final class WindowFitterView: NSView {
    private var fitted = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard !fitted, let window else { return }
        fitted = true
        DispatchQueue.main.async {
            guard let screen = window.screen ?? NSScreen.main else { return }
            let visible = screen.visibleFrame
            var frame = window.frame
            guard frame.width > visible.width || frame.height > visible.height else { return }
            frame.size.width = min(frame.width, visible.width)
            frame.size.height = min(frame.height, visible.height)
            frame.origin.x = visible.midX - frame.width / 2
            frame.origin.y = visible.midY - frame.height / 2
            window.setFrame(frame, display: true)
        }
    }
}
