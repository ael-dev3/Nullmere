import Foundation
@testable import NullmereCore
@testable import NullmereModels
import XCTest

/// The town about every hold: homes, lanes, a well, fields and a seat's
/// market, filling its land as its works rise, never in the way of a work,
/// a wall, a lane or a company, and the same each time.
final class TownTests: XCTestCase {
    private static let worlds = PlacementTests.worlds

    private func heart(_ hex: Hex) -> Vec3 {
        let centre = Relief.centre(of: hex)
        return Vec3(centre.x, 0, centre.z)
    }

    private func flat(_ a: Vec3, _ b: Vec3) -> Float {
        ((a.x - b.x) * (a.x - b.x) + (a.z - b.z) * (a.z - b.z)).squareRoot()
    }

    /// Every work a hold could raise at `level`, walls among them.
    private func grand(_ hex: Hex, seat: Bool, level: Int = 3, heritage: Heritage? = nil) -> HoldLayout.Plan {
        var levels: [HoldLayout.Work: Int] = [.building(.walls): level]
        for work in HoldLayout.Work.order where work != .building(.moonspire) || seat {
            levels[work] = level
        }
        return HoldLayout.Plan(hex: hex, isSeat: seat, levels: levels, heritage: heritage)
    }

    func testEachPieceIsSmallStandsOnTheGroundAndHomesAreLitWithTheirHousesDoor() {
        for piece in Town.allCases {
            let model = Library.model(.town(piece))
            let bounds = model.mesh.bounds
            XCTAssertGreaterThan(bounds.min.y, -0.07, "\(piece) is not sunk deep")
            XCTAssertLessThan(bounds.min.y, 0.001, "\(piece) stands on the ground")
            XCTAssertLessThan(bounds.max.y, 0.25, "\(piece) is low beside the works")
            let across = model.mesh.vertices.map { ($0.position.x * $0.position.x + $0.position.z * $0.position.z).squareRoot() }.max() ?? 0
            if piece == .lane {
                XCTAssertEqual(bounds.max.x - bounds.min.x, 1, accuracy: 1e-4, "A lane a unit long, stretched to its run")
                XCTAssertLessThanOrEqual(bounds.max.z - bounds.min.z, 2 * Town.lane.footprint + 1e-4)
            } else {
                XCTAssertLessThanOrEqual(across, piece.footprint + 0.03, "\(piece) keeps to its lot")
            }
            let materials = Set(model.mesh.vertices.map(\.material))
            if Town.homes.contains(piece) {
                XCTAssertTrue(materials.contains(.glow), "\(piece)'s window is lit")
                XCTAssertTrue(materials.contains(.house), "\(piece)'s door is its House's colour")
                // The door is on the side that faces the lane, +z.
                let door = model.mesh.vertices.filter { $0.material == .house }
                XCTAssertGreaterThan(door.map(\.position.z).min() ?? 0, 0.03, "\(piece)'s door faces +z")
            }
        }
        XCTAssertTrue(Set(Library.model(.town(.stall)).mesh.vertices.map(\.material)).contains(.house), "A stall's awning")
        XCTAssertTrue(Library.model(.town(.field)).mesh.vertices.contains { $0.material == .foliage && $0.sway > 0 }, "Grain in the wind")
    }

