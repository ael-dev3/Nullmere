import AppKit
import SwiftUI
import XCTest
@testable import NullmereKit
@testable import NullmereLive
import NullmereLiveStage
import NullmereRealm
import NullmereTestSupport
import NullmereWorld

/// The rebuilt realm's screens over a session on a stand-in line: what
/// lies over the world drawn for each state, the map in a real window
/// answering the pointer, and the way in that a debug run is given.
@MainActor
final class LiveGameTests: XCTestCase {
    private func n(_ value: Int) -> JSONValue { .number(Double(value)) }

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

    /// Ada's realm with something of everything a screen lists: troops
    /// ready and wounded, a Barracks training, a building rising, energy,
    /// and two reports, one unread.
    private func rows() -> [String: [[JSONValue]]] {
        var rows = LiveSample.rows()
        func blueprint(_ kind: Int, _ level: Int, _ name: String, opensAt: Int = 1) -> [JSONValue] {
            [n(kind << 32 | level), n(kind), n(level), .string(name), n(0), n(100 * level), n(40 * level), n(0), n(30 * level), n(0), n(0), n(0), n(0),
             n(opensAt), n(0), n(0), n(20 * level)]
        }
        rows["blueprint"] = (1...12).flatMap { level in
            [blueprint(1, level, "Keep"), blueprint(2, level, "Farm"), blueprint(7, level, "Barracks", opensAt: 2), blueprint(12, level, "Wall", opensAt: 3),
             blueprint(11, level, "Hospital", opensAt: 3)]
        }
        rows["soldier"] = [[n(1 << 8 | 1), n(1), n(1), .string("Spearmen"), n(90), n(110), n(110), n(60), n(12), n(1), n(50), n(50), n(0), n(0), n(8_000), n(7), n(1)],
                           [n(1 << 8 | 2), n(1), n(2), .string("Spearmen"), n(120), n(150), n(150), n(60), n(12), n(2), n(100), n(100), n(0), n(0), n(16_000), n(7), n(5)]]
        rows["my_buildings"]?.append([n(24), n(7), n(7), n(1)])
        rows["my_jobs"] = [[n(4), n(7), n(1), n(22), n(3), n(0), n(2_000), n(2_100), n(9)], [n(5), n(7), n(3), n(7 << 16 | 1 << 8 | 1), n(1), n(4), n(2_010), n(2_030), n(10)]]
        rows["my_stock"] = [[n(7), n(6_000), n(8_000), n(30_000), n(12), n(2_000), n(1_300), n(1_300), n(300), n(0), n(0), n(0), n(0), n(0), n(30_000)]]
        rows["my_troops"] = [[n(7 << 16 | 1 << 8 | 1), n(7), n(1), n(1), n(40), n(6)]]
        rows["my_hunt"] = [[n(1), n(940), n(2_000), n(1_000), n(8_000), n(1)]]
        rows["my_reports"] = [
            [n(31), n(1), n(1_900), n(1), n(Int(LiveHex(q: 8, r: -2).packed)), .bool(true), n(1), n(3), n(200), n(6), n(0), n(25), n(25), n(800), n(800), n(0), n(0),
             .string("Your army cleared a level 1 barrow of the Unquiet. Of your 200 soldiers, 6 were wounded. It is bringing home 800 grain and 800 timber."), .bool(true)],
            [n(32), n(1), n(1_950), n(1), n(Int(LiveHex(q: 8, r: -2).packed)), .bool(false), n(2), n(5), n(40), n(30), n(10), n(60), n(31), n(0), n(0), n(0), n(0),
             .string("Your army was beaten at a level 2 barrow of the Unquiet. 29 of the Unquiet still stood. Of your 40 soldiers, 30 were wounded and 10 died."), .bool(false)],
        ]
        return rows
    }

    private func playing(_ rows: [String: [[JSONValue]]]? = nil) async -> (LiveSession, StandInLine) {
        let line = StandInLine(rows: rows ?? self.rows())
        let session = LiveSession(line: line) { 2_015 }
        await session.open()
        return (session, line)
    }

    /// How much of a view shows when it is drawn in a window, as AppKit
    /// draws it; kept under a name where CI asks for the tests' renders.
    private func drawn(_ view: some View, width: CGFloat, height: CGFloat, as name: String? = nil) throws -> Int {
        let size = CGSize(width: width, height: height)
        let framed = view.frame(width: width, height: height)
        if let name { try CardShot.keep(framed, as: name, size: size) }
        return litPixels(try CardShot.draw(framed, size: size))
    }

