import Foundation
@testable import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

/// Where the dead lie unburied, corpse-lights hang over the field: more the
/// more lie there, brighter as the dark of the moon nears over a field that
/// will rise, cold and pale, straying and breathing, still where motion is
/// reduced, and seen from across the realm.
final class CorpseLightsTests: XCTestCase {
    private let state = GameState(settings: GameSettings(seedText: "corpse lights", houseCount: 4, radius: 14, keepers: 1))
    private var stage: WorldStage { WorldStage(map: state.map, relief: Relief(map: state.map)) }
    private let field = Hex(3, -6)

    private func flat(_ a: Vec3, _ b: (x: Float, z: Float)) -> Float {
        ((a.x - b.x) * (a.x - b.x) + (a.z - b.z) * (a.z - b.z)).squareRoot()
    }

    func testMoreLightsTheMoreLieThereAndMostOverAFieldThatWillRise() {
        XCTAssertEqual(WorldStage.corpseLightCount(troops: 0), 0, "none where none lie")
        XCTAssertEqual(WorldStage.corpseLightCount(troops: 400), 1, "one over a few")
        XCTAssertEqual(WorldStage.corpseLightCount(troops: 3_000), 2)
        XCTAssertEqual(WorldStage.corpseLightCount(troops: GameState.unquietAt - 1), 2, "the land takes these back")
        XCTAssertEqual(WorldStage.corpseLightCount(troops: GameState.unquietAt), 3, "these rise: three at the least")
        XCTAssertEqual(WorldStage.corpseLightCount(troops: GameState.unquietAt + GameState.unquietPerLevel), 4, "one more a level")
        XCTAssertEqual(WorldStage.corpseLightCount(troops: 90_000), WorldStage.corpseLightsMost, "never more than the most")
    }

    func testBrighterAsTheDarkOfTheMoonNearsOverAFieldThatWillRise() {
        let month = GameState.lunarMonth
        func strength(_ troops: Int, _ darkIn: Int) -> Float {
            WorldStage.corpseStrength(UnburiedSight(at: field, troops: troops, darkIn: darkIn))
        }
        XCTAssertEqual(strength(8_000, 1), 1, accuracy: 0.0001, "full on the eve of the dark")
        XCTAssertEqual(strength(8_000, month), 0.35, accuracy: 0.0001, "faint a month off")
        XCTAssertEqual(strength(8_000, 0), strength(8_000, month), "fallen at the dark itself, they wait the month round")
        XCTAssertLessThan(strength(8_000, 20), strength(8_000, 5), "brighter as it nears")
        XCTAssertLessThanOrEqual(strength(2_000, 1), 0.3 + 0.0001, "a glimmer over a field the land takes back, however near")
        XCTAssertLessThan(strength(2_000, 1), strength(8_000, month), "fainter than one that will rise, at its faintest")
    }

    func testEachFieldsLightsHangLowOverItInAColdPaleGlow() throws {
        let sights = [UnburiedSight(at: field, troops: 10_000, darkIn: 3), UnburiedSight(at: Hex(-4, 2), troops: 700, darkIn: 3)]
        // Seen from over the greater field, so its lights come first.
        let centre = Relief.centre(of: field)
        let lit = stage.corpseLights(sights, near: Vec3(centre.x, 0, centre.z), scale: 60, time: 7)
        XCTAssertEqual(lit.motes.count, 2 * (4 + 1), "a flame and its glow for each light")
        XCTAssertEqual(lit.lights.count, 2, "and one light over each field")
        let over = lit.motes.prefix(8)
        for mote in over {
            let at = Vec3(mote.place.x, mote.place.y, mote.place.z)
            XCTAssertLessThan(flat(at, centre), WorldStage.corpseFarthest + WorldStage.corpseWander * 1.5, "over its own field")
            let ground = stage.ground(atX: at.x, z: at.z)
            XCTAssertGreaterThan(at.y, ground + 0.03, "hanging over the ground")
            XCTAssertLessThan(at.y, ground + 0.36, "and low")
            XCTAssertGreaterThan(mote.colour.y, mote.colour.x * 1.8, "cold and pale, no fire's")
            XCTAssertGreaterThan(mote.colour.z, mote.colour.x * 1.5)
            XCTAssertEqual(mote.colour.w, 0, "light only: it hides nothing")
        }
        let flames = over.enumerated().filter { $0.offset % 2 == 0 }.map(\.element)
        // No two so near each other, or at so like a height, that they read
        // as a pair of eyes.
        for (a, first) in flames.enumerated() {
            for second in flames.dropFirst(a + 1) {
                let apart = ((first.place.x - second.place.x) * (first.place.x - second.place.x)
                    + (first.place.z - second.place.z) * (first.place.z - second.place.z)).squareRoot()
                XCTAssertGreaterThan(apart, 0.08, "each in its own place")
            }
        }
        XCTAssertGreaterThan(Set(flames.map { Int($0.place.y * 50) }).count, 2, "at their own heights")

    }

