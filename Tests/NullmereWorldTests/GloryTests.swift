import Foundation
import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

/// A company come through the fighting a rank higher, or led by a
/// commander risen a level, is lit where it stands a moment: points of
/// gold rising about it in a slow spiral, close about it as they leave the
/// ground, and a warm light swelling over it and dying away.
final class GloryTests: XCTestCase {
    private let company = Vec3(2, 0.3, -1)

    private func happenings() -> Happenings {
        var happenings = Happenings()
        happenings.glories = [Happenings.Spot(at: company, start: 5, seed: 23)]
        return happenings
    }

    /// The gold of a glory: light only, warm, hiding nothing.
    private func gold(at time: Float) -> [Mote] {
        happenings().effects(at: time).motes.filter { $0.colour.w == 0 && $0.colour.x > $0.colour.z * 2.5 }
    }

    private func flat(_ mote: Mote) -> Float {
        (Vec3(mote.place.x, 0, mote.place.z) - Vec3(company.x, 0, company.z)).length
    }

    private func height(_ motes: [Mote]) -> Float {
        motes.map(\.place.y).reduce(0, +) / Float(max(motes.count, 1))
    }

    func testGoldRisesCloseAboutTheCompany() {
        XCTAssertTrue(gold(at: 4.9).isEmpty, "nothing before")
        let early = gold(at: 5.3)
        XCTAssertEqual(early.count, Happenings.gloryMotes, "every point kindled")
        for mote in early {
            XCTAssertGreaterThan(flat(mote), 0.2, "about the company, not on its heart")
            XCTAssertLessThan(flat(mote), 0.55, "close about it")
            XCTAssertGreaterThan(mote.place.y, company.y, "off the ground")
            XCTAssertLessThan(mote.place.w, 0.03, "small points")
        }
        let late = gold(at: 6.3)
        XCTAssertGreaterThan(height(late), height(early) + 0.3, "climbing as it goes")
        XCTAssertGreaterThan(late.map(flat).reduce(0, +) / Float(late.count), early.map(flat).reduce(0, +) / Float(early.count),
                             "widening a little as it climbs")
        XCTAssertTrue(gold(at: 5 + Effect.glory.lifetime * 1.36).isEmpty, "gone in time")
    }

    func testItTurnsOneWayRoundAndFadesAsItClimbs() {
        let first = gold(at: 5.3), then = gold(at: 5.5)
        XCTAssertEqual(first.count, then.count, "the same points, a moment on")
        for (a, b) in zip(first, then) {
            let before = atan2(Double(a.place.z - company.z), Double(a.place.x - company.x))
            let after = atan2(Double(b.place.z - company.z), Double(b.place.x - company.x))
            var turned = after - before
            if turned > .pi { turned -= 2 * .pi }
            if turned < -.pi { turned += 2 * .pi }
            XCTAssertGreaterThan(turned, 0.1, "each the same way round")
            XCTAssertLessThan(turned, 0.6, "slowly")
        }
        func brightness(_ motes: [Mote]) -> Float { motes.map(\.colour.x).reduce(0, +) / Float(max(motes.count, 1)) }
        XCTAssertGreaterThan(brightness(gold(at: 5.4)), brightness(gold(at: 6.6)) * 1.5, "brightest low, fading as it climbs")
        XCTAssertLessThan(brightness(gold(at: 5.02)), brightness(gold(at: 5.3)), "quick to kindle, not there at once")
    }

    func testAWarmLightSwellsOverItAndDiesAway() {
        func light(at time: Float) -> PointLight? { happenings().effects(at: time).lights.first }
        XCTAssertNil(light(at: 4.9), "none before")
        let rising = light(at: 5.2)?.colour.x ?? 0
        let full = light(at: 5 + Happenings.gloryGlow / 2)?.colour.x ?? 0
        let dying = light(at: 5 + Happenings.gloryGlow * 0.9)?.colour.x ?? 0
        XCTAssertGreaterThan(full, rising, "swelling")
        XCTAssertGreaterThan(full, dying, "and dying away")
        XCTAssertGreaterThan(full, 1, "a light to see by")
        XCTAssertNil(light(at: 5 + Happenings.gloryGlow + 0.01), "gone")
        let over = light(at: 5.9)
        XCTAssertGreaterThan(over?.colour.x ?? 0, (over?.colour.z ?? 0) * 2, "warm")
        XCTAssertEqual(over?.position.x ?? 0, company.x, accuracy: 1e-5, "over the company")
        XCTAssertEqual(over?.position.z ?? 0, company.z, accuracy: 1e-5)
        XCTAssertGreaterThan(over?.position.y ?? 0, company.y)
    }

    func testEachGloryIsItsOwnAndAMomentIsDrawnAlike() {
        var two = Happenings()
        two.glories = [Happenings.Spot(at: company, start: 5, seed: 23), Happenings.Spot(at: Vec3(-3, 0.1, 4), start: 5.5, seed: 29)]
        let motes = two.effects(at: 5.8).motes
        XCTAssertEqual(motes.count, 2 * Happenings.gloryMotes)
        XCTAssertEqual(two.effects(at: 5.8).lights.count, 2)
        XCTAssertEqual(motes, two.effects(at: 5.8).motes, "drawn alike each time")
        XCTAssertEqual(motes.filter { $0.place.x < 0 }.count, Happenings.gloryMotes, "each about its own company")
    }
}
