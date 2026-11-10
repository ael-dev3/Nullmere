import Foundation
@testable import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

/// Where a battle was fought, the field keeps its dead a while: each side's
/// men lying on its own side of where the fronts met, fewer each watch, the
/// arrows of a volley standing in the ground about those it felled, and
/// birds come down to a field fought lately.
final class FieldDeadTests: XCTestCase {
    private let state = GameState(settings: GameSettings(seedText: "field dead", houseCount: 4, radius: 14, keepers: 1))
    private let red = Vec4(0.8, 0.1, 0.1, 1), blue = Vec4(0.1, 0.2, 0.8, 1)
    private let spears = ModelKey.figure(.spear, tier: 2), bows = ModelKey.figure(.bow, tier: 1)

    private func centre(_ hex: Hex) -> Vec3 {
        let at = Relief.centre(of: hex)
        return Vec3(at.x, 0, at.z)
    }

    private func flat(_ a: Vec3, _ b: Vec3) -> Float {
        ((a.x - b.x) * (a.x - b.x) + (a.z - b.z) * (a.z - b.z)).squareRoot()
    }

    private func melee(watch: Int = 5, seed: Int = 7) -> FieldBlow {
        FieldBlow(from: Hex(2, -6), at: Hex(3, -6), struck: .init(kind: spears, colour: red, troops: 2_000),
                  striker: .init(kind: bows, colour: blue, troops: 500), watch: watch, seed: seed)
    }

    private func volley(watch: Int = 5) -> FieldBlow {
        FieldBlow(from: Hex(1, -6), at: Hex(3, -6), struck: .init(kind: spears, colour: red, troops: 900),
                  striker: nil, watch: watch, seed: 11)
    }

    func testTheDeadThinOutOverThreeWatchesAndAreGone() {
        XCTAssertEqual((0..<4).map { WorldStage.deadCount(troops: 2_000, since: $0) }, [5, 4, 2, 0],
                       "a full field's dead, fewer each watch, gone after three")
        XCTAssertEqual((0..<4).map { WorldStage.deadCount(troops: 1, since: $0) }, [1, 1, 1, 0], "any fallen leave one lying")
        XCTAssertEqual(WorldStage.deadCount(troops: 500, since: 0), 2, "one, and one more for each four hundred")
        XCTAssertEqual(WorldStage.deadCount(troops: 90_000, since: 0), WorldStage.deadMost, "never more than the most")
        XCTAssertEqual(WorldStage.deadCount(troops: 0, since: 0), 0, "none fallen, none lying")
        XCTAssertEqual(WorldStage.deadCount(troops: 2_000, since: -1), 0, "nothing before the blow")
    }

    func testAHorseWithItsRiderOrAnEngineLiesForTwoMenAndWider() throws {
        XCTAssertEqual(WorldStage.deadWeight(of: spears), 1)
        XCTAssertEqual(WorldStage.deadWeight(of: .figure(.rider, tier: 3)), 2)
        XCTAssertEqual(WorldStage.deadWeight(of: .figure(.mangonel, tier: 1)), 2)
        let riders = try XCTUnwrap(Heritage.allCases.first { $0.signature == .rider })
        let footmen = try XCTUnwrap(Heritage.allCases.first { $0.signature == .spear })
        XCTAssertEqual(WorldStage.deadWeight(of: .signature(riders)), 2)
        XCTAssertEqual(WorldStage.deadWeight(of: .signature(footmen)), 1)
        XCTAssertEqual((0..<4).map { WorldStage.deadLying(.figure(.rider, tier: 1), troops: 2_000, since: $0) }, [3, 2, 1, 0],
                       "half as many horses as men would lie, and still one for any fallen")
        XCTAssertEqual((0..<4).map { WorldStage.deadLying(spears, troops: 2_000, since: $0) }, [5, 4, 2, 0])
        // Drawn so, and lying wider about the struck.
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        var frame = SceneFrame()
        let horses = FieldBlow(from: Hex(1, -6), at: Hex(3, -6), struck: .init(kind: .figure(.rider, tier: 1), colour: red, troops: 2_000),
                               striker: nil, watch: 5, seed: 13)
        let lying = try XCTUnwrap(stage.fieldDead([horses], watch: 5, time: 1, birds: false, into: &frame)
            .first { $0.key == .figure(.rider, tier: 1) }).instances
        XCTAssertEqual(lying.count, 3)
        let wide = WorldStage.deadPlaces(of: horses, struck: true, count: 3, wide: WorldStage.heavyDeadWider)
        XCTAssertEqual(lying.map { $0.model.transformPoint(.zero).x }, wide.map(\.at.x))
        XCTAssertTrue(wide.allSatisfy { flat($0.at, centre(horses.at)) <= WorldStage.deadAbout * WorldStage.heavyDeadWider + 1e-4 })
        XCTAssertGreaterThan(wide.map { flat($0.at, centre(horses.at)) }.max() ?? 0, WorldStage.deadAbout * 0.6, "not heaped on the heart")
    }

