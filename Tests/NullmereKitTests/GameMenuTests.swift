import NullmereRealm
import NullmereWorld
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// Every item of the game's menus: nothing to choose before the world is
/// entered; each does what it says once it is.
@MainActor
final class GameMenuTests: XCTestCase {
    /// The realm's face shows from crossing in to leaving for the launcher,
    /// and the Watch menu's sound toggles with it.
    func testTheRealmsFaceShowsFromCrossingInToLeaving() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let app = GameApp(store: LocalStore(directory: dir), readiness: { .ready }, sound: false, address: .hosted(seed: "showing"),
                          identity: FileIdentityStore(url: dir.appendingPathComponent("identity")))
        XCTAssertFalse(app.isShowing)
        app.open()
        XCTAssertTrue(app.isShowing)
        app.leaveDoor()
        XCTAssertFalse(app.isShowing)
    }

    func testEveryMenuItemDoesWhatItSays() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        UserDefaults.standard.removeObject(forKey: GameApp.nameKey(for: .hosted(seed: "menus")))
        let app = GameApp(store: LocalStore(directory: dir), readiness: { .ready }, sound: false, address: .hosted(seed: "menus"),
                          identity: FileIdentityStore(url: dir.appendingPathComponent("identity")))
        _ = GameCommands(app: app).body
        XCTAssertFalse(app.isShowing, "In the launcher: the Watch menu's Sound and Music wait for the realm")
        for item in GameMenu.allCases {
            XCTAssertFalse(item.isEnabled(in: app), "\(item.title) waits for the world")
            item.perform(in: app)
        }
        XCTAssertEqual(Set(GameMenu.allCases.map(\.title)).count, GameMenu.allCases.count, "Each item its own title")
        XCTAssertEqual(GameMenu.ready.shortcut, KeyboardShortcut(.return, modifiers: .command))

        app.checkModel()
        app.enterWorld(name: "Ama")
        let session = try XCTUnwrap(app.session)
        _ = GameCommands(app: app).body
        XCTAssertTrue(GameMenu.allCases.allSatisfy { $0.isEnabled(in: app) })

        for (item, panel) in [(GameMenu.houses, GameSession.Panel.houses), (.chronicle, .chronicle), (.guide, .guide),
                              (.archive, .archive), (.commanders, .commanders), (.alliance, .alliance), (.realm, .realm), (.words, .words)] {
            item.perform(in: app)
            XCTAssertEqual(session.panel, panel, item.title)
            item.perform(in: app)
            XCTAssertNil(session.panel, "\(item.title) again closes it")
        }
        GameMenu.goToSeat.perform(in: app)
        XCTAssertEqual(session.selection, .hold(try XCTUnwrap(session.state.seat(of: session.player)).id))
        GameMenu.nextCompany.perform(in: app)
        if case .unit = session.selection {} else { XCTFail("A company waiting for orders is chosen: \(session.selection)") }
        // Reset View takes in the whole House, north up, at the opening tilt.
        XCTAssertEqual(GameMenu.resetView.shortcut, KeyboardShortcut("0", modifiers: .command))
        session.camera.heading = 1.2
        session.camera.tilt = 0.3
        session.camera.focus(on: Hex(0, 0))
        GameMenu.resetView.perform(in: app)
        for _ in 0..<100 where session.camera.heading != 0 { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
        XCTAssertEqual(session.camera.heading, 0)
        XCTAssertEqual(session.camera.tilt, Camera.defaultTilt, accuracy: 1e-9)
        let seat = try XCTUnwrap(session.state.seat(of: session.player)).position
        XCTAssertLessThanOrEqual(session.camera.centreHex.distance(to: seat), 2, "A House of one hold: its seat in the middle")
        let watch = session.state.watch
        GameMenu.ready.perform(in: app)
        XCTAssertGreaterThan(session.state.watch, watch, "Alone in the realm, ready turns the watch")
        GameMenu.stayReady.perform(in: app)
        GameMenu.leaveWorld.perform(in: app)
        XCTAssertNil(app.session, "Left the world")
    }
}
