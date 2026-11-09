import Foundation
@testable import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

/// A hold's townsfolk: one for each work standing whole, up to six, each
/// the folk of its work's kind, going out from the keep's door to the work
/// and back at a walk their feet hold the ground at, along the town's lanes
/// and never through a home, through the gate and round the walls where the
/// hold is walled; none about a hold whose ward is broken.
final class TownsfolkTests: XCTestCase {
    private let state = GameState(settings: GameSettings(seedText: "townsfolk", houseCount: 4, radius: 14, keepers: 1))

    private func seat(_ levels: [BuildingKind: Int]) throws -> Hold {
        var hold = try XCTUnwrap(state.holds.first { $0.isSeat })
        hold.levels = levels
        hold.ward = hold.maximumWard
        return hold
    }

    private func heart(of hold: Hold) -> Vec3 {
        let centre = Relief.centre(of: hold.position)
        return Vec3(centre.x, 0, centre.z)
    }

    /// Errands as their hold's plan lays them, before the hold is drawn
    /// `HoldLayout.grandeur` times larger about its middle.
    private func planned(_ errands: [WorldStage.Errand], of hold: Hold) -> [WorldStage.Errand] {
        let middle = heart(of: hold), k = HoldLayout.grandeur
        return errands.map { errand in
            var plan = errand
            plan.path = errand.path.map { Vec3(middle.x + ($0.x - middle.x) / k, $0.y, middle.z + ($0.z - middle.z) / k) }
            return plan
        }
    }

    private func flat(_ a: Vec3, _ b: Vec3) -> Float {
        let dx = b.x - a.x, dz = b.z - a.z
        return (dx * dx + dz * dz).squareRoot()
    }

    func testEachWholeWorkHasTheFolkOfItsKind() throws {
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        let hold = try seat([.granary: 2, .sawpit: 1, .quarry: 1, .saltworks: 1])
        let errands = planned(stage.errands(of: HoldSight(hold: hold, colour: Vec4(1, 0, 0, 1))), of: hold)
        XCTAssertEqual(errands.map(\.key).sorted { $0.description < $1.description },
                       [ModelKey.folk(of: .granary), .folk(of: .sawpit), .folk(of: .quarry), .folk(of: .saltworks)].sorted { $0.description < $1.description })
        XCTAssertEqual(ModelKey.folk(of: .infirmary), ModelKey.folk(of: .archive), "A porter about every other work")
        let heart = heart(of: hold)
        // Drawn as large as the companies' figures: the plan carried out
        // from the hold's middle, every work as much larger.
        let drawn = stage.errands(of: HoldSight(hold: hold, colour: Vec4(1, 0, 0, 1)))
        XCTAssertEqual(flat(drawn[0].path[0], heart), 0.42 * HoldLayout.grandeur, accuracy: 1e-3, "The door as far out as the hold is grand")
        XCTAssertEqual(HoldLayout.grandeur, WorldStage.figureScale, "Works and figures at one scale")
        var frame = SceneFrame()
        let laid = stage.pieces(of: hold, progress: nil)
        let keep = try XCTUnwrap(laid.first { if case .keep = $0.key { return true } else { return false } })
        let batches = stage.holds([HoldSight(hold: hold, colour: Vec4(1, 0, 0, 1))], time: 0, into: &frame).batches
        let drawnKeep = try XCTUnwrap(batches.first { $0.key == keep.key }?.instances.first)
        XCTAssertEqual(Vec3(drawnKeep.model.c0.x, drawnKeep.model.c0.y, drawnKeep.model.c0.z).length,
                       Vec3(keep.transform.c0.x, keep.transform.c0.y, keep.transform.c0.z).length * HoldLayout.grandeur, accuracy: 1e-4)
        for errand in errands {
            XCTAssertEqual(errand.path.count, 2, "Unwalled, straight there")
            XCTAssertEqual(flat(errand.path[0], heart), 0.42, accuracy: 1e-3, "From the keep's door")
            XCTAssertGreaterThan(errand.length, 0.3)
            XCTAssertLessThan(flat(errand.path[1], heart), HoldLayout.reach, "Within the hold's reach")
        }
        // A work rising has none yet; a work finished does.
        var rising = hold
        rising.project = Hold.Project(kind: .musterHall, targetLevel: 1, watchesLeft: 2)
        XCTAssertEqual(stage.errands(of: HoldSight(hold: rising, colour: Vec4(1, 0, 0, 1), progress: 0.5)).count, errands.count)
        // Six at most.
        let busy = try seat([.granary: 1, .sawpit: 1, .quarry: 1, .saltworks: 1, .beacon: 1, .musterHall: 1, .infirmary: 1, .forge: 1])
        XCTAssertEqual(planned(stage.errands(of: HoldSight(hold: busy, colour: Vec4(1, 0, 0, 1))), of: busy).count, WorldStage.townsfolkMost)
        // None about a bare keep.
        XCTAssertEqual(stage.errands(of: HoldSight(hold: try seat([:]), colour: Vec4(1, 0, 0, 1))), [])
    }