    func testEachSidesDeadLieOnItsOwnSideOfTheLineWhereTheFrontsMet() {
        let blow = melee()
        let struck = centre(blow.at), striker = centre(blow.from)
        let way = struck - striker, middle = striker + way * 0.5
        let length = flat(struck, striker)
        func depth(_ point: Vec3) -> Float {  // toward the struck, from the meeting line, as a share of the way
            ((point.x - middle.x) * way.x + (point.z - middle.z) * way.z) / (length * length)
        }
        func across(_ point: Vec3) -> Float {
            abs((point.x - middle.x) * way.z - (point.z - middle.z) * way.x) / (length * length)
        }
        let theirs = WorldStage.deadPlaces(of: blow, struck: true, count: 5)
        let ours = WorldStage.deadPlaces(of: blow, struck: false, count: 5)
        XCTAssertEqual(theirs.count, 5)
        for place in theirs {
            XCTAssertGreaterThanOrEqual(depth(place.at), WorldStage.deadNear - 1e-4, "the struck's dead on the struck's side")
            XCTAssertLessThanOrEqual(depth(place.at), WorldStage.deadNear + WorldStage.deadDeep + 1e-4, "near the line, not back at its heart")
            XCTAssertLessThanOrEqual(across(place.at), WorldStage.deadAlong + 1e-4, "along the line, not beyond the front")
        }
        for place in ours {
            XCTAssertLessThanOrEqual(depth(place.at), -WorldStage.deadNear + 1e-4, "the striker's dead on the striker's side")
            XCTAssertGreaterThanOrEqual(depth(place.at), -(WorldStage.deadNear + WorldStage.deadDeep) - 1e-4)
        }
        // Facing the foe as they fell, or near it.
        let toward = CompanyPose.heading(from: blow.at, to: blow.from)
        for place in theirs {
            let off = atan2(sin(Double(place.heading - toward)), cos(Double(place.heading - toward)))
            XCTAssertLessThanOrEqual(abs(off), Double(WorldStage.deadTurned) + 1e-3)
        }
        // Spread out, not heaped on one spot, nor lying all one way.
        XCTAssertGreaterThan(Set(theirs.map { Int($0.at.x * 100) * 1_000 + Int($0.at.z * 100) }).count, 3)
        let headings = theirs.map(\.heading)
        XCTAssertGreaterThan((headings.max() ?? 0) - (headings.min() ?? 0), 1)
    }

    func testTheDeadOfAVolleyLieAboutTheStruck() {
        let blow = volley()
        XCTAssertTrue(blow.isRanged)
        let heart = centre(blow.at)
        let places = WorldStage.deadPlaces(of: blow, struck: true, count: 5)
        XCTAssertTrue(places.allSatisfy { flat($0.at, heart) <= WorldStage.deadAbout + 1e-4 }, "about the struck's heart")
        XCTAssertFalse(melee().isRanged)
    }

