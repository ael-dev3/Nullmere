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

    private func flat(_ a: Vec3, _ b: Vec3) -> Float {
        let dx = b.x - a.x, dz = b.z - a.z
        return (dx * dx + dz * dz).squareRoot()
    }

    func testEachWholeWorkHasTheFolkOfItsKind() throws {
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        let hold = try seat([.granary: 2, .sawpit: 1, .quarry: 1, .saltworks: 1])
        let errands = stage.errands(of: HoldSight(hold: hold, colour: Vec4(1, 0, 0, 1)))
        XCTAssertEqual(errands.map(\.key).sorted { $0.description < $1.description },
                       [ModelKey.folk(of: .granary), .folk(of: .sawpit), .folk(of: .quarry), .folk(of: .saltworks)].sorted { $0.description < $1.description })
        XCTAssertEqual(ModelKey.folk(of: .infirmary), ModelKey.folk(of: .archive), "A porter about every other work")
        let heart = heart(of: hold)
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
        XCTAssertEqual(stage.errands(of: HoldSight(hold: busy, colour: Vec4(1, 0, 0, 1))).count, WorldStage.townsfolkMost)
        // None about a bare keep.
        XCTAssertEqual(stage.errands(of: HoldSight(hold: try seat([:]), colour: Vec4(1, 0, 0, 1))), [])
    }

    func testAWalledHoldsFolkGoOutThroughItsGate() throws {
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        let hold = try seat([.walls: 2, .granary: 1, .quarry: 1])
        let gate = HoldLayout.gate(of: hold.position)
        let heart = heart(of: hold)
        XCTAssertEqual(flat(gate, heart), 0.84 * Float(cos(Double.pi / 6)), accuracy: 1e-3)
        let errands = stage.errands(of: HoldSight(hold: hold, colour: Vec4(1, 0, 0, 1)))
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
            let errands = stage.errands(of: HoldSight(hold: hold, colour: Vec4(1, 0, 0, 1)))
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
        for errand in stage.errands(of: HoldSight(hold: hold, colour: Vec4(1, 0, 0, 1))) {
            let speed = try XCTUnwrap(errand.key.marchSpeed)
            let round = 2 * errand.length / speed + 2 * WorldStage.townsfolkPause
            var clips: Set<Clip> = []
            var time: Float = 0
            while time < round + 1 {
                let now = WorldStage.walk(errand, at: time), next = WorldStage.walk(errand, at: time + 0.05)
                clips.insert(now.clip)
                if now.clip == .idle {
                    XCTAssertTrue(flat(now.position, errand.path[0]) < 1e-3 || flat(now.position, errand.path.last!) < 1e-3, "Standing at an end")
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
            XCTAssertEqual(clips, [.march, .idle])
            XCTAssertEqual(flat(WorldStage.walk(errand, at: 3).position, WorldStage.walk(errand, at: 3 + round).position), 0, accuracy: 1e-4,
                           "Round and round")
        }
        let none = WorldStage.Errand(key: .folk(of: .granary), path: [Vec3(1, 0, 1)], salt: 1)
        XCTAssertEqual(WorldStage.walk(none, at: 2).clip, .idle)
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