    func testTheyStrayAndBreatheButHangStillWhereMotionIsReduced() {
        let sights = [UnburiedSight(at: field, troops: 7_000, darkIn: 2)]
        let now = stage.corpseLights(sights, near: Vec3(0, 0, 0), scale: 60, time: 3)
        let later = stage.corpseLights(sights, near: Vec3(0, 0, 0), scale: 60, time: 9)
        XCTAssertNotEqual(now.motes.map(\.place), later.motes.map(\.place), "straying about their places")
        XCTAssertNotEqual(now.motes.map(\.colour), later.motes.map(\.colour), "and breathing in and out")
        let stillNow = stage.corpseLights(sights, near: Vec3(0, 0, 0), scale: 60, time: 3, still: true)
        let stillLater = stage.corpseLights(sights, near: Vec3(0, 0, 0), scale: 60, time: 9, still: true)
        XCTAssertEqual(stillNow.motes, stillLater.motes, "still where motion is reduced")
        XCTAssertEqual(stillNow.motes.count, now.motes.count, "and none the fewer")
    }

    /// The dead risen as Barrowkin carry the lights of the field they rose
    /// from, as many as hung over it and as bright as on the eve of the
    /// dark; they are drawn pale and cold, no House's, and those risen this
    /// watch come up out of the dark.
    func testTheRisenCarryTheirFieldsLightsAndComeUpOutOfTheDark() throws {
        XCTAssertEqual(UnburiedSight.risen(at: field, level: 1).troops, GameState.unquietAt)
        XCTAssertTrue(UnburiedSight.risen(at: field, level: 1).rises)
        XCTAssertEqual(WorldStage.corpseLightCount(troops: UnburiedSight.risen(at: field, level: 3).troops), 5, "three and one a level past the first")
        XCTAssertEqual(WorldStage.corpseStrength(UnburiedSight.risen(at: field, level: 2)), 1, accuracy: 0.0001, "as bright as on the eve")
        XCTAssertEqual(WorldStage.risenShowing(age: 0), 0)
        XCTAssertEqual(WorldStage.risenShowing(age: WorldStage.risingSeconds / 2), 0.5, accuracy: 0.0001)
        XCTAssertEqual(WorldStage.risenShowing(age: WorldStage.risingSeconds * 2), 1)
        XCTAssertEqual(WorldStage.risenShowing(age: 0, still: true), 1, "whole at once where motion is reduced")
        // Drawn in their own pale colour, not a House's.
        let centre = Relief.centre(of: field)
        var pose = CompanyPose(unit: -40, key: .wild(tier: 1), sigil: 0, health: 100, hex: field,
                               position: Vec3(centre.x, stage.ground(atX: centre.x, z: centre.z), centre.z), heading: 0, isOwn: false)
        let red = Vec4(0.9, 0.1, 0.1, 1)
        var frame = SceneFrame()
        let plain = stage.companies([pose], houses: [red], into: &frame).flatMap(\.instances)
        XCTAssertFalse(plain.isEmpty)
        XCTAssertTrue(plain.allSatisfy { $0.colour == red }, "a wild as before, in the colour its sigil gives")
        pose.colour = WorldStage.barrowkinColour
        let risen = stage.companies([pose], houses: [red], into: &frame).flatMap(\.instances)
        XCTAssertEqual(risen.count, plain.count)
        XCTAssertTrue(risen.allSatisfy { $0.colour == WorldStage.barrowkinColour }, "the risen dead pale and cold")
    }

