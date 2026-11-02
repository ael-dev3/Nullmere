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
        Ambience(enabled: false).setSawing(0.5)

        // A sawpit raised in the seat: the town heard is sawing, told once.
        XCTAssertEqual(try XCTUnwrap(busier.townSounds()).sawing, 0, "No sawpit, no saw")
        var sawn = state
        sawn.holds[built].levels[.sawpit] = 1
        let sawing = GameSession(state: sawn, store: LocalStore(directory: dir.appendingPathComponent("sawing")))
        var near = session.camera
        near.focus(on: seat.position)
        sawing.camera = near
        XCTAssertGreaterThan(try XCTUnwrap(sawing.townSounds()).sawing, 0.5)
        var shares: [Float] = []
        sawing.onSawing = { shares.append($0) }
        sawing.hearTowns()
        sawing.hearTowns()
        XCTAssertEqual(shares.count, 1)
        XCTAssertEqual(try XCTUnwrap(sawing.townSounds()).chiselling, 0, "No lodge, no chisel")
        var cut = sawn
        cut.holds[built].levels[.lodge] = 2
        let lodge = GameSession(state: cut, store: LocalStore(directory: dir.appendingPathComponent("lodge")))
        lodge.camera = near
        var taps: [Float] = []
        lodge.onChiselling = { taps.append($0) }
        lodge.hearTowns()
        XCTAssertGreaterThan(taps.last ?? 0, 0.5)
        Ambience(enabled: false).setChiselling(0.5)
        var fired = cut
        fired.holds[built].levels[.beacon] = 1
        let beacon = GameSession(state: fired, store: LocalStore(directory: dir.appendingPathComponent("beacon")))
        beacon.camera = near
        var fires: [Float] = []
        beacon.onBurning = { fires.append($0) }
        beacon.hearTowns()
        XCTAssertGreaterThan(fires.last ?? 0, 0.5)
        Ambience(enabled: false).setBurning(0.5)
        var grain = fired
        grain.holds[built].levels[.granary] = 1
        let granary = GameSession(state: grain, store: LocalStore(directory: dir.appendingPathComponent("granary")))
        granary.camera = near
        var floors: [Float] = []
        granary.onThreshing = { floors.append($0) }
        granary.hearTowns()
        XCTAssertGreaterThan(floors.last ?? 0, 0.5)
        Ambience(enabled: false).setThreshing(0.5)
        var cutStone = grain
        cutStone.holds[built].levels[.quarry] = 1
        let quarry = GameSession(state: cutStone, store: LocalStore(directory: dir.appendingPathComponent("quarry")))
        quarry.camera = near
        var picks: [Float] = []
        quarry.onQuarrying = { picks.append($0) }
        quarry.hearTowns()
        XCTAssertGreaterThan(picks.last ?? 0, 0.5)
        Ambience(enabled: false).setQuarrying(0.5)
        var salted = cutStone
        salted.holds[built].levels[.saltworks] = 1
        let saltworks = GameSession(state: salted, store: LocalStore(directory: dir.appendingPathComponent("saltworks")))
        saltworks.camera = near
        var rakes: [Float] = []
        saltworks.onRaking = { rakes.append($0) }
        saltworks.hearTowns()
        XCTAssertGreaterThan(rakes.last ?? 0, 0.5)
        Ambience(enabled: false).setRaking(0.5)
        var mustered = salted
        mustered.holds[built].levels[.musterHall] = 1
        let muster = GameSession(state: mustered, store: LocalStore(directory: dir.appendingPathComponent("muster")))
        muster.camera = near
        var drums: [Float] = []
        muster.onDrilling = { drums.append($0) }
        muster.hearTowns()
        XCTAssertGreaterThan(drums.last ?? 0, 0.5)
        Ambience(enabled: false).setDrilling(0.5)
        var healed = mustered
        healed.holds[built].levels[.infirmary] = 1
        let infirmary = GameSession(state: healed, store: LocalStore(directory: dir.appendingPathComponent("infirmary")))
        infirmary.camera = near
        var pestles: [Float] = []
        infirmary.onGrinding = { pestles.append($0) }
        infirmary.hearTowns()
        XCTAssertGreaterThan(pestles.last ?? 0, 0.5)
        Ambience(enabled: false).setGrinding(0.5)
        var studied = healed
        studied.holds[built].levels[.archive] = 1
        let archive = GameSession(state: studied, store: LocalStore(directory: dir.appendingPathComponent("archive")))
        archive.camera = near
        var leaves: [Float] = []
        archive.onReading = { leaves.append($0) }
        archive.hearTowns()
        XCTAssertGreaterThan(leaves.last ?? 0, 0.5)
        Ambience(enabled: false).setReading(0.5)
        var smithied = studied
        smithied.holds[built].levels[.forge] = 1
        let smithy = GameSession(state: smithied, store: LocalStore(directory: dir.appendingPathComponent("forge")))
        smithy.camera = near
        var rings: [Float] = []
        smithy.onForging = { rings.append($0) }
        smithy.hearTowns()
        XCTAssertGreaterThan(rings.last ?? 0, 0.5)
        Ambience(enabled: false).setForging(0.5)
        sawing.motion = .still
        sawing.hearTowns()
        XCTAssertEqual(shares.last, 0, "Still under the stillest motion")
    }
}