    func testNothingOfTheTownStandsInTheWay() throws {
        var lotsSeen = 0
        for state in TownTests.worlds {
            let relief = Relief(map: state.map)
            for hold in state.holds {
                for plan in [grand(hold.position, seat: hold.isSeat), HoldLayout.Plan(hex: hold.position, isSeat: hold.isSeat)] {
                    let heart = heart(plan.hex)
                    let land = HoldLayout.land(of: plan.hex, relief: relief)
                    let angles = HoldLayout.laneAngles(of: plan.hex)
                    let reserved = HoldLayout.reservedSlots(plan, relief: relief).slots
                    let neighbours = plan.hex.neighbors.map { self.heart($0) }
                    let keep = Library.model(.keep(seat: plan.isSeat)).mesh.bounds
                    let lots = HoldLayout.lots(plan, relief: relief)
                    lotsSeen += lots.count
                    for (index, lot) in lots.enumerated() {
                        let footprint = lot.piece.footprint, p = lot.position
                        let r = flat(p, heart)
                        XCTAssertLessThanOrEqual(r + footprint, HoldLayout.reach, "Within the hold's reach, where the land is bare")
                        XCTAssertGreaterThan(r - footprint, max(keep.max.x, keep.max.z), "Clear of the keep")
                        XCTAssertTrue(r + footprint <= HoldLayout.wardEdge || r - footprint >= HoldLayout.ringLane + HoldLayout.laneHalfWidth,
                                      "Off the walls' ground and the ring lane: \(lot.piece) at \(r)")
                        XCTAssertTrue(land.contains(HexLayout(size: 1).hex(atX: Double(p.x), y: Double(p.z))), "On the hold's land")
                        for slot in reserved {
                            XCTAssertGreaterThanOrEqual(flat(slot.position, p), footprint + HoldLayout.workRadius, "Never where a work could stand")
                        }
                        for angle in angles {
                            let way = Vec3(Float(cos(Double(angle))), 0, Float(sin(Double(angle))))
                            let offset = p - heart
                            let along = offset.dot(way)
                            guard along > 0 else { continue }
                            XCTAssertGreaterThanOrEqual((offset - way * along).length, footprint + HoldLayout.laneHalfWidth - 1e-4, "Off the lanes")
                        }
                        for neighbour in neighbours {
                            XCTAssertGreaterThanOrEqual(flat(neighbour, p), footprint + HoldLayout.heartClear - 1e-4, "Where companies stand")
                        }
                        for other in lots[(index + 1)...] {
                            XCTAssertGreaterThan(flat(other.position, p), footprint + other.piece.footprint, "Lots apart")
                        }
                        // Facing the lane nearest it.
                        let facing = Vec3(Float(sin(Double(lot.facing))), 0, Float(cos(Double(lot.facing))))
                        let nearest = angles.map { angle -> (Float, Vec3) in
                            let way = Vec3(Float(cos(Double(angle))), 0, Float(sin(Double(angle))))
                            let along = (p - heart).dot(way)
                            let toward = way * along - (p - heart)
                            return (along > 0 ? toward.length : .infinity, toward)
                        }.min { $0.0 < $1.0 }
                        if let toward = nearest?.1 {
                            XCTAssertGreaterThan(facing.dot(toward.normalized), 0.99, "\(lot.piece) faces its lane")
                        }
                    }
                }
            }
        }
        XCTAssertGreaterThan(lotsSeen, 200, "Towns stand about the holds")
    }

    func testTheTownGrowsWithItsWorksAndWhatStandsStays() {
        for state in TownTests.worlds {
            let relief = Relief(map: state.map)
            for hold in state.holds {
                let bare = HoldLayout.Plan(hex: hold.position, isSeat: hold.isSeat)
                let some = grand(hold.position, seat: hold.isSeat, level: 1)
                let more = grand(hold.position, seat: hold.isSeat, level: 3)
                let homes = { (plan: HoldLayout.Plan) in HoldLayout.lots(plan, relief: relief).filter { Town.homes.contains($0.piece) } }
                let few = homes(bare), several = homes(some), many = homes(more)
                XCTAssertLessThanOrEqual(few.count, HoldLayout.homes(bare))
                XCTAssertLessThanOrEqual(several.count, HoldLayout.homes(some))
                XCTAssertGreaterThanOrEqual(several.count, few.count)
                XCTAssertGreaterThanOrEqual(many.count, several.count)
                // The homes of a smaller town stand where they stood in the larger.
                for (small, large) in zip(few, many) {
                    XCTAssertEqual(small.piece, large.piece)
                    XCTAssertEqual(flat(small.position, large.position), 0, accuracy: 1e-5)
                }
                for (small, large) in zip(several, many) {
                    XCTAssertEqual(flat(small.position, large.position), 0, accuracy: 1e-5)
                }
            }
            // Where the land allows, a grand seat's town is a town.
            let seats = state.holds.filter(\.isSeat).map { homes in
                HoldLayout.lots(grand(homes.position, seat: true), relief: relief).filter { Town.homes.contains($0.piece) }.count
            }
            XCTAssertGreaterThanOrEqual(seats.max() ?? 0, 30, "A great seat has its streets of homes: \(seats)")
        }
        XCTAssertEqual(HoldLayout.homes(HoldLayout.Plan(hex: Hex(0, 0), isSeat: false)), 4)
        XCTAssertEqual(HoldLayout.homes(HoldLayout.Plan(hex: Hex(0, 0), isSeat: true)), 10)
        XCTAssertEqual(HoldLayout.homes(grand(Hex(0, 0), seat: false, level: 5)), 44)
        XCTAssertEqual(HoldLayout.homes(grand(Hex(0, 0), seat: true, level: 5)), 64)
    }

