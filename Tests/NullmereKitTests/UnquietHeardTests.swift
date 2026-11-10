import NullmereWorld
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The unquiet dead heard near the view on the Mac: wherever their lights
/// burn, over a field the House knows of fallen quiet or about the Barrowkin
/// in sight, as near as the view comes and from where they lie; told to the
/// sound as it changes. Which dead are heard is held in NullmereWorldTests
/// (`UnquietSoundTests`), how they sound in NullmereSoundTests.
final class UnquietHeardTests: XCTestCase {
    @MainActor
    func testTheSessionHearsTheDeadWhereTheirLightsBurn() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var state = GameState(settings: GameSettings(seedText: "unquiet heard", keepers: 1))
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me)).position
        let field = try XCTUnwrap(seat.spiral(2).first { hex in
            hex != seat && state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true
                && !state.isOccupied(hex) && state.hold(at: hex) == nil
        })
        // Fallen the watch before, the field quiet since.
        state.unburied = [FieldOfDead(at: field, troops: GameState.unquietAt + 2_000, houses: [me], since: state.watch - 1)]
        var camera = Camera()
        camera.focus(on: field)
        camera.heading = 0
        camera.scale = UnquietSound.fullest
        func hearing(_ state: GameState, _ name: String) -> GameSession {
            let session = GameSession(state: state, store: LocalStore(directory: dir.appendingPathComponent(name)))
            session.camera = camera
            return session
        }

        // Dead the House does not know of are not heard.
        state.houses[me].explored = Explored(repeating: false, count: state.map.count)
        let blind = hearing(state, "blind")
        XCTAssertTrue(blind.unquietSights().unburied.isEmpty)
        XCTAssertNil(blind.unquietSound(blind.unquietSights().unburied), "Dead the House does not know of are not heard")

        state.houses[me].explored = Explored(repeating: true, count: state.map.count)
        let session = hearing(state, "known")
        let sights = session.unquietSights()
        XCTAssertEqual(sights.unburied.map(\.at), [field], "the field whose lights the world draws")
        XCTAssertTrue(sights.risen.isEmpty)
        let heard = try XCTUnwrap(session.unquietSound(sights.unburied), "Heard where they lie")
        let lights = try XCTUnwrap(UnquietSound.heard(sights.unburied, from: camera))
        XCTAssertEqual(heard.level, lights.level, accuracy: 0.001, "as loud as their lights burn bright, near the view's middle")
        XCTAssertGreaterThan(heard.level, 0.2)
        XCTAssertEqual(heard.pan, 0, accuracy: 0.2)
        camera.scale = Camera.minimumScale
        session.camera = camera
        XCTAssertNil(session.unquietSound(sights.unburied), "Well back, the dead are not heard")
        camera.scale = UnquietSound.fullest
        session.camera = camera

        // Dead fallen this watch lie quiet, as their lights do not yet burn.
        var fresh = state
        fresh.unburied = [FieldOfDead(at: field, troops: GameState.unquietAt + 2_000, houses: [me], since: state.watch)]
        let quiet = hearing(fresh, "fresh")
        XCTAssertNil(quiet.unquietSound(quiet.unquietSights().unburied), "None heard while their lights do not burn")

        // The Barrowkin in sight carry their field's lights, and are heard
        // where they walk.
        var risen = state
        risen.unburied = nil
        risen.wilds = (risen.wilds ?? []) + [Wild(id: risen.takeID(), kind: .barrowkin, level: 2, position: field, raised: risen.watch)]
        let walking = hearing(risen, "risen")
        let carried = walking.unquietSights()
        XCTAssertEqual(carried.risen.map(\.at), [field])
        XCTAssertGreaterThan(try XCTUnwrap(walking.unquietSound(carried.risen)).level, heard.level * 0.9, "as bright as on the eve of the dark")

        // Told to the sound as it changes, not every frame, as the world is
        // drawn; still under the stillest motion.
        var told: [(Float, Float)] = []
        session.onKeening = { told.append(($0, $1)) }
        _ = session.sceneFrame(at: 40, now: Date())
        XCTAssertEqual(told.count, 1, "told as the world is drawn")
        XCTAssertEqual(told.last?.0 ?? 0, heard.level, accuracy: 0.01)
        session.hearUnquiet(sights.unburied)
        XCTAssertEqual(told.count, 1, "Told as it changes, not every frame")
        camera.scale = Camera.minimumScale
        session.camera = camera
        session.hearUnquiet(sights.unburied)
        XCTAssertEqual(told.last?.0, 0, "Drawn back, silent again")
        camera.scale = UnquietSound.fullest
        session.camera = camera
        session.hearUnquiet(sights.unburied)
        XCTAssertEqual(told.last?.0 ?? 0, heard.level, accuracy: 0.01)
        session.motion = .still
        session.hearUnquiet(sights.unburied)
        XCTAssertEqual(told.last?.0, 0, "Still under the stillest motion")
        Ambience(enabled: false).setKeening(level: 0.5, pan: 0)
    }
}
