import AppKit
import LauncherCore
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit
import NullmereWorld

/// The game's keys as the window reads them: each key's meaning, typing
/// and shortcuts left alone, and the window fitted to a small screen.
@MainActor
final class KeyBridgeTests: XCTestCase {
    private func key(_ characters: String, code: UInt16 = 0, in window: NSWindow?, modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: window?.windowNumber ?? 0,
                         context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)!
    }

    private func special(_ key: NSEvent.SpecialKey, code: UInt16, modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
        let text = String(Character(key.unicodeScalar))
        return NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: 0,
                                context: nil, characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code)!
    }

    func testEveryKeyHasItsMeaning() {
        let letters: [(String, GameKey)] = [
            ("f", .fortify), ("B", .found), ("h", .nextHold), ("=", .zoom(1.25)), ("+", .zoom(1.25)), ("-", .zoom(0.8)), ("_", .zoom(0.8)),
            ("]", .anyUnit(forward: true)), ("[", .anyUnit(forward: false)), (" ", .chooseAtCentre),
            ("w", .pan(dx: 0, dy: 90)), ("s", .pan(dx: 0, dy: -90)), ("a", .pan(dx: 90, dy: 0)), ("d", .pan(dx: -90, dy: 0)),
            ("1", .houses), ("2", .chronicle), ("?", .guide), ("/", .guide),
        ]
        for (characters, meaning) in letters {
            XCTAssertEqual(KeyBridgeView.key(for: key(characters, in: nil)), meaning, characters)
        }
        XCTAssertNil(KeyBridgeView.key(for: key("q", in: nil)))
        XCTAssertEqual(KeyBridgeView.key(for: key("\u{1b}", code: 53, in: nil)), .escape)
        XCTAssertEqual(KeyBridgeView.key(for: special(.tab, code: 48)), .nextUnit)
        XCTAssertEqual(KeyBridgeView.key(for: special(.upArrow, code: 126)), .pan(dx: 0, dy: 90))
        XCTAssertEqual(KeyBridgeView.key(for: special(.downArrow, code: 125)), .pan(dx: 0, dy: -90))
        XCTAssertEqual(KeyBridgeView.key(for: special(.leftArrow, code: 123)), .pan(dx: 90, dy: 0))
        XCTAssertEqual(KeyBridgeView.key(for: special(.rightArrow, code: 124, modifiers: .shift)), .pan(dx: -240, dy: 0), "Shift pans further")
        XCTAssertEqual(KeyBridgeView.key(for: special(.carriageReturn, code: 36)), .chooseAtCentre)
        XCTAssertEqual(KeyBridgeView.key(for: special(.pageUp, code: 116)), .page(-1))
        XCTAssertEqual(KeyBridgeView.key(for: special(.pageDown, code: 121)), .page(1))
    }

    /// With Letter keys set to need ⌥, a stray letter does nothing and the
    /// same letter with ⌥ acts; Space, Return, Tab, the arrows and Esc act
    /// alone as ever. With letters alone, ⌥ and a letter is not the game's.
    func testLetterKeysMayNeedOption() throws {
        var heard: [GameKey] = []
        let bridge = KeyBridgeView()
        bridge.onKey = { heard.append($0); return true }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        window.contentView?.addSubview(bridge)
        window.orderFrontRegardless()
        defer { window.close() }

        XCTAssertFalse(bridge.handle(key("f", in: window), keyboardNavigation: false, lettersAlone: false), "A stray F does nothing")
        XCTAssertTrue(bridge.handle(key("f", in: window, modifiers: .option), keyboardNavigation: false, lettersAlone: false), "⌥F fortifies")
        XCTAssertFalse(bridge.handle(key("f", in: window, modifiers: .option), keyboardNavigation: false, lettersAlone: true))
        XCTAssertTrue(bridge.handle(key(" ", in: window), keyboardNavigation: false, lettersAlone: false), "Space acts alone")
        XCTAssertTrue(bridge.handle(key("\u{1b}", code: 53, in: window), keyboardNavigation: false, lettersAlone: false), "and Esc")
        XCTAssertEqual(heard, [.fortify, .chooseAtCentre, .escape])
    }

    /// The realm's gate and door step along their choices as the launcher
    /// does: left and up back, right and down on.
    func testTheGateAndTheDoorReadTheArrowsAsTheLauncherDoes() {
        XCTAssertEqual(ChoiceArrows.command(for: .leftArrow), .left)
        XCTAssertEqual(ChoiceArrows.command(for: .upArrow), .up)
        XCTAssertEqual(ChoiceArrows.command(for: .rightArrow), .right)
        XCTAssertEqual(ChoiceArrows.command(for: .downArrow), .down)
        XCTAssertEqual(ChoiceRow.step(0, by: ChoiceArrows.command(for: .downArrow), among: 3), 1)
        XCTAssertEqual(ChoiceRow.step(1, by: ChoiceArrows.command(for: .upArrow), among: 3), 0)
    }

    func testTheWindowsKeysReachTheGameButTypingAndShortcutsDont() throws {
        var heard: [GameKey] = []
        let bridge = KeyBridgeView()
        bridge.onKey = { heard.append($0); return true }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        window.contentView = content
        content.addSubview(bridge)
        window.orderFrontRegardless()
        defer { window.close() }
        XCTAssertNotNil(bridge.monitor, "Listening once in a window")

        XCTAssertTrue(bridge.handle(key("f", in: window)))
        XCTAssertFalse(bridge.handle(key("f", in: window, modifiers: .command)), "⌘F is the menus'")
        XCTAssertFalse(bridge.handle(key("q", in: window)), "No meaning, not taken")
        let other = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        other.orderFrontRegardless()
        defer { other.close() }
        XCTAssertFalse(bridge.handle(key("f", in: other)), "Another window's key")
        XCTAssertEqual(heard, [.fortify])

        // Typing a name: the keys are the text field's.
        let field = NSTextField(frame: NSRect(x: 10, y: 10, width: 200, height: 24))
        content.addSubview(field)
        window.makeKey()
        if window.makeFirstResponder(field), window.firstResponder is NSText {
            XCTAssertFalse(bridge.handle(key("f", in: window)))
            XCTAssertEqual(heard, [.fortify])
        }

        bridge.removeFromSuperview()
        XCTAssertNil(bridge.monitor, "Gone from the window, it stops listening")
    }

    /// With keyboard navigation on, Tab and the arrows move focus, whatever
    /// has it, unless it is the map; "." and the letters stay the game's,
    /// and without keyboard navigation every key is.
    func testKeyboardNavigationKeepsTabAndTheArrows() throws {
        var heard: [GameKey] = []
        let bridge = KeyBridgeView()
        bridge.onKey = { heard.append($0); return true }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        window.contentView = content
        content.addSubview(bridge)
        let control = Focusable(frame: NSRect(x: 10, y: 10, width: 80, height: 24))
        content.addSubview(control)
        window.orderFrontRegardless()
        defer { window.close() }
        func special(_ key: NSEvent.SpecialKey, code: UInt16) -> NSEvent {
            let text = String(Character(key.unicodeScalar))
            return NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                                    context: nil, characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code)!
        }
        let tab = special(.tab, code: 48), up = special(.upArrow, code: 126)
        // A window may hand its first key view the keyboard as it opens.
        window.makeFirstResponder(nil)

        XCTAssertFalse(bridge.handle(tab, keyboardNavigation: true), "Nothing focused yet: Tab moves focus to the first control")
        XCTAssertTrue(window.makeFirstResponder(control))
        XCTAssertFalse(bridge.handle(tab, keyboardNavigation: true), "Tab moves focus on")
        XCTAssertFalse(bridge.handle(up, keyboardNavigation: true), "The arrows are the control's")
        XCTAssertTrue(bridge.handle(key("f", in: window), keyboardNavigation: true), "Letters stay the game's")
        XCTAssertTrue(bridge.handle(key(".", in: window), keyboardNavigation: true), "and . is the next company")
        XCTAssertTrue(bridge.handle(tab, keyboardNavigation: false), "Without keyboard navigation, Tab is the game's")
        XCTAssertTrue(bridge.handle(up, keyboardNavigation: false), "and the arrows pan")
        XCTAssertEqual(heard, [.fortify, .nextUnit, .nextUnit, .pan(dx: 0, dy: 90)])

        // The map, clicked, has the keyboard: its keys are still the game's.
        if WorldMetalView.systemDevice != nil {
            let map = WorldMetalView()
            map.frame = NSRect(x: 100, y: 10, width: 200, height: 200)
            content.addSubview(map)
            XCTAssertTrue(window.makeFirstResponder(map))
            XCTAssertTrue(bridge.handle(tab, keyboardNavigation: true))
            XCTAssertTrue(bridge.handle(up, keyboardNavigation: true), "The map, with the keyboard, pans to the arrows")
            // Out of the window, so it draws no more for the tests after.
            map.removeFromSuperview()
        }
        bridge.removeFromSuperview()
    }

    /// The interface as the app draws it, in a SwiftUI hosting view: with
    /// keyboard navigation on, Tab moves through its buttons rather than
    /// being kept by the game, so every control can be reached.
    func testWithKeyboardNavigationTabReachesTheInterfacesControls() throws {
        var heard: [GameKey] = []
        let bridge = KeyBridgeView()
        bridge.onKey = { heard.append($0); return true }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        window.contentView = content
        let hosting = NSHostingView(rootView: HStack {
            Button("Houses") {}
            Button("Ready") {}
        })
        hosting.frame = content.bounds
        content.addSubview(hosting)
        content.addSubview(bridge)
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        _ = window.makeFirstResponder(hosting)
        let tab = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                                   context: nil, characters: "\t", charactersIgnoringModifiers: "\t", isARepeat: false, keyCode: 48)!
        XCTAssertFalse(bridge.handle(tab, keyboardNavigation: true), "Tab is the window's, to move through the buttons")
        XCTAssertTrue(bridge.handle(tab, keyboardNavigation: false))
        XCTAssertEqual(heard, [.nextUnit])
        bridge.removeFromSuperview()
    }

    func testAKeyTheAppDispatchesIsTakenByTheGame() throws {
        var heard: [GameKey] = []
        let bridge = KeyBridgeView()
        bridge.onKey = { heard.append($0); return true }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        window.contentView?.addSubview(bridge)
        window.orderFrontRegardless()
        defer { window.close() }

        // The app's own dispatch, where its event monitors see each key first.
        NSApplication.shared.sendEvent(key("f", in: window))
        XCTAssertEqual(heard, [.fortify])
        NSApplication.shared.sendEvent(key("q", in: window))
        XCTAssertEqual(heard, [.fortify], "A key with no meaning is left to the window")
    }

    func testAWindowTooLargeForItsScreenIsFittedToIt() throws {
        let screen = try XCTUnwrap(NSScreen.main ?? NSScreen.screens.first, "A screen")
        let visible = screen.visibleFrame
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: visible.width + 400, height: visible.height + 300),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false, screen: screen)
        window.isReleasedWhenClosed = false
        let content = NSView(frame: window.contentLayoutRect)
        window.contentView = content
        defer { window.close() }
        // Not yet on screen, so AppKit hasn't fitted it itself.
        window.setFrame(NSRect(x: 0, y: 0, width: visible.width + 400, height: visible.height + 300), display: false)
        XCTAssertGreaterThan(window.frame.width, visible.width, "Too large to begin with")
        content.addSubview(WindowFitterView())
        let deadline = Date().addingTimeInterval(3)
        while window.frame.width > visible.width, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertLessThanOrEqual(window.frame.width, visible.width)
        XCTAssertLessThanOrEqual(window.frame.height, visible.height)
    }
}

