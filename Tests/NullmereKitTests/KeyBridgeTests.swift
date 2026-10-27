import AppKit
import XCTest
@testable import NullmereKit

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
            ("f", .fortify), ("B", .found), ("h", .home), ("=", .zoom(1.25)), ("+", .zoom(1.25)), ("-", .zoom(0.8)), ("_", .zoom(0.8)),
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

    func testAWindowTooLargeForItsScreenIsFittedToIt() throws {
        let screen = try XCTUnwrap(NSScreen.main ?? NSScreen.screens.first, "A screen")
        let visible = screen.visibleFrame
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: visible.width + 400, height: visible.height + 300),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false, screen: screen)
        window.isReleasedWhenClosed = false
        let content = NSView(frame: window.contentLayoutRect)
        window.contentView = content
        window.orderFrontRegardless()
        defer { window.close() }
        content.addSubview(WindowFitterView())
        let deadline = Date().addingTimeInterval(3)
        while window.frame.width > visible.width, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertLessThanOrEqual(window.frame.width, visible.width)
        XCTAssertLessThanOrEqual(window.frame.height, visible.height)
    }
}
