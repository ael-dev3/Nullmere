import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The din of a field of battle in sight: as loud as the troops fighting
/// there and as near as the view stands, heard from where the field is
/// across the view; nothing where no field is in sight. How the din itself
/// sounds is measured in NullmereSoundTests.
final class BattleDinTests: XCTestCase {
    @MainActor
    func testTheSessionHearsTheFieldsInSightAsLoudAsTheTroopsFightingThere() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var state = GameState(settings: GameSettings(seedText: "din", keepers: 1))
        let quiet = GameSession(state: state, store: LocalStore(directory: dir.appendingPathComponent("quiet")))
        XCTAssertNil(quiet.battleDin(), "No battle, no din")
        var told: [(Float, Float)] = []
        quiet.onDin = { told.append(($0, $1)) }
        quiet.hearBattles()
        XCTAssertTrue(told.isEmpty, "Silence is not told again")

        // A field where the keeper's company stands.
        let player = state.player
        let mine = try XCTUnwrap(state.units(of: player).first { $0.kind.isMilitary })
        var field = Field(id: 1, at: mine.position, joined: state.watch, first: player, second: (player + 1) % 4)
        field.fighters = [Fighter(unit: mine.id, owner: player, side: 0, kind: mine.kind, tier: mine.tier, leader: nil, troops: 9_000),
                          Fighter(unit: 999, owner: (player + 1) % 4, side: 1, kind: .spear, tier: 2, leader: nil, troops: 6_000)]
        state.fields = [field]
        let session = GameSession(state: state, store: LocalStore(directory: dir.appendingPathComponent("battle")))
        // The view a little to the left of it, the field within its
        // middle: to its right.
        var camera = session.camera
        camera.focus(on: mine.position)
        camera.heading = 0
        camera.centerX -= 0.3 * 600 / camera.scale
        session.camera = camera
        let din = try XCTUnwrap(session.battleDin())
        XCTAssertEqual(din.level, 1, accuracy: 1e-4, "Fifteen thousand fighting, close by: as loud as it gets")
        XCTAssertGreaterThan(din.pan, 0, "to the right of the view")
        var heard: [(Float, Float)] = []
        session.onDin = { heard.append(($0, $1)) }
        session.hearBattles()
        XCTAssertEqual(heard.count, 1)
        XCTAssertEqual(heard.last?.0 ?? 0, din.level, accuracy: 1e-4)
        session.hearBattles()
        XCTAssertEqual(heard.count, 1, "Told as it changes, not every frame")
        _ = session.sceneFrame(at: 1)
        XCTAssertEqual(heard.count, 1, "The frame hears it too, unchanged")
        // Under the stillest motion, the world and its din are still.
        session.motion = .still
        session.hearBattles()
        XCTAssertEqual(heard.last?.0, 0)
    }
}