    func testAWalledHoldsFolkGoOutThroughItsGate() throws {
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        let hold = try seat([.walls: 2, .granary: 1, .quarry: 1])
        let gate = HoldLayout.gate(of: hold.position)
        let heart = heart(of: hold)
        XCTAssertEqual(flat(gate, heart), 0.84 * Float(cos(Double.pi / 6)), accuracy: 1e-3)
        let errands = planned(stage.errands(of: HoldSight(hold: hold, colour: Vec4(1, 0, 0, 1))), of: hold)
        XCTAssertEqual(errands.count, 2)
        for errand in errands {
            XCTAssertGreaterThanOrEqual(errand.path.count, 4)
            XCTAssertEqual(flat(errand.path[0], heart), HoldLayout.door, accuracy: 1e-3, "From the keep's door")
            XCTAssertEqual(flat(errand.path[1], gate), 0.12, accuracy: 1e-3, "Within the gate")
            XCTAssertEqual(flat(errand.path[2], gate), 0.12, accuracy: 1e-3, "and out of it")
            XCTAssertLessThan(flat(errand.path[1], heart), flat(errand.path[2], heart))
            // Round the ring lane outside the walls, a step at a time, then
            // out along the work's own lane.
            let ring = errand.path[3...].filter { abs(flat($0, heart) - HoldLayout.ringLane) < 1e-3 }
            XCTAssertGreaterThanOrEqual(ring.count, 1)
            for (a, b) in zip(ring, ring.dropFirst()) {
                XCTAssertLessThan(flat(a, b), 0.27)
            }
            XCTAssertGreaterThanOrEqual(flat(try XCTUnwrap(errand.path.last), heart), HoldLayout.ringLane - 1e-3)
        }
    }

    func testTheyKeepToTheLanesAndNeverWalkThroughAHome() throws {
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        let works: [BuildingKind: Int] = [.granary: 2, .sawpit: 2, .quarry: 1, .saltworks: 1, .infirmary: 1, .forge: 1]
        for levels in [works, works.merging([.walls: 3]) { $1 }] {
            let hold = try seat(levels)
            let homes = stage.pieces(of: hold, progress: nil).compactMap { piece -> (Vec3, Town)? in
                guard case .town(let town) = piece.key, town != .lane else { return nil }
                return (piece.position, town)
            }
            XCTAssertGreaterThan(homes.count, 10, "A town about the hold")
            let errands = planned(stage.errands(of: HoldSight(hold: hold, colour: Vec4(1, 0, 0, 1))), of: hold)
            XCTAssertEqual(errands.count, WorldStage.townsfolkMost)
            for errand in errands {
                for (a, b) in zip(errand.path, errand.path.dropFirst()) {
                    for step in 0...20 {
                        let p = a + (b - a) * (Float(step) / 20)
                        for (at, town) in homes {
                            XCTAssertGreaterThan(flat(p, at), town.footprint, "\(errand.key) walks round a \(town), not through it")
                        }
                    }
                }
            }
        }
    }

    func testTheyWalkOutStandAtTheirWorkAndComeBack() throws {
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        let hold = try seat([.walls: 1, .sawpit: 2, .saltworks: 1])
        for errand in planned(stage.errands(of: HoldSight(hold: hold, colour: Vec4(1, 0, 0, 1))), of: hold) {
            let speed = try XCTUnwrap(errand.key.marchSpeed)
            let round = 2 * errand.length / speed + 2 * WorldStage.townsfolkPause
            var clips: Set<Clip> = []
            var time: Float = 0
            while time < round + 1 {
                let now = WorldStage.walk(errand, at: time), next = WorldStage.walk(errand, at: time + 0.05)
                clips.insert(now.clip)
                if now.clip == .idle {
                    XCTAssertLessThan(flat(now.position, errand.path[0]), 1e-3, "Standing at the door")
                } else if now.clip == .gather {
                    XCTAssertLessThan(flat(now.position, errand.path.last!), 1e-3, "At work where it went")
                } else if next.clip == .march {
                    // At a walk the feet hold the ground; facing where it goes.
                    let step = flat(now.position, next.position)
                    XCTAssertLessThanOrEqual(step, speed * 0.05 + 1e-3)
                    // Along one leg, not round a corner of the way.
                    if step > speed * 0.05 * 0.9, abs(remainder(Double(next.heading - now.heading), 2 * .pi)) < 1e-4 {
                        let facing = Float(atan2(Double(next.position.x - now.position.x), Double(next.position.z - now.position.z)))
                        let off = abs(remainder(Double(facing - now.heading), 2 * .pi))
                        XCTAssertLessThan(off, 0.01, "\(errand.key) at \(time)")
                    }
                }
                time += 0.05
            }
            XCTAssertEqual(clips, [.march, .idle, .gather])
            XCTAssertEqual(flat(WorldStage.walk(errand, at: 3).position, WorldStage.walk(errand, at: 3 + round).position), 0, accuracy: 1e-4,
                           "Round and round")
        }
        let none = WorldStage.Errand(key: .folk(of: .granary), path: [Vec3(1, 0, 1)], salt: 1)
        XCTAssertEqual(WorldStage.walk(none, at: 2).clip, .idle)
    }

