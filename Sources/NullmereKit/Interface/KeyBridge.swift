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
    private var monitor: Any?

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

    private func handle(_ event: NSEvent) -> Bool {
        guard let window, event.window === window else { return false }
        // Leave typing, and anything with ⌘ or ⌃, to the controls and menus.
        if window.firstResponder is NSText { return false }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option])
        guard modifiers.isEmpty, let key = Self.key(for: event) else { return false }
        return onKey?(key) ?? false
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
        default: return nil
        }
    }
}
