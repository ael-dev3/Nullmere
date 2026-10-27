import AppKit
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The map in a real window, as the app shows it: the Metal view made and
/// fed its tiles, its renderer loaded, and the pointer's hovering, clicks,
/// drags and scrolling reaching the session.
@MainActor
final class WorldViewHostTests: XCTestCase {
    private func spin(_ seconds: Double) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func find<T: NSView>(_ type: T.Type, in view: NSView) -> T? {
        if let found = view as? T { return found }
        for child in view.subviews {
            if let found = find(type, in: child) { return found }
        }
        return nil
    }

    func testTheMapLivesInAWindowAndAnswersThePointer() throws {
        guard WorldMetalView.systemDevice != nil else { throw XCTSkip("No Metal device available") }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "a window on the lake")), store: LocalStore(directory: dir))
        session.autoplay(watches: 12)

        let size = NSSize(width: 1000, height: 700)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: WorldView(session: session).frame(width: size.width, height: size.height))
        window.contentView = host
        window.orderFrontRegardless()
        defer { window.close() }
        host.layoutSubtreeIfNeeded()
        spin(1.5)

        let map = try XCTUnwrap(find(WorldMetalView.self, in: host), "The Metal view is in the window")
        XCTAssertGreaterThan(map.bounds.width, 0)
        map.updateFrameRate()
        XCTAssertTrue([30, 60].contains(map.preferredFramesPerSecond))
        map.draw(map.bounds)

        // The pointer over the seat, a click on it, a step aside.
        let seat = try XCTUnwrap(session.state.seat(of: session.player))
        let centre = NSPoint(x: map.bounds.midX, y: map.bounds.midY)
        func event(_ type: NSEvent.EventType, at point: NSPoint) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: map.convert(point, to: nil), modifierFlags: [], timestamp: 0,
                               windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        }
        session.camera.focus(on: seat.position)
        spin(0.2)
        map.mouseMoved(with: event(.mouseMoved, at: centre))
        XCTAssertNotNil(session.hovered, "Hovering names a hex")
        map.mouseDown(with: event(.leftMouseDown, at: centre))
        map.mouseUp(with: event(.leftMouseUp, at: centre))
        XCTAssertNotEqual(session.selection, .none, "A click chooses what is there")
        map.rightMouseDown(with: event(.rightMouseDown, at: NSPoint(x: centre.x + 40, y: centre.y)))
        map.mouseExited(with: event(.mouseMoved, at: centre))
        XCTAssertNil(session.hovered)

        // A drag pans; a scroll pans or zooms.
        let before = session.camera
        map.mouseDown(with: event(.leftMouseDown, at: centre))
        map.mouseDragged(with: event(.leftMouseDragged, at: NSPoint(x: centre.x + 60, y: centre.y + 30)))
        map.mouseUp(with: event(.leftMouseUp, at: NSPoint(x: centre.x + 60, y: centre.y + 30)))
        if let scroll = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: 3, wheel2: 0, wheel3: 0),
           let wheel = NSEvent(cgEvent: scroll) {
            map.scrollWheel(with: wheel)
        }
        spin(0.2)
        XCTAssertNotEqual(session.camera, before, "The camera moved")
        map.draw(map.bounds)
    }
}