    func testWhatLiesOverTheWorldIsDrawnForEachState() async throws {
        let (session, line) = await playing()
        XCTAssertEqual(session.phase, .playing)

        // Nothing chosen, no panel: the top bar and the army out, and the
        // world left clear between them.
        var panel: LiveGameView.Panel?
        let binding = Binding(get: { panel }, set: { panel = $0 })
        let bare = try drawn(LiveHUD(session: session, panel: binding), width: 1280, height: 800)
        XCTAssertGreaterThan(bare, 400, "The city's name, its goods, the army out")
        XCTAssertLessThan(bare, 1280 * 800 / 4, "and most of the window left to the world")

        // Something chosen: its card at the foot. And what the realm said.
        session.selected = LiveHex(q: 12, r: -2)
        session.said = "Another army is gathering there."
        let chosen = try drawn(LiveHUD(session: session, panel: binding), width: 1280, height: 800, as: "live-hud.png")
        XCTAssertGreaterThan(chosen, bare + 200, "The grove's card and the realm's words")
        for hex in [LiveHex(q: 10, r: -4), LiveHex(q: 14, r: -4), LiveHex(q: 8, r: -2), LiveHex(q: 5, r: 5)] {
            let card = session.card(for: session.selection(at: hex))
            XCTAssertGreaterThan(try drawn(LiveCardView(session: session, card: card, panel: binding), width: 640, height: 120), 40, card.title)
        }
        XCTAssertGreaterThan(try drawn(LiveSaid(words: "Clear a level 3 barrow first.") {}, width: 600, height: 60), 60)
        XCTAssertGreaterThan(try drawn(LiveArmies(session: session, seconds: 2_015), width: 400, height: 80), 60)

        // Each side panel, with something of everything in it.
        for side in [LiveGameView.Panel.city, .troops, .reports] {
            let lit = try drawn(LiveSidePanel(session: session, seconds: 2_015, panel: side) {}, width: 340, height: 700, as: "live-\(side).png")
            XCTAssertGreaterThan(lit, 800, "\(side)")
        }
        // And with nothing in them: no soldiers yet, no reports yet.
        let (empty, _) = await playing(LiveSample.rows())
        for side in [LiveGameView.Panel.troops, .reports] {
            XCTAssertGreaterThan(try drawn(LiveSidePanel(session: empty, seconds: 2_015, panel: side) {}, width: 340, height: 700), 150, "\(side)")
        }
        XCTAssertEqual(LiveTroops.counts(LiveTroopLine(kind: 1, tier: 1, name: "Spearmen", ready: 1_040, wounded: 6, out: 20)), "1,040 ready, 6 wounded, 20 out")
        XCTAssertEqual(LiveTroops.counts(LiveTroopLine(kind: 1, tier: 1, name: "Spearmen", ready: 0, wounded: 0, out: 0)), "0 ready")

        // The whole screen while the realm is being reached, when it can't
        // be, and while a name is wanted.
        let unopened = LiveSession(line: StandInLine())
        XCTAssertGreaterThan(try drawn(LiveGameView(session: unopened), width: 900, height: 600), 80, "Reaching the realm")
        let lost = LiveSession(line: StandInLine(reachable: false))
        await lost.open()
        XCTAssertEqual(lost.phase, .lost)
        XCTAssertGreaterThan(try drawn(LiveGameView(session: lost), width: 900, height: 600), 120, "The realm can't be reached, and a way to try again")
        XCTAssertGreaterThan(try drawn(LiveNotice(title: "The world can't be drawn", words: "This Mac's graphics could not draw it.", button: nil) {}, width: 600, height: 200), 80)
        XCTAssertGreaterThan(try drawn(LiveNameCard(session: session), width: 400, height: 260, as: "live-name.png"), 80)
        XCTAssertTrue(LiveNameCard.fits("Ada"))
        XCTAssertTrue(LiveNameCard.fits("  Ada   of the Lake "), "tidied as the realm tidies it")
        XCTAssertFalse(LiveNameCard.fits("Al"))
        XCTAssertFalse(LiveNameCard.fits(String(repeating: "a", count: 17)))
        XCTAssertTrue(line.asked.isEmpty, "Drawing asks the realm nothing")
    }

    func testTheRealmsMapLivesInAWindowAndAnswersThePointer() async throws {
        guard WorldMetalView.systemDevice != nil else { throw XCTSkip("No Metal device available") }
        let (session, _) = await playing()
        let size = NSSize(width: 1000, height: 700)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: LiveGameView(session: session).frame(width: size.width, height: size.height))
        window.contentView = host
        window.orderFrontRegardless()
        defer { window.close() }
        host.layoutSubtreeIfNeeded()
        spin(1.5)