    /// A field buried releases its dead: its lights rise from it into the
    /// night, drawing in and fading, and are gone a few seconds on.
    func testABuriedFieldsLightsRiseAndFade() throws {
        XCTAssertTrue(stage.releasedLights(at: field, troops: 9_000, age: -0.1, scale: 60).isEmpty, "not before it is buried")
        XCTAssertTrue(stage.releasedLights(at: field, troops: 9_000, age: WorldStage.releaseSeconds, scale: 60).isEmpty, "gone after")
        XCTAssertTrue(stage.releasedLights(at: field, troops: 0, age: 1, scale: 60).isEmpty, "none where none lay")
        let early = stage.releasedLights(at: field, troops: 9_000, age: 0.5, scale: 60)
        let later = stage.releasedLights(at: field, troops: 9_000, age: 3, scale: 60)
        XCTAssertEqual(early.count, 2 * WorldStage.corpseLightCount(troops: 9_000), "as many as hung over it")
        XCTAssertEqual(later.count, early.count)
        let centre = Relief.centre(of: field)
        for (a, b) in zip(early, later) {
            XCTAssertGreaterThan(b.place.y, a.place.y + 0.3, "rising into the night")
            XCTAssertLessThanOrEqual(flat(Vec3(b.place.x, 0, b.place.z), centre), flat(Vec3(a.place.x, 0, a.place.z), centre) + 0.001,
                                     "drawing in toward the barrow's heart")
            XCTAssertEqual(b.colour.w, 0, "light only")
        }
        XCTAssertLessThan(try XCTUnwrap(later.first).colour.y, try XCTUnwrap(early.first).colour.y, "fading as they climb")
        XCTAssertGreaterThan(try XCTUnwrap(early.first).colour.y, try XCTUnwrap(early.first).colour.x * 1.8, "cold and pale")
    }

    /// The dead lie quiet the watch they fall, and any watch their field is
    /// fought over: their lights kindle once it falls quiet, so no battle is
    /// fought under them.
    func testTheLightsKindleOnceAFieldFallsQuiet() {
        let fallenNow = FieldOfDead(at: field, troops: 8_000, houses: [0], since: 12)
        let fallenBefore = FieldOfDead(at: Hex(-4, 2), troops: 3_000, houses: [1], since: 10)
        let foughtOver = FieldOfDead(at: Hex(1, 1), troops: 7_000, houses: [0, 1], since: 9)
        let besideIt = FieldOfDead(at: Hex(2, 1), troops: 6_500, houses: [1], since: 9)
        let fields = [fallenNow, fallenBefore, foughtOver, besideIt]
        XCTAssertEqual(UnburiedSight.kindled(fields, watch: 12, darkIn: 5).map(\.at), [Hex(-4, 2), Hex(1, 1), Hex(2, 1)],
                       "none over the dead fallen this watch")
        XCTAssertEqual(UnburiedSight.kindled([fallenBefore], watch: 12, darkIn: 5), [UnburiedSight(at: Hex(-4, 2), troops: 3_000, darkIn: 5)],
                       "each lit with how many lie there and the watches to the dark")
        // A blow struck from one field onto the next this watch: both are
        // fought over, and their dead lie quiet while they are.
        let blow = FieldBlow(from: Hex(1, 1), at: Hex(2, 1), struck: nil, striker: nil, watch: 12, seed: 1)
        XCTAssertEqual(UnburiedSight.kindled(fields, watch: 12, darkIn: 5, blows: [blow]).map(\.at), [Hex(-4, 2)],
                       "nor over a field a blow is struck on or from this watch")
        let lastWatch = FieldBlow(from: Hex(1, 1), at: Hex(2, 1), struck: nil, striker: nil, watch: 11, seed: 1)
        XCTAssertEqual(UnburiedSight.kindled(fields, watch: 12, darkIn: 5, blows: [lastWatch]).count, 3, "kindled once it falls quiet")
        XCTAssertTrue(UnburiedSight.kindled(fields, watch: 9, darkIn: 5).isEmpty, "none before any of them have lain a watch")
        XCTAssertTrue(UnburiedSight.kindled([], watch: 12, darkIn: 5, blows: [blow]).isEmpty, "none where none lie")
    }