    func testABlowLaysItsDeadTheSameEachFrameTheFirstCarriedOffLast() {
        let blow = melee()
        let five = WorldStage.deadPlaces(of: blow, struck: true, count: 5)
        let again = WorldStage.deadPlaces(of: blow, struck: true, count: 5)
        let two = WorldStage.deadPlaces(of: blow, struck: true, count: 2)
        XCTAssertEqual(five.map(\.at), again.map(\.at))
        XCTAssertEqual(five.map(\.heading), again.map(\.heading))
        XCTAssertEqual(two.map(\.at), Array(five.prefix(2)).map(\.at), "as they are carried off the rest lie where they lay")
        XCTAssertNotEqual(WorldStage.deadPlaces(of: melee(seed: 8), struck: true, count: 5).map(\.at), five.map(\.at),
                          "another blow's dead lie otherwise")
    }

    func testEachManLiesAsHeFellInHisColourFewerEachWatch() throws {
        let relief = Relief(map: state.map)
        let stage = WorldStage(map: state.map, relief: relief)
        var frame = SceneFrame()
        let batches = stage.fieldDead([melee()], watch: 5, time: 1, birds: false, into: &frame)
        let theirs = try XCTUnwrap(batches.first { $0.key == spears }).instances
        let ours = try XCTUnwrap(batches.first { $0.key == bows }).instances
        XCTAssertEqual(theirs.count, 5)
        XCTAssertEqual(ours.count, 2)
        XCTAssertTrue(theirs.allSatisfy { $0.colour == red } && ours.allSatisfy { $0.colour == blue }, "each in his House's colour")
        // Lying as the death leaves him: one pose for all of a kind, the end of the clip.
        XCTAssertEqual(Set(theirs.map(\.palette)).count, 1)
        let palette = Int(theirs[0].palette)
        let end = Float(WorldStage.frame(of: .death, at: Clip.death.period)) / 30
        let lying = Library.model(spears).pose(.death, at: end)
        XCTAssertEqual(end, Clip.death.period, accuracy: 1 / 60)
        XCTAssertEqual(Array(frame.palette[palette..<(palette + lying.count)]), lying, "the death played to its end")
        // On the ground, at his size in the field, kept by the hex he lies in.
        for man in theirs {
            let at = man.model.transformPoint(.zero)
            XCTAssertEqual(at.y, max(relief.height(atX: at.x, z: at.z), Relief.waterline), accuracy: 0.02)
            XCTAssertEqual(man.hex, SIMD2(3, -6))
        }
        XCTAssertTrue(ours.allSatisfy { $0.hex == SIMD2(2, -6) }, "the striker's on the striker's hex")
        // Fewer each watch, then none.
        let counts = (5...8).map { now -> Int in
            var frame = SceneFrame()
            return stage.fieldDead([melee()], watch: now, time: 1, birds: false, into: &frame)
                .filter { $0.key == spears || $0.key == bows }.map(\.instances.count).reduce(0, +)
        }
        XCTAssertEqual(counts, [7, 6, 3, 0], "five and two, four and two, two and one, then none")
        XCTAssertTrue(batches.allSatisfy { $0.key != .prop(.arrow) }, "no arrows where the fronts met")
    }

    func testArrowsStandInTheGroundAboutThoseAVolleyFelled() throws {
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        var frame = SceneFrame()
        let batches = stage.fieldDead([volley()], watch: 5, time: 1, birds: false, into: &frame)
        let dead = try XCTUnwrap(batches.first { $0.key == spears }).instances
        let arrows = try XCTUnwrap(batches.first { $0.key == .prop(.arrow) }).instances
        XCTAssertEqual(dead.count, 3)
        XCTAssertEqual(arrows.count, dead.count * WorldStage.arrowsPerDead)
        let men = dead.map { $0.model.transformPoint(.zero) }
        let bows = centre(volley().from)
        for arrow in arrows {
            let at = arrow.model.transformPoint(.zero)
            XCTAssertLessThanOrEqual(men.map { flat($0, at) }.min() ?? 9, 0.16, "about a man it felled")
            let nose = arrow.model.transformDirection(Vec3(0, 0, 1))
            let length = (nose.x * nose.x + nose.y * nose.y + nose.z * nose.z).squareRoot()
            XCTAssertLessThan(nose.y / length, -0.75, "standing nose down in the ground")
            // Its feathers toward the bows: its nose points away from them.
            let away = Vec3(at.x - bows.x, 0, at.z - bows.z)
            XCTAssertGreaterThan(nose.x * away.x + nose.z * away.z, 0)
        }
    }