/// What each key does in the world, as the session carries it out.
@MainActor
final class GameKeyTests: XCTestCase {
    func testEachKeyActsOnTheWorld() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "keys", houseCount: 4, radius: 18, keepers: 1)),
                                  store: LocalStore(directory: dir))

        // Escape lays down what is open, one thing at a time.
        XCTAssertNotNil(session.seatBriefing)
        XCTAssertTrue(session.handle(.escape))
        XCTAssertNil(session.seatBriefing, "The briefing first")

        // The panels open and close by their keys.
        for (key, panel) in [(GameKey.houses, GameSession.Panel.houses), (.chronicle, .chronicle), (.guide, .guide)] {
            XCTAssertTrue(session.handle(key))
            XCTAssertEqual(session.panel, panel)
            XCTAssertTrue(session.handle(key))
            XCTAssertNil(session.panel)
        }
        XCTAssertTrue(session.handle(.guide))
        XCTAssertTrue(session.handle(.escape))
        XCTAssertNil(session.panel, "Escape closes a panel")

        // Nothing chosen: fortify and found aren't the world's to take.
        session.selection = .none
        XCTAssertFalse(session.handle(.fortify))
        XCTAssertFalse(session.handle(.found))
        XCTAssertFalse(session.handle(.escape), "Nothing left for Escape to lay down")

        // Tab chooses a company; F fortifies it.
        XCTAssertTrue(session.handle(.nextUnit))
        let chosen = try XCTUnwrap(session.selectedUnit)
        if chosen.kind != .founder {
            XCTAssertFalse(session.handle(.found), "Only a founder founds")
        }
        XCTAssertTrue(session.handle(.fortify))
        XCTAssertTrue(session.handle(.escape))
        XCTAssertEqual(session.selection, .none, "Escape lets the company go")

        // A founder founds where it stands.
        if let founder = session.state.units(of: session.player).first(where: { $0.kind == .founder }) {
            session.selection = .unit(founder.id)
            _ = session.handle(.found)
        }

        // The camera pans, zooms and comes home.
        let before = session.camera
        XCTAssertTrue(session.handle(.pan(dx: 90, dy: 0)))
        XCTAssertNotEqual(session.camera, before)
        let panned = session.camera
        XCTAssertTrue(session.handle(.zoom(1.25)))
        XCTAssertNotEqual(session.camera.scale, panned.scale)
        XCTAssertTrue(session.handle(.nextHold))
        XCTAssertEqual(session.selectedHold?.isSeat, true, "H goes to the seat first")
    }

    /// Without a pointer, nothing is out of reach: ] and [ go round every
    /// company, whatever it is doing; H round the holds, the seat first;
    /// Space chooses what lies in the middle of the view; and VoiceOver
    /// hears what each key chose.
    func testEveryCompanyAndHoldIsWithinTheKeysReach() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var state = GameState(settings: GameSettings(seedText: "every one in reach", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        // One fortified, out of Tab's turn: never out of reach.
        let first = try XCTUnwrap(state.units.firstIndex { $0.owner == me })
        state.units[first].fortified = true
        let site = try XCTUnwrap(state.bestFoundingSite(for: me, from: seat.position))
        state.units.append(NullmereCore.Unit(id: state.nextID, kind: .founder, owner: me, position: site))
        state.nextID += 1
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        session.dismissSeatBriefing()
        session.voiceOverRunning = { true }

        let mine = session.state.units(of: me).map(\.id).sorted()
        var seen: [Int] = []
        for _ in mine {
            XCTAssertTrue(session.handle(.anyUnit(forward: true)))
            seen.append(try XCTUnwrap(session.selectedUnit).id)
        }
        XCTAssertEqual(seen, mine, "] goes round every company in turn")
        XCTAssertTrue(session.lastSaid?.hasPrefix("Chosen: ") ?? false, "and VoiceOver hears which")
        XCTAssertTrue(session.handle(.anyUnit(forward: false)))
        XCTAssertEqual(session.selectedUnit?.id, mine[mine.count - 2], "[ goes back")

        XCTAssertTrue(session.handle(.nextHold))
        XCTAssertEqual(session.selectedHold?.id, seat.id, "H: the seat first")
        XCTAssertTrue(session.lastSaid?.contains(seat.name) ?? false)

        // Space: whatever lies in the middle of the view, as a click there.
        session.selection = .none
        session.camera.focus(on: site)
        XCTAssertTrue(session.handle(.chooseAtCentre))
        XCTAssertEqual(session.selectedUnit?.kind, .founder)

        // B asks, B again founds; any other key between lets the question go.
        XCTAssertTrue(session.handle(.found))
        XCTAssertNil(session.state.hold(at: site), "The first B only asks")
        XCTAssertTrue(session.notices.last?.text.hasPrefix("Found a hold here?") ?? false)
        XCTAssertTrue(session.handle(.zoom(1.25)))
        XCTAssertTrue(session.handle(.found))
        XCTAssertNil(session.state.hold(at: site), "Asked afresh after another key")
        XCTAssertTrue(session.handle(.found))
        XCTAssertNotNil(session.state.hold(at: site), "B again founds")
    }

    /// Page Up and Page Down are for the panel open over the map, or else
    /// the chosen hold's; with neither, they are left to the window.
    func testThePageKeysPageTheOpenPanel() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "pages", houseCount: 3, radius: 16, keepers: 1)),
                                  store: LocalStore(directory: dir))
        session.dismissSeatBriefing()
        session.selection = .none
        XCTAssertFalse(session.handle(.page(1)), "Nothing to page")
        session.panel = .guide
        XCTAssertTrue(session.handle(.page(1)))
        XCTAssertEqual(session.pageRequest.target, .panel(.guide))
        XCTAssertEqual(session.pageRequest.direction, 1)
        let serial = session.pageRequest.serial
        session.panel = nil
        session.focusOnSeat()
        XCTAssertTrue(session.handle(.page(-1)))
        XCTAssertEqual(session.pageRequest, GameSession.PageRequest(serial: serial + 1, direction: -1, target: .selection))

        let extent = PagedByKeys.Extent(offset: 100, visible: 200, content: 1000)
        XCTAssertEqual(PagedByKeys.landing(after: extent, direction: 1), 270, accuracy: 0.001, "Most of a height on")
        XCTAssertEqual(PagedByKeys.landing(after: extent, direction: -1), 0, "Never past the top")
        XCTAssertEqual(PagedByKeys.landing(after: PagedByKeys.Extent(offset: 750, visible: 200, content: 1000), direction: 1), 800,
                       "Never past the end")
    }
}

/// A control that takes the keyboard, as a focused button does.
private final class Focusable: NSView {
    override var acceptsFirstResponder: Bool { true }
}