    /// The town's folk out and about its lanes: drawn only as the view
    /// comes close, householders, water-carriers, elders and children,
    /// there and back at the pace their feet hold the ground at; laid out
    /// again as the town grows, not as a work rises; and they too keep
    /// within a burning hold.
    func testTheTownsFolkWalkOutAsTheViewComesClose() throws {
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        let hold = try seat([.walls: 2, .granary: 3, .sawpit: 2, .quarry: 2, .saltworks: 1, .infirmary: 1, .forge: 1, .beacon: 1])
        let sight = HoldSight(hold: hold, colour: Vec4(0.2, 0.4, 0.8, 1))
        let strolls = planned(stage.strolls(of: sight), of: hold)
        XCTAssertGreaterThanOrEqual(strolls.count, 8, "A grown seat's lanes are busy")
        XCTAssertLessThanOrEqual(strolls.count, HoldLayout.seatStrollsMost)
        let homes: Set<ModelKey> = [.folk(ofHome: 0), .folk(ofHome: 0.5), .folk(ofHome: 0.7), .folk(ofHome: 0.9)]
        XCTAssertEqual(homes.count, 4, "Four kinds of folk at home")
        XCTAssertTrue(Set(strolls.map(\.key)).isSubset(of: homes))
        XCTAssertTrue(Set(strolls.map(\.key)).isDisjoint(with: [.folk(of: .granary), .folk(of: .sawpit), .folk(of: .quarry), .folk(of: .saltworks),
                                                                .folk(of: .forge)]), "None of the works' folk")
        let heart = heart(of: hold)
        for errand in strolls {
            XCTAssertLessThanOrEqual(flat(errand.path[0], heart), HoldLayout.ringLane + HoldLayout.keepSide + 1e-3, "From about the keep")
            let speed = try XCTUnwrap(errand.key.marchSpeed)
            var time: Float = 0
            while time < 2 * errand.length / speed + 2 * WorldStage.townsfolkPause {
                let now = WorldStage.walk(errand, at: time), next = WorldStage.walk(errand, at: time + 0.05)
                if now.clip == .idle {
                    XCTAssertLessThan(flat(now.position, errand.path[0]), 1e-3, "At the door")
                } else if now.clip == .gather {
                    XCTAssertLessThan(flat(now.position, errand.path.last!), 1e-3, "Where it went")
                } else if next.clip == .march {
                    XCTAssertLessThanOrEqual(flat(now.position, next.position), speed * 0.05 + 1e-3, "At a walk")
                }
                time += 0.25
            }
        }
        // The same when asked again, and as a work rises.
        XCTAssertEqual(planned(stage.strolls(of: sight), of: hold), strolls)
        var rising = hold
        rising.project = Hold.Project(kind: .musterHall, targetLevel: 1, watchesLeft: 2)
        let first = planned(stage.strolls(of: HoldSight(hold: rising, colour: sight.colour, progress: 0.2)), of: rising)
        XCTAssertEqual(planned(stage.strolls(of: HoldSight(hold: rising, colour: sight.colour, progress: 0.7)), of: rising), first, "Not laid anew as it rises")
        // A town that grows has more of its folk about, a bare keep's few.
        let bare = stage.strolls(of: HoldSight(hold: try seat([:]), colour: sight.colour))
        XCTAssertLessThan(bare.count, strolls.count)

        // Only as the view comes close.
        var frame = SceneFrame()
        let works = stage.errands(of: sight).count + stage.porters(of: sight).count
        func folk(_ batches: [ModelBatch]) -> Int { batches.reduce(0) { $0 + $1.instances.count } }
        XCTAssertEqual(folk(stage.townsfolk([sight], time: 12, into: &frame)), works, "From afar, the works' folk and porters alone")
        let close = stage.townsfolk([sight], time: 12, crowds: true, into: &frame)
        let gathered = stage.gatherings(of: sight)
        XCTAssertEqual(folk(close), works + strolls.count + gathered.count)
        for instance in close.flatMap(\.instances) {
            let at = Vec3(instance.model.c3.x, instance.model.c3.y, instance.model.c3.z)
            XCTAssertEqual(at.y, stage.ground(atX: at.x, z: at.z), accuracy: 1e-4, "On the ground")
            XCTAssertEqual(instance.colour, sight.colour, "In their House's colour")
        }
        var burning = hold
        burning.ward = burning.maximumWard / 2 - 1
        XCTAssertTrue(stage.townsfolk([HoldSight(hold: burning, colour: sight.colour)], time: 12, crowds: true, into: &frame).isEmpty,
                      "They keep within")
    }

