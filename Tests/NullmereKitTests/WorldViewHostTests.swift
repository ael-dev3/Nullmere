import AppKit
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit
import NullmereTestSupport
import NullmereWorld

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
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "a window on the lake", keepers: 1)), store: LocalStore(directory: dir))
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

        // A trackpad's scroll pans; with Command held, it zooms; a pinch zooms.
        func trackpad(_ dy: Int32, command: Bool) {
            guard let scroll = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: dy, wheel2: 4, wheel3: 0) else { return }
            scroll.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
            if command { scroll.flags = .maskCommand }
            if let wheel = NSEvent(cgEvent: scroll) { map.scrollWheel(with: wheel) }
        }
        let panned = session.camera
        trackpad(12, command: false)
        XCTAssertNotEqual(session.camera, panned, "A trackpad pans")
        let zoomed = session.camera
        trackpad(12, command: true)
        XCTAssertNotEqual(session.camera.scale, zoomed.scale, "With Command, it zooms")
        map.pinch(by: 0.8, around: centre)
        let pinched = session.camera.scale
        map.pinch(by: 1.2, around: centre)
        XCTAssertGreaterThan(session.camera.scale, pinched, "A pinch outward zooms in")
        map.draw(map.bounds)
    }
}

/// The map without Metal, and the forecast over an enemy in reach.
@MainActor
final class WorldOverlayTests: XCTestCase {
    func testTheFallbackMapAndAStrikesForecastDraw() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var state = GameState(settings: GameSettings(seedText: "a forecast", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let foe = (me + 1) % state.houses.count
        _ = try state.perform(.declareWar(on: foe), as: me)
        let spear = try XCTUnwrap(state.units(of: me).first { $0.kind.isMilitary })
        let beside = try XCTUnwrap(state.map.neighbors(of: spear.position).first { hex in
            state.map[hex]?.terrain.isPassable == true && !state.units.contains { $0.position == hex } && state.hold(at: hex) == nil
        })
        let enemy = try XCTUnwrap(state.units.firstIndex { $0.owner == foe })
        state.units[enemy].position = beside
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        session.camera.focus(on: spear.position)
        session.selection = .unit(spear.id)
        session.hover(beside)
        let forecast = try XCTUnwrap(session.hoverForecast, "Hovering a foe in reach forecasts the strike")

        func draw(_ view: some View, width: CGFloat, height: CGFloat) throws {
            let renderer = ImageRenderer(content: view.frame(width: width, height: height).background(Color.black))
            renderer.scale = 1
            let image = try XCTUnwrap(renderer.cgImage)
            XCTAssertGreaterThanOrEqual(litPixels(image), 20, "Drawn, not blank")
        }
        try draw(ForecastOverlay(session: session), width: 1000, height: 700)
        try draw(ForecastCard(forecast: forecast, targetName: "Spear"), width: 300, height: 200)
        try draw(WorldFallback(session: session), width: 1000, height: 700)
        try draw(WorldMarks(session: session), width: 1000, height: 700)
        for terrain in Terrain.allCases {
            _ = WorldFallback.colour(for: terrain)
        }
        session.hover(nil)
        XCTAssertNil(session.hoverForecast)

        // The strike itself: its ring, its flash and any fallen, drawn as they play.
        XCTAssertTrue(session.perform(.attack(unit: spear.id, target: beside)))
        XCTAssertFalse(session.blows.isEmpty, "The blow plays on the map")
        try draw(WorldMarks(session: session), width: 1000, height: 700)

        // A company on the march, and a route planned far off, over more than one watch.
        if let walker = session.state.units(of: me).first(where: { $0.kind == .lantern && $0.movesLeft > 0 }),
           let step = session.state.map.neighbors(of: walker.position).first(where: { hex in
               session.state.map[hex]?.terrain.isPassable == true && session.state.unit(at: hex) == nil
           }) {
            XCTAssertTrue(session.perform(.move(unit: walker.id, to: step)))
            XCTAssertFalse(session.marches.isEmpty, "The march plays on the map")
            try draw(WorldMarks(session: session), width: 1000, height: 700)
            session.selection = .unit(walker.id)
            let moved = try XCTUnwrap(session.state.unit(walker.id))
            let far = session.state.map.hexes.first { hex in
                (6...10).contains(hex.distance(to: step)) && session.state.map[hex]?.terrain.isPassable == true
                    && session.state.unit(at: hex) == nil && session.state.path(for: moved, to: hex) != nil
            }
            session.hover(far)
            XCTAssertFalse(session.pathPreview.isEmpty, "A route is planned")
            try draw(WorldMarks(session: session), width: 1000, height: 700)
            session.hover(nil)
        }
    }
}