    func testAWellForEveryHoldAMarketAtTheSeatAndFieldsForTheGranary() throws {
        let state = TownTests.worlds[0]
        let relief = Relief(map: state.map)
        let seat = try XCTUnwrap(state.holds.first { $0.isSeat })
        let pieces = { (plan: HoldLayout.Plan, piece: Town) in HoldLayout.lots(plan, relief: relief).filter { $0.piece == piece } }
        let bare = HoldLayout.Plan(hex: seat.position, isSeat: true)
        XCTAssertEqual(pieces(bare, .well).count, 1)
        XCTAssertEqual(pieces(bare, .stall).count, HoldLayout.stalls)
        XCTAssertEqual(pieces(HoldLayout.Plan(hex: seat.position, isSeat: false), .stall).count, 0, "Only a seat keeps a market")
        XCTAssertEqual(pieces(bare, .field).count, 0, "No fields without a granary")
        var fields: [Vec3] = []
        for level in 1...5 {
            var plan = bare
            plan.levels[.building(.granary)] = level
            let worked = pieces(plan, .field)
            XCTAssertEqual(worked.count, min(level, HoldLayout.fieldsMost))
            // A field once worked stays where it was.
            for (old, new) in zip(fields, worked.map(\.position)) {
                XCTAssertEqual(flat(old, new), 0, accuracy: 1e-5)
            }
            fields = worked.map(\.position)
        }
        // Each lies out at the edge, near the granary.
        var withGranary = bare
        withGranary.levels[.building(.granary)] = 3
        let granary = try XCTUnwrap(HoldLayout.pieces(withGranary, relief: relief).first { $0.key == .work(.granary, level: 3) })
        for field in fields {
            XCTAssertGreaterThan(flat(field, heart(seat.position)), 1.8)
            XCTAssertLessThan(flat(field, granary.position), 2.4)
        }
    }