    /// The town's folk gathered at the well and the stalls: drawn only as
    /// the view comes close, each standing where the hold is drawn, on the
    /// ground, facing what they gathered at and posed at their own moment of
    /// what they do there (drawing water, talking, resting, at play); laid
    /// out once for the town, and keeping within a burning hold.
    func testTheTownsFolkGatherAtTheWellAndTheStalls() throws {
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        let hold = try seat([.walls: 2, .granary: 3, .sawpit: 2, .quarry: 2, .saltworks: 1, .infirmary: 1, .forge: 1, .beacon: 1])
        let sight = HoldSight(hold: hold, colour: Vec4(0.6, 0.2, 0.2, 1))
        let gathered = stage.gatherings(of: sight)
        let plan = HoldLayout.Plan(hold: hold)
        let laid = HoldLayout.gatherings(plan, relief: Relief(map: state.map))
        XCTAssertEqual(gathered.count, laid.count)
        XCTAssertGreaterThanOrEqual(gathered.count, 6, "A grown seat's well and stalls are thronged")
        XCTAssertGreaterThanOrEqual(gathered.filter { $0.key == .folk(ofHome: 0.5) }.count, 2, "Two water-carriers at the well")
        let middle = heart(of: hold)
        for (drawn, planned) in zip(gathered, laid) {
            XCTAssertEqual(drawn.key, planned.key)
            XCTAssertEqual(drawn.facing, planned.facing)
            XCTAssertEqual(flat(drawn.position, middle), flat(planned.position, middle) * HoldLayout.grandeur, accuracy: 1e-4,
                           "Where the hold is drawn, its grandeur about its middle")
        }
        XCTAssertEqual(stage.gatherings(of: sight), gathered, "Laid out once for the town")

        var frame = SceneFrame()
        func folk(_ batches: [ModelBatch]) -> [(ModelKey, ModelInstance)] { batches.flatMap { batch in batch.instances.map { (batch.key, $0) } } }
        let far = folk(stage.townsfolk([sight], time: 12, into: &frame))
        let close = folk(stage.townsfolk([sight], time: 12, crowds: true, into: &frame))
        for one in gathered {
            let standing = close.filter { key, instance in
                key == one.key && flat(Vec3(instance.model.c3.x, 0, instance.model.c3.z), one.position) < 1e-4
            }
            XCTAssertEqual(standing.count, 1, "\(one.key) gathered where it stands, close")
            XCTAssertFalse(far.contains { $0.0 == one.key && flat(Vec3($0.1.model.c3.x, 0, $0.1.model.c3.z), one.position) < 1e-4 },
                           "None from afar")
            guard let (_, instance) = standing.first else { continue }
            XCTAssertEqual(instance.model.c3.y, stage.ground(atX: one.position.x, z: one.position.z), accuracy: 1e-4, "On the ground")
            XCTAssertEqual(instance.colour, sight.colour)
            // Turned by its facing about the up axis: its front, +z, toward its facing.
            let front = Vec3(instance.model.c2.x, 0, instance.model.c2.z)
            XCTAssertLessThan(abs(remainder(atan2(Double(front.x), Double(front.z)) - Double(one.facing), 2 * .pi)), 1e-3, "Facing what they gathered at")
        }
        // Posed as they work at what they gathered for, each at its own moment.
        let poses = Set(close.filter { key, instance in
            gathered.contains { $0.key == key && flat(Vec3(instance.model.c3.x, 0, instance.model.c3.z), $0.position) < 1e-4 }
        }.map(\.1.palette))
        XCTAssertGreaterThan(poses.count, 2, "Not all at one moment")
        var burning = hold
        burning.ward = burning.maximumWard / 2 - 1
        XCTAssertTrue(stage.townsfolk([HoldSight(hold: burning, colour: sight.colour)], time: 12, crowds: true, into: &frame).isEmpty,
                      "They keep within")
    }

