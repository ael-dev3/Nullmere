import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// Every item of the game's menus: nothing to choose before the world is
/// entered; each does what it says once it is.
@MainActor
final class GameMenuTests: XCTestCase {
    func testEveryMenuItemDoesWhatItSays() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        UserDefaults.standard.removeObject(forKey: GameApp.nameKey(for: .hosted(seed: "menus")))
        let app = GameApp(store: LocalStore(directory: dir), readiness: { .ready }, sound: false, address: .hosted(seed: "menus"),
                          identity: FileIdentityStore(url: dir.appendingPathComponent("identity")))
        _ = GameCommands(app: app).body
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

        for (item, panel) in [(GameMenu.houses, GameSession.Panel.houses), (.chronicle, .chronicle), (.guide, .guide)] {
            item.perform(in: app)
            XCTAssertEqual(session.panel, panel, item.title)
            item.perform(in: app)
            XCTAssertNil(session.panel, "\(item.title) again closes it")
        }
        GameMenu.goToSeat.perform(in: app)
        XCTAssertEqual(session.selection, .hold(try XCTUnwrap(session.state.seat(of: session.player)).id))
        GameMenu.nextCompany.perform(in: app)
        if case .unit = session.selection {} else { XCTFail("A company waiting for orders is chosen: \(session.selection)") }
        let watch = session.state.watch
        GameMenu.ready.perform(in: app)
        XCTAssertGreaterThan(session.state.watch, watch, "Alone in the realm, ready turns the watch")
        GameMenu.stayReady.perform(in: app)
        GameMenu.leaveWorld.perform(in: app)
        XCTAssertNil(app.session, "Left the world")
    }
}
