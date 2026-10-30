import AppKit
import SwiftUI

/// The game's keys, read from the window's key events while no text field
/// is being typed in.
enum GameKey: Equatable {
    /// The next company awaiting orders.
    case nextUnit
    /// Each of the keeper's companies in turn, whatever it is doing:
    /// marching, fortified or spent as well as awaiting orders.
    case anyUnit(forward: Bool)
    case fortify
    case found
    /// The keeper's holds in turn, the seat first.
    case nextHold
    /// Whatever lies where the view is centred, chosen as a click there
    /// would choose it: the keyboard's click.
    case chooseAtCentre
    case escape
    case pan(dx: Double, dy: Double)
    /// The selected company marches, or strikes, where the view is centred:
    /// the keyboard's right-click.
    case orderAtCentre
    case zoom(Double)
    /// The open panel, or the chosen hold's, a page up (-1) or down (1).
    case page(Int)
    case houses
    case chronicle
    case guide
}

extension GameSession {
    /// What a key does in the world. False leaves the key to the window.
    func handle(_ key: GameKey) -> Bool {
        // A card before the world (the seat's briefing, what passed while
        // away) has the keys: Escape puts it away, and nothing reaches the
        // map behind it.
        if isShowingCard {
            guard key == .escape else { return false }
            if seatBriefing != nil { dismissSeatBriefing() } else { dismissAwayReport() }
            return true
        }
        // The age's ending has its own way out, by Escape.
        if key == .escape, state.outcome != nil { return false }
        switch key {
        case .nextUnit:
            selectNextReadyUnit()
            sayChosen()
        case .anyUnit(let forward):
            selectNextUnit(forward: forward)
        case .fortify:
            guard let unit = selectedUnit, unit.owner == player else { return false }
            if perform(.fortify(unit: unit.id)) { sayDone("\(unit.kind.title) fortified") }
        case .found:
            guard let unit = selectedUnit, unit.owner == player, unit.kind == .founder else { return false }
            if let problem = state.canFound(at: unit.position, for: player) {
                post(String(describing: problem), tone: .bad)
                return true
            }
            // What can't be taken back asks twice: B, then B again.
            guard foundingAsked == unit.id else {
                foundingAsked = unit.id
                post("Found a hold here? Press B again to found it.", tone: .neutral)
                return true
            }
            foundingAsked = nil
            perform(.found(unit: unit.id))
        case .nextHold:
            selectNextHold()
        case .chooseAtCentre:
            click(camera.centreHex)
            sayChosen()
        case .escape:
            if panel != nil {
                panel = nil
            } else if selection != Selection.none {
                selection = Selection.none
            } else {
                return false
            }
        case .pan(let dx, let dy):
            camera.pan(dx: dx, dy: dy)
            camera.clamp(toRadius: state.map.radius)
            // A company chosen: where the view is centred is where it would
            // go, shown as a pointer would show it.
            if let unit = selectedUnit, unit.owner == player { hover(camera.centreHex) }
            // VoiceOver says what lies there: the line under a pointer, or
            // the odds of a strike.
            if NSWorkspace.shared.isVoiceOverEnabled, let words = centreWords { sayNow(words) }
        case .orderAtCentre:
            guard let unit = selectedUnit, unit.owner == player else { return false }
            let target = camera.centreHex
            let striking = strikeTargets.contains(target)
            // A strike asks twice, as Declare war does: M shows the odds,
            // M again strikes.
            if striking, strikeAsked != target {
                strikeAsked = target
                hover(target)
                let odds = state.forecast(unit: unit.id, at: target).map { MapAccessibility.odds($0) } ?? "a strike"
                post("Strike? \(odds.prefix(1).uppercased() + odds.dropFirst()). Press M again to strike.", tone: .neutral)
                return true
            }
            strikeAsked = nil
            order(target)
            // A march is said once under way, as a strike says itself.
            if !striking, let after = state.unit(unit.id), after.destination != nil || after.position != unit.position {
                let distance = unit.position.distance(to: target)
                sayDone("\(unit.kind.title) march \(distance) tile\(distance == 1 ? "" : "s") \(MapAccessibility.direction(from: unit.position, to: target))")
            }
        case .zoom(let factor):
            camera.zoom(by: factor, around: .zero, in: .zero)
        case .page(let direction):
            guard panel != nil || selectedHold != nil else { return false }
            pageRequest = PageRequest(serial: pageRequest.serial + 1, direction: direction, target: panel.map(PageTarget.panel) ?? .selection)
        case .houses:
            panel = panel == .houses ? nil : .houses
        case .chronicle:
            panel = panel == .chronicle ? nil : .chronicle
        case .guide:
            panel = panel == .guide ? nil : .guide
        }
        // A question asked by a key lapses at any other key.
        if key != .found { foundingAsked = nil }
        if key != .orderAtCentre { strikeAsked = nil }
        return true
    }
}

