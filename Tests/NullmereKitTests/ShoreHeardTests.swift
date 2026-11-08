import NullmereWorld
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The lake heard at its edge near the view on the Mac: the strand the
/// House has seen about the view's middle, as near as the view comes and
/// from where it lies, the quieter the calmer the Still lies; told to the
/// sound as it changes. Which strand is heard is held in NullmereWorldTests
/// (`ShoreSoundTests`), how it sounds in NullmereSoundTests.
final class ShoreHeardTests: XCTestCase {
    @MainActor
    func testTheSessionHearsTheStrandTheHouseHasSeenNearTheView() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var state = GameState(settings: GameSettings(seedText: "shore", keepers: 1))
        let me = state.player
        let map = state.map
        func isEdge(_ hex: Hex) -> Bool {
            guard let tile = map[hex], ShoreSound.isLake(tile.terrain) else { return false }
            return hex.neighbors.contains { map[$0].map { !$0.terrain.isWater } ?? false }
        }
        // The strand with the most strand about it.
        let strand = try XCTUnwrap(map.hexes.filter(isEdge).max { a, b in
            (a.spiral(3).filter(isEdge).count, b) < (b.spiral(3).filter(isEdge).count, a)
        })

        // Unseen water is not heard, however near the view comes.
        state.houses[me].explored = Explored(repeating: false, count: map.count)
        let blind = GameSession(state: state, store: LocalStore(directory: dir.appendingPathComponent("blind")))
        var camera = blind.camera
        camera.focus(on: strand)
        camera.heading = 0
        camera.scale = ShoreSound.fullest
        blind.camera = camera
        XCTAssertNil(blind.shoreSound(), "Water the House has not seen is not heard")

        state.houses[me].explored = Explored(repeating: true, count: map.count)
        let session = GameSession(state: state, store: LocalStore(directory: dir.appendingPathComponent("seen")))
        camera.scale = Camera.minimumScale
        session.camera = camera
        XCTAssertNil(session.shoreSound(), "Well back, the shore is not heard")
        camera.scale = ShoreSound.fullest
        session.camera = camera
        let close = try XCTUnwrap(session.shoreSound())
        XCTAssertGreaterThan(close.level, 0.3, "The strand all about the view's middle, close")
        XCTAssertLessThanOrEqual(abs(close.pan), 1)
        camera.scale = (ShoreSound.faintest + ShoreSound.fullest) / 2
        session.camera = camera
        XCTAssertLessThan(try XCTUnwrap(session.shoreSound()).level, close.level, "Farther back, fainter")
        camera.scale = ShoreSound.fullest

        // The calmer the Still lies, the quieter it laps.
        state.calm = Calm.deepest
        let calm = GameSession(state: state, store: LocalStore(directory: dir.appendingPathComponent("calm")))
        calm.camera = camera
        session.camera = camera
        let stilled = try XCTUnwrap(calm.shoreSound())
        XCTAssertEqual(stilled.level, try XCTUnwrap(session.shoreSound()).level * 0.25, accuracy: 0.01)

        // Told to the sound as it changes, not every frame; still under the
        // stillest motion.
        var heard: [(Float, Float)] = []
        session.onShore = { heard.append(($0, $1)) }
        session.hearShore()
        XCTAssertEqual(heard.count, 1)
        session.hearShore()
        XCTAssertEqual(heard.count, 1, "Told as it changes, not every frame")
        camera.scale = Camera.minimumScale
        session.camera = camera
        session.hearShore()
        XCTAssertEqual(heard.last?.0, 0, "Drawn back, silent again")
        camera.scale = ShoreSound.fullest
        session.camera = camera
        session.hearShore()
        XCTAssertGreaterThan(heard.last?.0 ?? 0, 0.3)
        session.motion = .still
        session.hearShore()
        XCTAssertEqual(heard.last?.0, 0, "Still under the stillest motion")
        Ambience(enabled: false).setShore(level: 0.5, pan: 0)
    }
}
