import Foundation
import NullmereCore
@testable import NullmereWorld
import XCTest

/// The blackwood burning, heard from the view: as near as the view comes,
/// the more of it alight about the view's middle the louder, from where it
/// burns across the view, and from further back than the lake's lapping.
/// How it sounds is held in NullmereSoundTests, the session hearing it in
/// NullmereKitTests (`FireHeardTests`).
final class FireSoundTests: XCTestCase {
    private static let state = GameState(settings: GameSettings(seedText: "stage", houseCount: 4, radius: 12, keepers: 1))

    func testTheFireIsHeardAsNearAsTheViewComesAndFromWhereItBurns() throws {
        let map = Self.state.map
        let wood = try XCTUnwrap(map.hexes.first { hex in
            map[hex]?.terrain == .blackwood && hex.neighbors.allSatisfy { map[$0]?.terrain == .blackwood }
        })
        let burning = [wood] + wood.neighbors
        var camera = Camera()
        camera.focus(on: wood)
        camera.heading = 0
        camera.scale = FireSound.faintest - 2
        XCTAssertNil(FireSound.heard(burning, from: camera), "Well back, the fire is not heard")
        camera.scale = FireSound.fullest
        let close = try XCTUnwrap(FireSound.heard(burning, from: camera))
        XCTAssertEqual(close.level, 1, accuracy: 0.001, "The wood alight all about the view's middle, close: as loud as fire gets")
        XCTAssertEqual(close.pan, 0, accuracy: 0.2, "about the middle")
        camera.scale = (FireSound.faintest + FireSound.fullest) / 2
        let farther = try XCTUnwrap(FireSound.heard(burning, from: camera))
        XCTAssertLessThan(farther.level, close.level, "Farther back, fainter")
        XCTAssertGreaterThan(farther.level, 0.2)
        // Heard from further back than the lake's lapping is.
        camera.scale = ShoreSound.faintest
        XCTAssertNotNil(FireSound.heard(burning, from: camera), "heard where the shore is not yet")
        camera.scale = FireSound.fullest
        XCTAssertNil(FireSound.heard([], from: camera), "No fire, no sound")

        // One tile alight a little to the right of the view: quieter than
        // the wood all about, from the right; the view turned about, from
        // the left.
        camera.centerX -= 0.3 * 600 / camera.scale
        let one = try XCTUnwrap(FireSound.heard([wood], from: camera))
        XCTAssertGreaterThan(one.pan, 0.1, "From the right")
        XCTAssertLessThan(one.level, close.level / 2, "One tile alight quieter than the wood all about")
        camera.heading = .pi
        XCTAssertLessThan(try XCTUnwrap(FireSound.heard([wood], from: camera)).pan, -0.1, "Turned about, from the left")

        // Far across the realm, out of the view, a fire is not heard at all.
        camera.heading = 0
        camera.focus(on: wood)
        let far = Hex(wood.q + 24, wood.r)
        XCTAssertNil(FireSound.heard([far], from: camera), "A fire far off is silent")
        let louder = try XCTUnwrap(FireSound.heard(burning + [far], from: camera))
        XCTAssertEqual(louder.level, close.level, accuracy: 0.001, "and adds nothing to one near")
    }
}