    func testCartsGoBetweenAHousesHoldsOnTheirWay() throws {
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        let hexes = [Hex(2, -6), Hex(3, -6), Hex(4, -6), Hex(5, -6)]
        let way = WorldStage.Way(hexes: hexes, colour: Vec4(0, 1, 0, 1), salt: 4)
        let errand = try XCTUnwrap(WorldStage.errand(along: way))
        XCTAssertEqual(errand.key, .folk(of: .sawpit), "Timber one way, stone the next")
        XCTAssertEqual(WorldStage.errand(along: WorldStage.Way(hexes: hexes, colour: .zero, salt: 5))?.key, .folk(of: .quarry))
        XCTAssertNil(WorldStage.errand(along: WorldStage.Way(hexes: Array(hexes.prefix(2)), colour: .zero, salt: 1)), "None for holds side by side")
        // From beyond one hold's walls to beyond the other's, through the hearts between.
        func centre(_ hex: Hex) -> Vec3 {
            let c = Relief.centre(of: hex)
            return Vec3(c.x, 0, c.z)
        }
        XCTAssertEqual(flat(errand.path[0], centre(hexes[0])), WorldStage.wayFromHold, accuracy: 1e-3)
        XCTAssertEqual(flat(errand.path.last!, centre(hexes.last!)), WorldStage.wayFromHold, accuracy: 1e-3)
        XCTAssertEqual(errand.path[1], centre(hexes[1]))
        // Drawn in the hex it is in, for what the keeper sees of it, in its House's colour.
        var frame = SceneFrame()
        let batches = stage.traffic([way, WorldStage.Way(hexes: [Hex(0, 0)], colour: .zero, salt: 2)], time: 30, into: &frame)
        let carts = batches.flatMap(\.instances)
        XCTAssertEqual(carts.count, 1)
        let cart = try XCTUnwrap(carts.first)
        let at = HexLayout(size: 1).hex(atX: Double(cart.model.c3.x), y: Double(cart.model.c3.z))
        XCTAssertEqual(cart.hex, SIMD2(Int32(at.q), Int32(at.r)))
        XCTAssertEqual(cart.colour, Vec4(0, 1, 0, 1))
        XCTAssertTrue(hexes.contains(at))
    }

    func testTheyAreStagedPosedAndKeepWithinABurningHold() throws {
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        let hold = try seat([.granary: 1, .sawpit: 1, .quarry: 1])
        var frame = SceneFrame()
        let batches = stage.townsfolk([HoldSight(hold: hold, colour: Vec4(0.2, 0.4, 0.8, 1))], time: 12, into: &frame)
        XCTAssertEqual(batches.reduce(0) { $0 + $1.instances.count }, 3)
        XCTAssertTrue(batches.allSatisfy { if case .folk = $0.key { return true } else { return false } })
        XCTAssertGreaterThan(frame.palette.count, 1, "Posed as they walk")
        let heart = heart(of: hold)
        for instance in batches.flatMap(\.instances) {
            let at = Vec3(instance.model.c3.x, instance.model.c3.y, instance.model.c3.z)
            XCTAssertLessThan(flat(at, heart), HoldLayout.reach)
            XCTAssertEqual(instance.colour, Vec4(0.2, 0.4, 0.8, 1), "In their House's colour")
        }
        var burning = hold
        burning.ward = burning.maximumWard / 2 - 1
        var dark = SceneFrame()
        XCTAssertTrue(stage.townsfolk([HoldSight(hold: burning, colour: Vec4(1, 0, 0, 1))], time: 12, into: &dark).isEmpty, "They keep within")
    }
}

extension TownsfolkTests {
    /// In a walled hold, porters walk the lane between its works, from the
    /// front of one to its neighbour's and back, round the lane a step at a
    /// time; an unwalled hold has none.
    func testPortersWalkBetweenTheWorks() throws {
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        let hold = try seat([.walls: 2, .granary: 1, .quarry: 1, .sawpit: 1, .forge: 1])
        let porters = stage.porters(of: HoldSight(hold: hold, colour: Vec4(1, 0, 0, 1)))
        XCTAssertEqual(porters.count, min(WorldStage.portersMost, 3))
        let works = stage.errands(of: HoldSight(hold: hold, colour: Vec4(1, 0, 0, 1))).compactMap(\.path.last)
        for porter in porters {
            XCTAssertEqual(porter.key, .folk(variant: Folk.porter))
            XCTAssertGreaterThan(porter.length, 0.2)
            let ends = [porter.path.first!, porter.path.last!]
            XCTAssertTrue(ends.allSatisfy { end in works.contains { flat($0, end) < 0.25 } }, "from one work's front to another's")
        }
        XCTAssertTrue(stage.porters(of: HoldSight(hold: try seat([.granary: 1, .quarry: 1]), colour: Vec4(1, 0, 0, 1))).isEmpty,
                      "none without walls to keep a lane")
    }