    /// Close in, a light's glow is a halo about its flame, however near the
    /// view comes: a disc that faces the eye, where the men about it stand
    /// upright under a camera looking steeply down, so a glow as wide as
    /// half a man is tall had looked three times his height. A buried
    /// field's rising lights the same.
    func testCloseInTheGlowIsAHaloAboutItsFlame() throws {
        let close = stage.corpseLights([UnburiedSight(at: field, troops: 9_000, darkIn: 1)], near: Vec3(0, 0, 0), scale: 400, time: 1)
        let flame = try XCTUnwrap(close.motes.first).place.w, glow = try XCTUnwrap(close.motes.last).place.w
        XCTAssertLessThanOrEqual(glow, 2.5 * flame, "no wider than two and a half of its flame")
        XCTAssertGreaterThan(glow, 2 * flame, "and wider than its flame")
        let man = Library.model(.figure(.spear, tier: 1)).mesh.bounds
        XCTAssertLessThan(2 * glow, (man.max.y - man.min.y) * WorldStage.figureScale / 4, "a quarter of a spearman's height across, his spear and all")
        let rising = try XCTUnwrap(stage.releasedLights(at: field, troops: 9_000, age: 1, scale: 400).last).place.w
        XCTAssertLessThanOrEqual(rising, 2.5 * flame, "a buried field's lights the same")
    }

    func testSeenFromAcrossTheRealmTheNearestFieldsFirst() throws {
        let sights = [UnburiedSight(at: field, troops: 9_000, darkIn: 1)]
        let near = stage.corpseLights(sights, near: Vec3(0, 0, 0), scale: 80, time: 1)
        let afar = stage.corpseLights(sights, near: Vec3(0, 0, 0), scale: 6, time: 1)
        let nearGlow = try XCTUnwrap(near.motes.last).place.w, afarGlow = try XCTUnwrap(afar.motes.last).place.w
        XCTAssertGreaterThan(afarGlow, nearGlow * 4, "its glow keeps its size on the screen as the view draws away")
        // Thirty fields in a ring: the twenty-four nearest the view are lit.
        let ring = state.map.hexes.filter { $0.distance(to: Hex(0, 0)) <= 6 }.sorted().prefix(30)
        let many = ring.map { UnburiedSight(at: $0, troops: 6_000, darkIn: 4) }
        let lit = stage.corpseLights(many, near: Vec3(0, 0, 0), scale: 30, time: 1)
        XCTAssertEqual(lit.lights.count, WorldStage.corpseFieldsMost)
        let nearest = try XCTUnwrap(many.min { lhs, rhs in
            let a = Relief.centre(of: lhs.at), b = Relief.centre(of: rhs.at)
            return a.x * a.x + a.z * a.z < b.x * b.x + b.z * b.z
        })
        let heart = Relief.centre(of: nearest.at)
        XCTAssertTrue(lit.lights.contains { abs($0.position.x - heart.x) < 0.001 && abs($0.position.z - heart.z) < 0.001 },
                      "the nearest field among them")
        XCTAssertEqual(stage.corpseLights([], near: Vec3(0, 0, 0), scale: 30, time: 1).motes, [], "none where none lie")
    }
}
