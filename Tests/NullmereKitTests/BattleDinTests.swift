import NullmereWorld
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

/// The towns near the view: heard only as the view comes down close, the
/// closer the louder, from where they lie across it; told to the sound as
/// they change, and still under the stillest motion.
final class TownSoundTests: XCTestCase {
    @MainActor
    func testTheSessionHearsTheTownsNearTheView() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let state = GameState(settings: GameSettings(seedText: "towns", keepers: 1))
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        let seat = try XCTUnwrap(state.seat(of: state.player))
        var camera = session.camera
        camera.focus(on: seat.position)
        camera.heading = 0
        camera.scale = Camera.minimumScale
        session.camera = camera
        XCTAssertNil(session.townSound(), "Well back, no town is heard")
        camera.scale = Camera.maximumScale
        session.camera = camera
        let close = try XCTUnwrap(session.townSound())
        XCTAssertEqual(close.level, 0.3, accuracy: 0.01, "The seat close by, nothing raised in it yet")
        XCTAssertEqual(close.pan, 0, accuracy: 0.3, "in the middle of the view")
        // A town that has raised more is busier, and heard the louder.
        var raised = state
        let built = try XCTUnwrap(raised.holds.firstIndex { $0.id == seat.id })
        raised.holds[built].levels[.granary] = 10
        let busier = GameSession(state: raised, store: LocalStore(directory: dir.appendingPathComponent("busier")))
        busier.camera = camera
        XCTAssertGreaterThan(try XCTUnwrap(busier.townSound()).level, close.level + 0.3)
        // The view a little to the left of the seat: the seat to its right.
        camera.centerX -= 0.3 * 600 / camera.scale
        session.camera = camera
        XCTAssertGreaterThan(try XCTUnwrap(session.townSound()).pan, 0, "to the right of the view")

        var heard: [(Float, Float)] = []
        session.onTown = { heard.append(($0, $1)) }
        session.hearTowns()
        XCTAssertEqual(heard.count, 1)
        session.hearTowns()
        XCTAssertEqual(heard.count, 1, "Told as they change, not every frame")
        session.motion = .still
        session.hearTowns()
        XCTAssertEqual(heard.last?.0, 0, "Still under the stillest motion")
        Ambience(enabled: false).setTown(level: 0.5, pan: 0)
    }
}