    func testBirdsWheelLowOverAFieldFoughtLately() throws {
        let relief = Relief(map: state.map)
        let stage = WorldStage(map: state.map, relief: relief)
        func birds(_ watch: Int, time: Float, wheeling: Bool = true) -> [ModelInstance] {
            var frame = SceneFrame()
            return stage.fieldDead([melee(), melee(seed: 9)], watch: watch, time: time, birds: wheeling, into: &frame)
                .first { $0.key == .prop(.bird) }?.instances ?? []
        }
        let now = birds(5, time: 1)
        XCTAssertEqual(now.count, 3, "a few birds, once for a field however many blows were struck on it")
        XCTAssertEqual(birds(6, time: 1).count, 3, "still the next watch")
        XCTAssertTrue(birds(7, time: 1).isEmpty, "gone the watch after")
        XCTAssertTrue(birds(5, time: 1, wheeling: false).isEmpty, "none where the world is still")
        let middle = (centre(Hex(3, -6)) + centre(Hex(2, -6))) * 0.5
        let ground = max(relief.height(atX: middle.x, z: middle.z), Relief.waterline)
        for bird in now {
            let at = bird.model.transformPoint(.zero)
            XCTAssertLessThanOrEqual(flat(at, middle), 0.5, "over the field")
            XCTAssertGreaterThan(at.y - ground, WorldStage.birdsOver - 0.1, "low, above the dead")
            XCTAssertLessThan(at.y - ground, WorldStage.birdsOver + 0.4)
        }
        let later = birds(5, time: 2)
        XCTAssertGreaterThan(flat(now[0].model.transformPoint(.zero), later[0].model.transformPoint(.zero)), 0.05, "wheeling")
    }

    func testTheNewestDeadAreDrawnFirstUpToTheMost() throws {
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        func men(_ blows: [FieldBlow]) -> [Vec3] {
            var frame = SceneFrame()
            return stage.fieldDead(blows, watch: 5, time: 1, birds: false, into: &frame)
                .filter { $0.key == spears || $0.key == bows }.flatMap(\.instances).map { $0.model.transformPoint(.zero) }
        }
        // Thirty blows this watch (seven men each) and thirty the last (six).
        let blows = (0..<60).map { melee(watch: 4 + $0 % 2, seed: $0) }
        let drawn = men(blows)
        XCTAssertEqual(drawn.count, WorldStage.deadDrawnMost, "no more than the most a frame draws")
        let fresh = men(blows.filter { $0.watch == 5 })
        XCTAssertEqual(fresh.count, 30 * 7)
        func spot(_ point: Vec3) -> SIMD2<Int32> { SIMD2(Int32((point.x * 1_000).rounded()), Int32((point.z * 1_000).rounded())) }
        XCTAssertTrue(Set(fresh.map(spot)).isSubset(of: Set(drawn.map(spot))), "this watch's dead all drawn before the last's")
        var frame = SceneFrame()
        XCTAssertTrue(stage.fieldDead([], watch: 5, time: 1, into: &frame).isEmpty)
    }