    /// Two meeting on a lane each step to their own side, the more the
    /// nearer, so they pass a lane's width apart where they would have met;
    /// the step comes and goes smoothly as they walk; one alone, or one
    /// standing at the end of their way, keeps to the line.
    func testTwoMeetingOnALaneStepAsideAndPass() {
        func step(_ gap: Float) -> (Vec3, Vec3) {
            let aside = WorldStage.stepsAside([WorldStage.Walker(at: Vec3(0, 0, -gap / 2), heading: 0, along: 1),
                                               WorldStage.Walker(at: Vec3(0, 0, gap / 2), heading: .pi, along: 1)], standing: [])
            return (aside[0], aside[1])
        }
        let (far, farOther) = step(WorldStage.passing + 0.01)
        XCTAssertEqual(far, .zero, "Not yet near")
        XCTAssertEqual(farOther, .zero)
        let (met, metOther) = step(0)
        XCTAssertEqual(met.x - metOther.x, 2 * WorldStage.stepAside, accuracy: 1e-4, "Where they would have met, a lane's width apart")
        XCTAssertLessThan(met.x * metOther.x, 0, "Each to their own side")
        XCTAssertEqual(met.y, 0)
        XCTAssertLessThan(WorldStage.stepAside, HoldLayout.laneHalfWidth * HoldLayout.grandeur, "Never past the lane's edge")
        // Smoothly, at a walk's pace a frame at sixty a second.
        let walk: Float = 0.15 / 60
        var gap = WorldStage.passing + 0.05, last = step(gap).0
        while gap > 0 {
            gap -= 2 * walk
            let now = step(max(gap, 0)).0
            XCTAssertLessThan(abs(now.x - last.x), WorldStage.stepAside * 0.08, "No jump at a gap of \(gap)")
            last = now
        }
        // Alone, or standing at the end of the way, on the line.
        XCTAssertEqual(WorldStage.stepsAside([WorldStage.Walker(at: .zero, heading: 1, along: 1)], standing: []), [.zero])
        let resting = WorldStage.stepsAside([WorldStage.Walker(at: .zero, heading: 0, along: 0),
                                             WorldStage.Walker(at: Vec3(0, 0, 0.05), heading: .pi, along: 1)], standing: [])
        XCTAssertEqual(resting[0], .zero, "Standing at the end of its way")
        XCTAssertNotEqual(resting[1], .zero, "The other steps round it")
    }

    /// One overtaking steps out and the one overtaken keeps on; one coming
    /// on folk standing at the well steps round them.
    func testOneOvertakingStepsOutAndFolkStandingAreWalkedRound() {
        let overtaking = WorldStage.stepsAside([WorldStage.Walker(at: Vec3(0, 0, 0), heading: 0, along: 1),
                                                WorldStage.Walker(at: Vec3(0, 0, 0.12), heading: 0, along: 1)], standing: [])
        XCTAssertGreaterThan(abs(overtaking[0].x), 0.01, "The one behind steps out")
        XCTAssertEqual(overtaking[1], .zero, "The one ahead keeps on")
        let round = WorldStage.stepsAside([WorldStage.Walker(at: .zero, heading: 0, along: 1)], standing: [Vec3(0, 0, 0.1)])
        XCTAssertGreaterThan(abs(round[0].x), 0.01)
        let behind = WorldStage.stepsAside([WorldStage.Walker(at: .zero, heading: 0, along: 1)], standing: [Vec3(0, 0, -0.2)])
        XCTAssertEqual(behind[0], .zero, "Nothing for those behind")
    }

    /// A busy seat's folk, crowds and all, through three minutes: two
    /// coming face to face on the lanes never pass through each other, as
    /// they did walking their lanes' lines, and the frame stages each as
    /// it steps.
    func testTheTownsFolkNeverWalkThroughEachOther() throws {
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        let hold = try seat([.walls: 2, .granary: 3, .sawpit: 2, .quarry: 2, .saltworks: 1, .infirmary: 1, .forge: 1, .beacon: 1])
        let sight = HoldSight(hold: hold, colour: Vec4(0.2, 0.4, 0.8, 1))
        let errands = stage.errands(of: sight) + stage.porters(of: sight) + stage.strolls(of: sight)
        let standing = stage.gatherings(of: sight).map(\.position)
        var throughBefore = 0, nearestAfter = Float.infinity
        var time: Float = 0
        while time < 180 {
            let walks = errands.map { WorldStage.walk($0, at: time) }
            let walkers = zip(errands, walks).map { WorldStage.Walker(at: $1.position, heading: $1.heading, along: WorldStage.along($0, at: $1.position)) }
            let aside = WorldStage.stepsAside(walkers, standing: standing)
            for a in walks.indices where walks[a].clip == .march && walkers[a].along > 0.99 {
                for b in walks.indices where b > a && walks[b].clip == .march && walkers[b].along > 0.99
                    && cos(walks[a].heading - walks[b].heading) < -0.95 {
                    guard flat(walks[a].position, walks[b].position) < 0.02 else { continue }
                    throughBefore += 1
                    nearestAfter = min(nearestAfter, flat(walks[a].position + aside[a], walks[b].position + aside[b]))
                }
            }
            time += 0.05
        }
        XCTAssertGreaterThan(throughBefore, 0, "On their lanes' lines, some met face to face")
        XCTAssertGreaterThan(nearestAfter, WorldStage.stepAside, "Stepping aside, none passes through another")

        // The frame stages them so.
        var frame = SceneFrame()
        let staged = stage.townsfolk([sight], time: 41, crowds: true, into: &frame).flatMap(\.instances)
        let walks = errands.map { WorldStage.walk($0, at: 41) }
        let aside = WorldStage.stepsAside(zip(errands, walks).map { WorldStage.Walker(at: $1.position, heading: $1.heading,
                                                                                    along: WorldStage.along($0, at: $1.position)) },
                                          standing: standing)
        for (walk, step) in zip(walks, aside) {
            let at = walk.position + step
            XCTAssertTrue(staged.contains { abs($0.model.c3.x - at.x) < 1e-4 && abs($0.model.c3.z - at.z) < 1e-4 }, "Staged where it steps")
        }
    }