extension GameSession {
    /// What lies where the view is centred, in words: who stands there,
    /// the ground, and how far it lies from the company chosen.
    var centreWords: String? {
        let hex = camera.centreHex
        if let forecast = hoverForecast, hovered == hex {
            return "Strike: " + MapAccessibility.odds(forecast)
        }
        var parts: [String] = []
        if let unit = state.unit(at: hex), unit.owner == player || isVisible(hex) {
            parts.append(unit.owner == player ? "Your \(unit.kind.title)" : "The \(unit.kind.title) of \(state.houses[unit.owner].title)")
        }
        if let ground = HoverInfo.line(for: hex, in: state, explored: isExplored(hex), territory: territory) {
            parts.append(ground.replacingOccurrences(of: " · ", with: ", "))
        }
        if let unit = selectedUnit, unit.owner == player, unit.position != hex {
            let distance = unit.position.distance(to: hex)
            parts.append("\(distance) tile\(distance == 1 ? "" : "s") \(MapAccessibility.direction(from: unit.position, to: hex)) of your \(unit.kind.title)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "; ")
    }
}

/// Whether the game's letter keys act alone, or only with ⌥ held: one of
/// the realm's Settings, for those who'd rather a stray key did nothing.
enum LetterKeys {
    static let defaultsKey = "keys.lettersAlone"

    static var actAlone: Bool {
        UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true
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

    func handle(_ event: NSEvent, keyboardNavigation: Bool = NSApp.isFullKeyboardAccessEnabled,
                lettersAlone: Bool = LetterKeys.actAlone) -> Bool {
        guard let window, event.window === window else { return false }
        // Leave typing, and anything with ⌘ or ⌃, to the controls and menus.
        if window.firstResponder is NSText { return false }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option])
        // The letters, numbers and marks act alone; or, for those who'd
        // rather a stray key did nothing, only with ⌥ held.
        let needed: NSEvent.ModifierFlags = !lettersAlone && Self.isCharacterKey(event) ? [.option] : []
        guard modifiers == needed, let key = Self.key(for: event) else { return false }
        // With keyboard navigation on, Tab and the arrows move focus through
        // the interface, as everywhere on the Mac, unless the map itself
        // has the keyboard. The game keeps "." for the next company and
        // WASD to pan, whatever has focus.
        if keyboardNavigation, Self.isNavigationKey(event), !(window.firstResponder is WorldMetalView) { return false }
        return onKey?(key) ?? false
    }

    /// A letter, a number or a mark: the keys a stray press can send.
    static func isCharacterKey(_ event: NSEvent) -> Bool {
        event.specialKey == nil && event.keyCode != 53 && event.charactersIgnoringModifiers != " "
    }

    /// Tab, the arrows, Space and Return: the keys keyboard navigation
    /// moves focus with, and presses the focused control with.
    static func isNavigationKey(_ event: NSEvent) -> Bool {
        switch event.specialKey {
        case .tab?, .upArrow?, .downArrow?, .leftArrow?, .rightArrow?, .carriageReturn?, .enter?: return true
        default: return event.charactersIgnoringModifiers == " "
        }
    }

    static func key(for event: NSEvent) -> GameKey? {
        let step = event.modifierFlags.contains(.shift) ? 240.0 : 90.0
        switch event.specialKey {
        case .tab?: return .nextUnit
        case .upArrow?: return .pan(dx: 0, dy: step)
        case .downArrow?: return .pan(dx: 0, dy: -step)
        case .leftArrow?: return .pan(dx: step, dy: 0)
        case .rightArrow?: return .pan(dx: -step, dy: 0)
        case .carriageReturn?, .enter?: return .chooseAtCentre
        case .pageUp?: return .page(-1)
        case .pageDown?: return .page(1)
        default: break
        }
        if event.keyCode == 53 { return .escape }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case " ": return .chooseAtCentre
        case ".": return .nextUnit
        case "]": return .anyUnit(forward: true)
        case "[": return .anyUnit(forward: false)
        case "f": return .fortify
        case "m": return .orderAtCentre
        case "b": return .found
        case "h": return .nextHold
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
/// smaller than the default size never hides the edges of the interface,
/// and names its content for VoiceOver as the window is named.
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
        window.contentView?.setAccessibilityLabel(window.title)
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