        let map = try XCTUnwrap(find(WorldMetalView.self, in: host), "The Metal view is in the window")
        XCTAssertEqual(map.radius, LiveSession.reach)
        XCTAssertNotNil(map.relief)
        XCTAssertEqual(map.houseColours.count, LiveSession.colours.count)
        XCTAssertEqual(map.camera, session.camera)
        map.draw(map.bounds)

        // A click at the window's middle chooses what the camera is over:
        // her own city, at the window's heart.
        let centre = NSPoint(x: map.bounds.midX, y: map.bounds.midY)
        func event(_ type: NSEvent.EventType, at point: NSPoint) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: map.convert(point, to: nil), modifierFlags: [], timestamp: 0,
                               windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        }
        map.mouseDown(with: event(.leftMouseDown, at: centre))
        map.mouseUp(with: event(.leftMouseUp, at: centre))
        XCTAssertEqual(session.selected, LiveHex(q: 10, r: -4))
        spin(0.3)
        XCTAssertEqual(map.selected, session.selectedLocal)

        // A drag pans: the session's camera follows the view's, and the look with it.
        let before = session.camera
        map.mouseDown(with: event(.leftMouseDown, at: centre))
        map.mouseDragged(with: event(.leftMouseDragged, at: NSPoint(x: centre.x + 120, y: centre.y + 40)))
        map.mouseUp(with: event(.leftMouseUp, at: NSPoint(x: centre.x + 120, y: centre.y + 40)))
        spin(0.3)
        XCTAssertNotEqual(session.camera, before, "The camera moved")
        XCTAssertEqual(map.camera, session.camera)

        // Turned to a place far off: another window's land is given to the view.
        session.go(to: LiveHex(q: 30, r: -4))
        spin(0.5)
        XCTAssertEqual(session.windowVersion, 2)
        XCTAssertEqual(map.camera, session.camera)
        map.draw(map.bounds)
    }

    func testADebugRunIsShownIntoTheRebuiltRealm() async throws {
        // Named by the environment, or not at all.
        XCTAssertNil(OnlineShell.session(in: [:]))
        XCTAssertNil(OnlineShell.session(in: ["NULLMERE_REBUILT_REALM": "nowhere at all"]))
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("nullmere-rebuilt-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: file) }
        // A realm no one answers at: the session is made, and says it can't be reached.
        let named = try XCTUnwrap(OnlineShell.session(in: ["NULLMERE_REBUILT_REALM": "http://127.0.0.1:9/nullmere-rebuilt", "NULLMERE_IDENTITY_FILE": file.path]))
        XCTAssertEqual(named.phase, .opening)
        await named.open()
        XCTAssertEqual(named.phase, .lost)
        XCTAssertNotNil(OnlineShell.session(in: ["NULLMERE_REBUILT_REALM": "http://127.0.0.1:9/nullmere-rebuilt"]), "Kept in the keychain where no file is named")

        // The smoke test's rehearsal: a name given where one is wanted,
        // then what it asks to be shown.
        var unnamed = LiveSample.rows()
        unnamed["me"] = nil
        unnamed["my_city"] = nil
        let line = StandInLine(rows: unnamed)
        let joining = LiveSession(line: line) { 2_015 }
        await joining.open()
        XCTAssertEqual(joining.phase, .naming)
        var shown: [LiveGameView.Panel] = []
        await LiveGameView.rehearse(joining, ["NULLMERE_REBUILT_NAME": "Ilsen", "NULLMERE_REBUILT_SHOW": "city"], patience: 1) { shown.append($0) }
        XCTAssertEqual(line.asked, ["join Ilsen"])
        XCTAssertTrue(shown.isEmpty, "Nothing to show of a city not yet founded")

        let (session, played) = await playing()
        await LiveGameView.rehearse(session, [:]) { shown.append($0) }
        XCTAssertNil(session.selected)
        for what in ["city", "troops", "reports", "nothing at all"] {
            await LiveGameView.rehearse(session, ["NULLMERE_REBUILT_NAME": "Ilsen", "NULLMERE_REBUILT_SHOW": what]) { shown.append($0) }
        }
        XCTAssertEqual(shown, [.city, .troops, .reports])
        XCTAssertEqual(session.selected, LiveHex(q: 10, r: -4))
        await LiveGameView.rehearse(session, ["NULLMERE_REBUILT_SHOW": "barrow"]) { shown.append($0) }
        XCTAssertEqual(session.selected, LiveHex(q: 8, r: -2), "The nearest barrow, chosen")
        await LiveGameView.rehearse(session, ["NULLMERE_REBUILT_SHOW": "site"]) { shown.append($0) }
        XCTAssertEqual(session.selected, LiveHex(q: 12, r: -2), "The nearest site")
        XCTAssertTrue(played.asked.isEmpty, "A player already in the realm is not asked to join")
    }
}