    /// Through the night one in three of the town's folk with a hand free
    /// carries a lantern: a warm point of flame at their hand beside them,
    /// in a fainter, wider glow, light only, staged with them in the
    /// frame's motes; it swings with the step and its flame flickers, so it
    /// moves frame by frame. Carters, farmhands, salters and children carry
    /// none, and none walk with one about a burning hold.
    func testOneInThreeWithAHandFreeCarriesALantern() throws {
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        let hold = try seat([.walls: 2, .granary: 3, .sawpit: 2, .quarry: 2, .saltworks: 1, .infirmary: 1, .forge: 1, .beacon: 1])
        let sight = HoldSight(hold: hold, colour: Vec4(0.6, 0.2, 0.2, 1))
        func bearers(_ errands: [WorldStage.Errand]) -> Int {
            errands.filter { errand in
                guard case .folk(let variant) = errand.key else { return false }
                return Folk.carriesLantern(variant) && errand.salt % WorldStage.lanternEvery == 0
            }.count
        }
        XCTAssertEqual((0..<9).filter(Folk.carriesLantern), [4, 5, 6, 7], "Porters, householders, water-carriers and elders")
        let works = stage.errands(of: sight) + stage.porters(of: sight)
        let close = bearers(works + stage.strolls(of: sight))
        XCTAssertGreaterThanOrEqual(close, 3, "A grown seat's lanes have lanterns in them")

        var frame = SceneFrame()
        let walkers = stage.townsfolk([sight], time: 12, crowds: true, into: &frame).flatMap { batch in
            batch.instances.map { (key: batch.key, foot: Vec3($0.model.c3.x, $0.model.c3.y, $0.model.c3.z)) }
        }
        XCTAssertEqual(frame.motes.count, 2 * close, "A flame and its glow for each")
        for pair in stride(from: 0, to: frame.motes.count - 1, by: 2) {
            let flame = frame.motes[pair], glow = frame.motes[pair + 1]
            XCTAssertEqual(flame.colour.w, 0, "Light only")
            XCTAssertEqual(glow.colour.w, 0, "Light only")
            XCTAssertGreaterThan(flame.colour.x, 2 * flame.colour.z, "Warm")
            XCTAssertGreaterThan(glow.place.w, 3 * flame.place.w, "In a wider glow")
            XCTAssertLessThan(glow.colour.x, 0.2 * flame.colour.x, "A faint one")
            XCTAssertEqual(glow.place.x, flame.place.x)
            XCTAssertEqual(glow.place.z, flame.place.z)
            let at = Vec3(flame.place.x, flame.place.y, flame.place.z)
            // At the hand of one with a hand free, beside them.
            XCTAssertTrue(walkers.contains { walker in
                guard case .folk(let variant) = walker.key, Folk.carriesLantern(variant) else { return false }
                return flat(at, walker.foot) < 0.08 && abs(at.y - walker.foot.y - Folk.lanternHeight(variant)) < 1e-4
            }, "At a bearer's hand, beside them")
        }
        var later = SceneFrame()
        _ = stage.townsfolk([sight], time: 12.1, crowds: true, into: &later)
        XCTAssertEqual(later.motes.count, frame.motes.count)
        XCTAssertNotEqual(later.motes, frame.motes, "Swinging and flickering as they go")

        // From afar the works' folk and porters walk alone, with theirs.
        var far = SceneFrame()
        _ = stage.townsfolk([sight], time: 12, into: &far)
        XCTAssertEqual(far.motes.count, 2 * bearers(works))
        var burning = hold
        burning.ward = burning.maximumWard / 2 - 1
        var dark = SceneFrame()
        _ = stage.townsfolk([HoldSight(hold: burning, colour: sight.colour)], time: 12, crowds: true, into: &dark)
        XCTAssertTrue(dark.motes.isEmpty, "None walk out of a burning hold")
    }

