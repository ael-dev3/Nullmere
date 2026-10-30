import Foundation
import LauncherCore
import NullmereRealm
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// A realm that forgets a keeper in the middle of play, as one begun anew
/// does: the keeper goes back to its front door to choose a name again, not
/// left looking on at a world that is gone, and the name this Mac kept for
/// the realm goes with it.
@MainActor
final class RealmForgetsTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testAKeeperTheRealmForgetsInPlayGoesBackToItsDoor() throws {
        let address = GameApp.RealmAddress.hosted(seed: "a realm that forgets")
        UserDefaults.standard.removeObject(forKey: GameApp.nameKey(for: address))
        defer { UserDefaults.standard.removeObject(forKey: GameApp.nameKey(for: address)) }
        let app = GameApp(store: LocalStore(directory: dir), readiness: { .ready }, sound: false, address: address,
                          identity: FileIdentityStore(url: dir.appendingPathComponent("identity")), opensAtOnce: false)
        app.checkModel()
        guard case .frontDoor = app.phase else { return XCTFail("A ready model opens the front door") }
        app.enterWorld(name: "Ama")
        XCTAssertNotNil(app.session, "In the world")
        XCTAssertEqual(app.keeperName, "Ama")
        XCTAssertEqual(UserDefaults.standard.string(forKey: GameApp.nameKey(for: address)), "Ama")
        let played = try XCTUnwrap(app.link)

        // The realm says it no longer knows this keeper, to the world's own ear.
        played.onEvent?(.refused(.unknownKeeper))
        XCTAssertNil(app.session, "Not left in a world that is gone")
        guard case .frontDoor = app.phase else { return XCTFail("Back at the door") }
        XCTAssertNil(app.keeperName, "A name to choose anew")
        XCTAssertNil(UserDefaults.standard.string(forKey: GameApp.nameKey(for: address)), "The name kept for the realm goes")
        XCTAssertEqual(app.arrivalProblem, "The realm no longer knows you, as when a realm is begun anew. Choose the name you'll go by.")
        XCTAssertNil(played.onEvent, "The old link is let go, telling nothing more")
        XCTAssertFalse(app.link === played, "The door reaches for the realm afresh")
        app.leaveDoor()
    }
}
