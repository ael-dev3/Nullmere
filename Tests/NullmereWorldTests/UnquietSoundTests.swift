import Foundation
import NullmereCore
@testable import NullmereWorld
import XCTest

/// The unquiet dead, heard from the view: as near as the view comes, the
/// brighter their lights burn about the view's middle the louder, from where
/// they lie across the view; a sound half heard, from no further back than
/// the lake's lapping and only nearer the view's middle than fire. How it
/// sounds is held in NullmereSoundTests, the session hearing it in
/// NullmereKitTests (`UnquietHeardTests`).
final class UnquietSoundTests: XCTestCase {
    private let field = Hex(3, -2)

    private func rising(darkIn: Int, at hex: Hex? = nil) -> UnburiedSight {
        UnburiedSight(at: hex ?? field, troops: GameState.unquietAt, darkIn: darkIn)
    }

    func testTheDeadAreHeardAsNearAsTheViewComesAndAsBrightAsTheirLightsBurn() throws {
        var camera = Camera()
        camera.focus(on: field)
        camera.heading = 0
        let eve = rising(darkIn: 1)
        camera.scale = UnquietSound.faintest
        XCTAssertNil(UnquietSound.heard([eve], from: camera), "Well back, the dead are not heard")
        camera.scale = UnquietSound.fullest
        let close = try XCTUnwrap(UnquietSound.heard([eve], from: camera))
        XCTAssertEqual(close.level, 1 / UnquietSound.full, accuracy: 0.001, "A field that will rise, on the eve of the dark, at the view's middle")
        XCTAssertEqual(close.pan, 0, accuracy: 0.05, "about the middle")
        camera.scale = (UnquietSound.faintest + UnquietSound.fullest) / 2
        let farther = try XCTUnwrap(UnquietSound.heard([eve], from: camera))
        XCTAssertEqual(farther.level, close.level / 2, accuracy: 0.001, "Farther back, fainter")
        camera.scale = UnquietSound.fullest
        XCTAssertNil(UnquietSound.heard([], from: camera), "No dead, no sound")

        // The brighter their lights the louder: a month from the dark,
        // fainter; a field the land will take back, a glimmer, quieter than
        // one that will rise at its faintest.
        let month = try XCTUnwrap(UnquietSound.heard([rising(darkIn: GameState.lunarMonth)], from: camera))
        XCTAssertLessThan(month.level, close.level / 2, "A month from the dark, fainter")
        let few = UnburiedSight(at: field, troops: GameState.unquietAt - 1, darkIn: 1)
        let glimmer = try XCTUnwrap(UnquietSound.heard([few], from: camera))
        XCTAssertLessThan(glimmer.level, month.level, "Dead the land will take back, a glimmer of a sound")
        // Two fields at their brightest about the middle, as loud as the
        // dead get.
        let both = try XCTUnwrap(UnquietSound.heard([eve, rising(darkIn: 1, at: field.neighbors[0])], from: camera))
        XCTAssertEqual(both.level, 1, accuracy: 0.001, "As loud as the dead get, and no louder")
    }

    func testTheDeadAreHeardFromWhereTheyLieAndOnlyNearTheViewsMiddle() throws {
        var camera = Camera()
        camera.focus(on: field)
        camera.heading = 0
        camera.scale = UnquietSound.fullest
        let eve = rising(darkIn: 1)
        // A little to the right of the view: from the right; turned about,
        // from the left.
        camera.centerX -= 0.3 * 600 / camera.scale
        let right = try XCTUnwrap(UnquietSound.heard([eve], from: camera))
        XCTAssertGreaterThan(right.pan, 0.1, "From the right")
        camera.heading = .pi
        XCTAssertLessThan(try XCTUnwrap(UnquietSound.heard([eve], from: camera)).pan, -0.1, "Turned about, from the left")

        // Out toward the view's edge, where a fire would still be heard,
        // the dead are silent; and from further back than the lake's
        // lapping, though fire is heard there, they are not.
        camera.heading = 0
        camera.focus(on: field)
        camera.centerX -= 1.8 * 600 / camera.scale
        XCTAssertNotNil(FireSound.heard([field], from: camera), "A fire there is heard")
        XCTAssertNil(UnquietSound.heard([eve], from: camera), "but the dead there are not")
        camera.focus(on: field)
        camera.scale = (FireSound.faintest + UnquietSound.faintest) / 2
        XCTAssertNotNil(FireSound.heard([field], from: camera), "Fire is heard from back here")
        XCTAssertNil(UnquietSound.heard([eve], from: camera), "the dead not until the view comes nearer")
        XCTAssertEqual(UnquietSound.faintest, ShoreSound.faintest, "as near as the lake's lapping")
        XCTAssertEqual(UnquietSound.fullest, ShoreSound.fullest)

        // Far across the realm a field is not heard at all, and adds nothing
        // to one near.
        camera.scale = UnquietSound.fullest
        let far = rising(darkIn: 1, at: Hex(field.q + 24, field.r))
        XCTAssertNil(UnquietSound.heard([far], from: camera), "Dead far off are silent")
        let near = try XCTUnwrap(UnquietSound.heard([eve], from: camera))
        XCTAssertEqual(try XCTUnwrap(UnquietSound.heard([eve, far], from: camera)).level, near.level, accuracy: 0.001)
    }
}
