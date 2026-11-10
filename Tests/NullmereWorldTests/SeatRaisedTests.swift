import Foundation
import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

/// A seat raised anew is seen where it rises: the moon's light drawn down
/// on its new ground in a shaft and laid about it in rings and spokes, a
/// cold light swelling over it and dying away, and dust thrown up as its
/// walls stand; where it stood, dust settles over the bare ground.
final class SeatRaisedTests: XCTestCase {
    private let ground = Vec3(3, 0.2, -2)
    private let stood = Vec3(-4, 0.1, 5)

    private func happenings() -> Happenings {
        var happenings = Happenings()
        happenings.seatsRaised = [Happenings.Spot(at: ground, start: 5, seed: 41)]
        happenings.seatsLeft = [Happenings.Spot(at: stood, start: 5, seed: 41)]
        return happenings
    }

    private func flat(_ mote: Mote, from centre: Vec3) -> Float {
        (Vec3(mote.place.x, 0, mote.place.z) - Vec3(centre.x, 0, centre.z)).length
    }

    /// Pure light, the moon's own cold hue.
    private func moonlight(at time: Float) -> [Mote] {
        happenings().effects(at: time).motes.filter { $0.colour.w == 0 && $0.colour.z > $0.colour.x && $0.colour.z > 0 }
    }

    /// Dust: what hides what lies behind it.
    private func dust(at time: Float) -> [Mote] {
        happenings().effects(at: time).motes.filter { $0.colour.w > 0 }
    }

    func testTheMoonsLightIsDrawnDownOnItsNewGround() {
        XCTAssertTrue(moonlight(at: 4.9).isEmpty, "nothing before")
        let lit = moonlight(at: 5.4)
        XCTAssertFalse(lit.isEmpty)
        XCTAssertTrue(lit.allSatisfy { flat($0, from: ground) <= Happenings.seatRaisedReach * 1.01 }, "about its new ground alone")
        XCTAssertTrue(lit.contains { $0.place.y > ground.y + 1 }, "a shaft of it rising over the seat")
        let rings = lit.filter { abs($0.place.y - (ground.y + Effects.sigilLift)) < 1e-4 }
        XCTAssertTrue(rings.contains { flat($0, from: ground) > Happenings.seatRaisedReach * 0.9 }, "rings laid wide about it")
        XCTAssertTrue(moonlight(at: 5 + Effect.sigil.lifetime * 1.36).isEmpty, "gone in time")
    }

    func testDustRisesWithItsWallsAndSettlesWhereItStood() {
        XCTAssertTrue(dust(at: 4.9).isEmpty, "nothing before")
        let leaving = dust(at: 5.2)
        XCTAssertFalse(leaving.isEmpty, "dust where it stood at once")
        XCTAssertTrue(leaving.allSatisfy { flat($0, from: stood) < 3 }, "over the bare ground it left")
        let rising = dust(at: 5.8).filter { flat($0, from: ground) < 3 }
        XCTAssertFalse(rising.isEmpty, "and as its walls stand on the new")
        XCTAssertTrue(dust(at: 5.2).allSatisfy { flat($0, from: ground) > 3 }, "the new ground's a moment after the light comes")
        XCTAssertTrue(dust(at: 5.4 + Effect.dust.lifetime * 1.36).isEmpty, "settled in time")
    }

    func testAColdLightSwellsOverItAndDiesAway() {
        func light(at time: Float) -> PointLight? { happenings().effects(at: time).lights.first }
        XCTAssertNil(light(at: 4.9), "none before")
        let rising = light(at: 5.2)?.colour.z ?? 0
        let full = light(at: 5 + Happenings.seatRaisedGlow / 2)?.colour.z ?? 0
        let dying = light(at: 5 + Happenings.seatRaisedGlow * 0.9)?.colour.z ?? 0
        XCTAssertGreaterThan(full, rising, "swelling")
        XCTAssertGreaterThan(full, dying, "and dying away")
        XCTAssertGreaterThan(full, 1, "a light to see by")
        XCTAssertNil(light(at: 5 + Happenings.seatRaisedGlow + 0.01), "gone")
        let over = light(at: 6)
        XCTAssertGreaterThan(over?.colour.z ?? 0, over?.colour.x ?? 0, "cold, the moon's")
        XCTAssertEqual(over?.position.x ?? 0, ground.x, accuracy: 1e-5, "over the new ground")
        XCTAssertEqual(over?.position.z ?? 0, ground.z, accuracy: 1e-5)
        XCTAssertGreaterThan(over?.position.y ?? 0, ground.y)
        XCTAssertEqual(happenings().effects(at: 6).lights.count, 1, "none where it stood")
    }

    func testAMomentIsDrawnAlikeAndLeftOutWhenAsked() {
        let once = happenings().effects(at: 5.6).motes
        XCTAssertEqual(once, happenings().effects(at: 5.6).motes, "drawn alike each time")
        let plain = happenings().effects(at: 5.6, leaving: [.sigil, .pillar]).motes
        XCTAssertFalse(plain.isEmpty)
        XCTAssertLessThan(plain.count, once.count, "a film shot leaves out its rings and shaft, as a skill's")
    }
}
