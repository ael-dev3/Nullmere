import NullmereWorld
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The blackwood burning heard near the view on the Mac: the wood alight
/// the House has seen about the view's middle, as near as the view comes
/// and from where it burns; told to the sound as it changes. Which fire is
/// heard is held in NullmereWorldTests (`FireSoundTests`), how it sounds in
/// NullmereSoundTests.
final class FireHeardTests: XCTestCase {
    @MainActor
    func testTheSessionHearsTheWoodBurningThatTheHouseHasSeen() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var state = GameState(settings: GameSettings(seedText: "fire heard", keepers: 1))
        let me = state.player
        let map = state.map
        let wood = try XCTUnwrap(map.hexes.first { hex in
            state.isBlackwood(hex) && state.hold(at: hex) == nil && hex.neighbors.allSatisfy { state.isBlackwood($0) && state.hold(at: $0) == nil }
        })
        let burning = [wood] + wood.neighbors
        state.wildfires = burning.map { Wildfire(at: $0, by: me, caught: state.watch, out: state.watch + Wildfire.burns) }
        XCTAssertEqual(state.problems(), [])
        var camera = Camera()
        camera.focus(on: wood)
        camera.heading = 0
        camera.scale = FireSound.fullest

        // Wood the House has not seen is not heard burning.
        state.houses[me].explored = Explored(repeating: false, count: map.count)
        let blind = GameSession(state: state, store: LocalStore(directory: dir.appendingPathComponent("blind")))
        blind.camera = camera
        XCTAssertNil(blind.fireSound(), "Wood the House has not seen is not heard burning")

        state.houses[me].explored = Explored(repeating: true, count: map.count)
        let session = GameSession(state: state, store: LocalStore(directory: dir.appendingPathComponent("seen")))
        session.camera = camera
        let close = try XCTUnwrap(session.fireSound())
        XCTAssertEqual(close.level, 1, accuracy: 0.01, "The wood alight all about the view's middle, close")
        XCTAssertEqual(close.pan, 0, accuracy: 0.2)
        camera.scale = (FireSound.faintest + FireSound.fullest) / 2
        session.camera = camera
        XCTAssertLessThan(try XCTUnwrap(session.fireSound()).level, close.level, "Farther back, fainter")
        camera.scale = Camera.minimumScale
        session.camera = camera
        XCTAssertNil(session.fireSound(), "Well back, the fire is not heard")
        camera.scale = FireSound.fullest

        // Burnt out, it is silent.
        var ash = state
        ash.wildfires = burning.map { Wildfire(at: $0, by: me, caught: state.watch - 4, out: state.watch - 1) }
        let cold = GameSession(state: ash, store: LocalStore(directory: dir.appendingPathComponent("ash")))
        cold.camera = camera
        XCTAssertNil(cold.fireSound(), "Ash makes no sound")

        // Told to the sound as it changes, not every frame; still under the
        // stillest motion.
        session.camera = camera
        var heard: [(Float, Float)] = []
        session.onBlaze = { heard.append(($0, $1)) }
        session.hearFire()
        XCTAssertEqual(heard.count, 1)
        XCTAssertEqual(heard.last?.0 ?? 0, 1, accuracy: 0.01)
        session.hearFire()
        XCTAssertEqual(heard.count, 1, "Told as it changes, not every frame")
        camera.scale = Camera.minimumScale
        session.camera = camera
        session.hearFire()
        XCTAssertEqual(heard.last?.0, 0, "Drawn back, silent again")
        camera.scale = FireSound.fullest
        session.camera = camera
        session.hearFire()
        XCTAssertGreaterThan(heard.last?.0 ?? 0, 0.9)
        session.motion = .still
        session.hearFire()
        XCTAssertEqual(heard.last?.0, 0, "Still under the stillest motion")
    }
}