    func testABarrowIsRaisedBesideTheFieldsHeartWithItsStone() throws {
        let relief = Relief(map: state.map)
        let stage = WorldStage(map: state.map, relief: relief)
        let small = stage.graves([(at: Hex(3, -6), troops: 800)])
        let great = stage.graves([(at: Hex(3, -6), troops: 30_000)])
        let mound = try XCTUnwrap(small.first { $0.key == .furnishing(.barrowMound) }).instances
        let stone = try XCTUnwrap(small.first { $0.key == .furnishing(.standingStone) }).instances
        XCTAssertEqual(mound.count, 1)
        XCTAssertEqual(stone.count, 1)
        let heart = centre(Hex(3, -6))
        let at = mound[0].model.transformPoint(.zero), head = stone[0].model.transformPoint(.zero)
        XCTAssertEqual(flat(at, heart), WorldStage.graveOffset, accuracy: 1e-3, "beside the heart, off the ground a company stands on")
        XCTAssertEqual(at.y, max(relief.height(atX: at.x, z: at.z), Relief.waterline), accuracy: 0.02, "on the ground")
        XCTAssertEqual(head.y, max(relief.height(atX: head.x, z: head.z), Relief.waterline), accuracy: 0.02)
        XCTAssertGreaterThan(flat(head, at), 0.1, "its stone at its head")
        XCTAssertEqual(mound[0].hex, SIMD2(3, -6))
        // The more laid in it, the larger, to a bound.
        let side = { (batches: [ModelBatch]) -> Float in
            let model = try! XCTUnwrap(batches.first { $0.key == .furnishing(.barrowMound) }).instances[0].model
            let axis = model.transformDirection(Vec3(1, 0, 0))
            return (axis.x * axis.x + axis.y * axis.y + axis.z * axis.z).squareRoot()
        }
        XCTAssertGreaterThan(side(great), side(small))
        XCTAssertEqual(WorldStage.graveScale(troops: 30_000), WorldStage.graveScale(troops: 12_000))
        XCTAssertEqual(WorldStage.graveScale(troops: -5), WorldStage.graveScale(troops: 0))
        XCTAssertTrue(stage.graves([]).isEmpty)
    }

    /// A barrow the keeper sees raised is heaped up from the ground over a
    /// few seconds, its stone set up at its head over the last half, while
    /// the lights of its dead still rise; once raised it stands as every
    /// barrow does, and where motion is reduced it stands whole at once.
    func testABarrowBeingRaisedIsHeapedUpFromTheGround() throws {
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        let field = Hex(3, -6)
        func parts(_ done: Float?) -> (mound: [ModelInstance], stone: [ModelInstance]) {
            let batches = stage.graves([(at: field, troops: 6_000)], raising: done.map { [field: $0] } ?? [:])
            return (batches.first { $0.key == .furnishing(.barrowMound) }?.instances ?? [],
                    batches.first { $0.key == .furnishing(.standingStone) }?.instances ?? [])
        }
        let mound = Library.model(.furnishing(.barrowMound)).mesh.bounds
        let stone = Library.model(.furnishing(.standingStone)).mesh.bounds
        let begun = parts(0.1), half = parts(0.5), late = parts(0.8), done = parts(1), standing = parts(nil)
        XCTAssertEqual(begun.mound.count, 1)
        XCTAssertGreaterThan(begun.mound[0].params.x, mound.min.y, "heaped from the ground")
        XCTAssertLessThan(begun.mound[0].params.x, half.mound[0].params.x, "higher as it goes")
        XCTAssertLessThan(half.mound[0].params.x, mound.max.y, "not yet whole")
        XCTAssertTrue(begun.stone.isEmpty && half.stone.isEmpty, "its stone not yet set up")
        XCTAssertEqual(late.stone.count, 1, "its stone going up as it ends")
        XCTAssertLessThan(late.stone[0].params.x, stone.max.y)
        XCTAssertEqual(done.mound, standing.mound, "raised, it stands as every barrow does")
        XCTAssertEqual(done.stone, standing.stone)
        let at = stage.gravePlace(field), foot = begun.mound[0].model.transformPoint(.zero)
        XCTAssertLessThan(flat(at, foot) + abs(at.y - foot.y), 1e-4, "where it stands")
        // Its pace: slow to start and slow to end, whole after, and whole at
        // once where motion is reduced; heaped while its dead's lights rise.
        XCTAssertEqual(WorldStage.graveRaised(age: 0), 0)
        XCTAssertEqual(WorldStage.graveRaised(age: WorldStage.graveRaisingSeconds / 2), 0.5, accuracy: 1e-4)
        XCTAssertEqual(WorldStage.graveRaised(age: WorldStage.graveRaisingSeconds * 2), 1)
        XCTAssertEqual(WorldStage.graveRaised(age: 0, still: true), 1)
        XCTAssertLessThan(WorldStage.graveRaisingSeconds, WorldStage.releaseSeconds)
    }
}