    func testLanesLeadThroughTheGateToEveryWorkAndRoundTheWallsLyingOnTheGround() throws {
        let state = TownTests.worlds[1]
        let relief = Relief(map: state.map)
        let seat = try XCTUnwrap(state.holds.first { $0.isSeat })
        let heart = heart(seat.position)
        let front = HoldLayout.frontAngle(of: seat.position)
        func lanes(_ plan: HoldLayout.Plan) -> [(from: Vec3, to: Vec3)] {
            HoldLayout.town(plan, relief: relief).filter { $0.key == .town(.lane) }.map {
                ($0.transform.transformPoint(Vec3(-0.5, 0, 0)), $0.transform.transformPoint(Vec3(0.5, 0, 0)))
            }
        }
        let bare = lanes(HoldLayout.Plan(hex: seat.position, isSeat: true))
        XCTAssertFalse(bare.isEmpty, "A way out through the gate, works or none")
        let gate = Vec3(Float(cos(Double(front))), 0, Float(sin(Double(front))))
        for lane in bare {
            for end in [lane.from, lane.to] {
                let offset = end - heart
                XCTAssertEqual(offset.x * gate.z - offset.z * gate.x, 0, accuracy: 1e-3, "Only the gate's way")
                XCTAssertGreaterThan(offset.x * gate.x + offset.z * gate.z, 0)
                XCTAssertEqual(end.y, relief.height(atX: end.x, z: end.z), accuracy: 1e-3, "Lying on the ground")
            }
            XCTAssertLessThanOrEqual(flat(lane.from, lane.to), HoldLayout.laneStep + 1e-4)
        }
        let farthest = bare.flatMap { [flat($0.from, heart), flat($0.to, heart)] }.max() ?? 0
        XCTAssertGreaterThan(farthest, HoldLayout.reach - 0.1, "Out to the hold's edge")
        // Walled, a ring of lane outside the walls; and one out to each work.
        let plan = grand(seat.position, seat: true)
        let laid = lanes(plan)
        let ring = laid.filter { abs(flat($0.from, heart) - HoldLayout.ringLane) < 1e-3 && abs(flat($0.to, heart) - HoldLayout.ringLane) < 1e-3 }
        XCTAssertGreaterThanOrEqual(ring.count, 24)
        for unwalled in [false, true] {
            var plan = plan
            if unwalled { plan.levels[.building(.walls)] = nil }
            let laid = lanes(plan)
            for piece in HoldLayout.pieces(plan, relief: relief) {
                guard case .work = piece.key else { continue }
                // The ring lane passes at the feet of the works beside the walls.
                let reaching = laid.contains { lane in
                    [lane.from, lane.to].contains { flat($0, piece.position) <= HoldLayout.workRadius + 0.06 }
                }
                XCTAssertTrue(reaching, "A lane to \(piece.key)\(unwalled ? ", unwalled" : "")")
            }
        }
        let unwalled = lanes(HoldLayout.Plan(hex: seat.position, isSeat: true, levels: [.building(.granary): 2]))
        XCTAssertFalse(unwalled.contains { abs(flat($0.from, heart) - HoldLayout.ringLane) < 1e-3 && abs(flat($0.to, heart) - HoldLayout.ringLane) < 1e-3 },
                       "No ring without walls")
    }

    func testTheSameHoldGivesTheSameTownAndEachPeopleBuildsItTheirWay() throws {
        let state = TownTests.worlds[2]
        let relief = Relief(map: state.map)
        let hold = try XCTUnwrap(state.holds.first)
        let plan = grand(hold.position, seat: hold.isSeat)
        XCTAssertEqual(HoldLayout.town(plan, relief: relief), HoldLayout.town(plan, relief: relief))
        XCTAssertEqual(HoldLayout.town(hold: hold, relief: relief), HoldLayout.town(HoldLayout.Plan(hold: hold), relief: relief))
        // Another hold, another town.
        let other = try XCTUnwrap(state.holds.dropFirst().first)
        let mine = HoldLayout.lots(plan, relief: relief).map { $0.position - heart(hold.position) }
        let theirs = HoldLayout.lots(grand(other.position, seat: other.isSeat), relief: relief).map { $0.position - heart(other.position) }
        XCTAssertNotEqual(mine.map { ($0 * 100).rounded(.toNearestOrEven) }, theirs.map { ($0 * 100).rounded(.toNearestOrEven) })
        // A people's own keep, wider or narrower, and their town still clear of it.
        for heritage in Heritage.allCases {
            let keep = Library.model(.keepOf(heritage, seat: hold.isSeat)).mesh.bounds
            for lot in HoldLayout.lots(grand(hold.position, seat: hold.isSeat, heritage: heritage), relief: relief) {
                XCTAssertGreaterThan(flat(lot.position, heart(hold.position)) - lot.piece.footprint, max(keep.max.x, keep.max.z, -keep.min.x, -keep.min.z))
            }
        }
    }
}