    /// One of a hold's folk at its gate with a plea for its keeper: standing
    /// just beyond the gate as the hold is drawn, facing in toward the keep,
    /// in its House's colour, at a hold whose ward is broken as at any; none
    /// where no plea waits.
    func testThePetitionerStandsAtTheGate() throws {
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        var hold = try seat([.granary: 1])
        var frame = SceneFrame()
        let plain = HoldSight(hold: hold, colour: Vec4(0.8, 0.2, 0.2, 1))
        func folk(_ batches: [ModelBatch], _ key: ModelKey) -> [ModelInstance] { batches.filter { $0.key == key }.flatMap(\.instances) }
        let key = ModelKey.folk(variant: Petition.Plea.mend.folk)
        let without = folk(stage.townsfolk([plain], time: 3, into: &frame), key).count
        var pleading = plain
        pleading.petitioner = Petition.Plea.mend.folk
        let added = folk(stage.townsfolk([pleading], time: 3, into: &frame), key)
        XCTAssertEqual(added.count, without + 1)
        let (foot, heading) = stage.petitionerStand(at: hold.position)
        let petitioner = try XCTUnwrap(added.first { abs($0.model.c3.x - foot.x) < 1e-4 && abs($0.model.c3.z - foot.z) < 1e-4 })
        XCTAssertEqual(petitioner.model.c3.y, stage.ground(atX: foot.x, z: foot.z), accuracy: 1e-4, "On the ground")
        XCTAssertEqual(petitioner.colour, pleading.colour, "In their House's colour")
        let centre = Relief.centre(of: hold.position)
        let middle = Vec3(centre.x, 0, centre.z)
        let gate = WorldStage.grand(HoldLayout.gate(of: hold.position), about: centre)
        XCTAssertGreaterThan(flat(foot, middle), flat(gate, middle), "Beyond the gate as the hold is drawn")
        let facing = Vec3(Float(sin(Double(heading))), 0, Float(cos(Double(heading))))
        XCTAssertGreaterThan(facing.x * (middle.x - foot.x) + facing.z * (middle.z - foot.z), 0, "Facing the keep")
        // At a hold whose ward is broken, the plea's own case: the town keeps within, the petitioner stands.
        hold.ward = 0
        pleading.hold = hold
        XCTAssertEqual(stage.townsfolk([pleading], time: 3, into: &frame).flatMap(\.instances).count, 1)
        XCTAssertEqual(Petition.Plea.allCases.map(\.folk), [Folk.porter, Folk.elder, Folk.farmhand, Folk.waterCarrier])
    }

    /// The envoys waiting on a keeper's answer stand mounted at the seat's
    /// gate, each in the colour of the House that sent it, facing in, either
    /// side of the gate's way and clear of the petitioner on it; a few at
    /// most, and none where none waits.
    func testEnvoysWaitMountedAtTheSeatsGate() throws {
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        let hold = try seat([.granary: 1])
        var frame = SceneFrame()
        let plain = HoldSight(hold: hold, colour: Vec4(0.8, 0.2, 0.2, 1))
        func riders(_ batches: [ModelBatch]) -> [ModelInstance] { batches.filter { $0.key == WorldStage.envoyMount }.flatMap(\.instances) }
        XCTAssertTrue(riders(stage.townsfolk([plain], time: 3, into: &frame)).isEmpty, "None where none waits")
        let colours = (0..<6).map { Vec4(Float($0) / 6, 0.5, 0.3, 1) }
        var waiting = plain
        waiting.envoys = colours
        waiting.petitioner = Petition.Plea.mend.folk
        let mounted = riders(stage.townsfolk([waiting], time: 3, into: &frame))
        XCTAssertEqual(mounted.count, WorldStage.envoysAtGate, "A few at most")
        XCTAssertEqual(mounted.map(\.colour), Array(colours.prefix(WorldStage.envoysAtGate)), "Each in the colour of the House that sent it")
        let centre = Relief.centre(of: hold.position)
        let middle = Vec3(centre.x, 0, centre.z)
        let gate = WorldStage.grand(HoldLayout.gate(of: hold.position), about: centre)
        let (petitioner, _) = stage.petitionerStand(at: hold.position)
        var feet: [Vec3] = []
        for (index, rider) in mounted.enumerated() {
            let (foot, heading) = stage.envoyStand(at: hold.position, index: index)
            XCTAssertEqual(rider.model.c3.x, foot.x, accuracy: 1e-4)
            XCTAssertEqual(rider.model.c3.z, foot.z, accuracy: 1e-4)
            XCTAssertEqual(rider.model.c3.y, stage.ground(atX: foot.x, z: foot.z), accuracy: 1e-4, "On the ground")
            XCTAssertGreaterThan(flat(foot, middle), flat(gate, middle), "Beyond the gate as the hold is drawn")
            XCTAssertGreaterThan(flat(foot, petitioner), 0.1, "Clear of the petitioner")
            let facing = Vec3(Float(sin(Double(heading))), 0, Float(cos(Double(heading))))
            XCTAssertGreaterThan(facing.x * (middle.x - foot.x) + facing.z * (middle.z - foot.z), 0, "Facing the keep")
            XCTAssertTrue(feet.allSatisfy { flat($0, foot) > 0.1 }, "Each apart from the rest")
            feet.append(foot)
        }
    }
}
