import Foundation
import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

/// The hamlets and barrows a House has found, as the world draws them: a
/// hamlet's three homes facing their well, their doors in the free folk's
/// brown, its field beside them and its hearth smoking; a barrow's great
/// mound, the stones of its open mouth before it, a third laid across the
/// two; each within its own hex.
final class FindsStageTests: XCTestCase {
    private static let state = GameState(settings: GameSettings(seedText: "stage", houseCount: 4, radius: 12, keepers: 1))
    private static let relief = Relief(map: state.map)

    private func open(_ count: Int) throws -> [Hex] {
        let map = Self.state.map
        let found = map.hexes.filter { hex in
            map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && hex.distance(to: .origin) > 3
        }
        XCTAssertGreaterThanOrEqual(found.count, count)
        return Array(found.prefix(count))
    }

    private func position(_ instance: ModelInstance) -> Vec3 {
        Vec3(instance.model.c3.x, instance.model.c3.y, instance.model.c3.z)
    }

    func testAHamletsHomesFaceTheirWellAndItsHearthSmokes() throws {
        let stage = WorldStage(map: Self.state.map, relief: Self.relief)
        let hex = try open(1)[0]
        let (batches, hearths) = stage.finds([(kind: .hamlet, hex: hex)])
        let centre = Relief.centre(of: hex)
        var homes: [ModelInstance] = [], wells: [ModelInstance] = [], fields: [ModelInstance] = []
        for batch in batches {
            guard case .town(let piece) = batch.key else { return XCTFail("Only the town's pieces: \(batch.key)") }
            switch piece {
            case .well: wells += batch.instances
            case .field: fields += batch.instances
            default:
                XCTAssertTrue(Town.homes.contains(piece))
                XCTAssertNotEqual(piece, .townhouse, "No tall town homes out in the country")
                homes += batch.instances
            }
        }
        XCTAssertEqual(homes.count, 3)
        XCTAssertEqual(wells.count, 1)
        XCTAssertEqual(fields.count, 1)
        let well = position(wells[0])
        XCTAssertEqual(well.x, centre.x, accuracy: 0.001)
        XCTAssertEqual(well.z, centre.z, accuracy: 0.001)
        for home in homes {
            let at = position(home)
            XCTAssertEqual(hypot(at.x - centre.x, at.z - centre.z), WorldStage.hamletRing, accuracy: 0.001)
            // Facing the well: its +z turned toward the middle.
            let facing = Vec3(home.model.c2.x, 0, home.model.c2.z)
            let toWell = Vec3(centre.x - at.x, 0, centre.z - at.z)
            let cosine = (facing.x * toWell.x + facing.z * toWell.z) / (hypot(facing.x, facing.z) * hypot(toWell.x, toWell.z))
            XCTAssertGreaterThan(cosine, 0.99, "faces its well")
            XCTAssertEqual(home.colour, WorldStage.freeFolkDoor, "the free folk's own doors")
        }
        // Everything within its own hex.
        for instance in homes + wells + fields {
            let at = position(instance)
            XCTAssertLessThan(hypot(at.x - centre.x, at.z - centre.z), 0.8)
            XCTAssertEqual(HexLayout(size: 1).hex(atX: Double(at.x), y: Double(at.z)), hex)
        }
        XCTAssertEqual(hearths.count, 1)
        XCTAssertEqual(hearths[0].hex, hex)
        XCTAssertGreaterThan(hearths[0].point.y, well.y, "smoke from over the well's hearth")
    }

    func testABarrowsMouthStandsBeforeItsGreatMound() throws {
        let stage = WorldStage(map: Self.state.map, relief: Self.relief)
        let hex = try open(1)[0]
        let (batches, hearths) = stage.finds([(kind: .barrow, hex: hex)])
        XCTAssertTrue(hearths.isEmpty, "No hearth in the old graves")
        let mounds = batches.filter { $0.key == .furnishing(.barrowMound) }.flatMap(\.instances)
        let stones = batches.filter { $0.key == .furnishing(.standingStone) }.flatMap(\.instances)
        XCTAssertEqual(mounds.count, 1)
        XCTAssertEqual(stones.count, 3)
        // Larger than any the barrows' ground bears.
        let scale = hypot(mounds[0].model.c0.x, mounds[0].model.c0.z)
        XCTAssertEqual(scale, WorldStage.barrowMoundScale, accuracy: 0.001)
        XCTAssertGreaterThan(WorldStage.barrowMoundScale, 1.2)
        // Two stones standing upright either side of its mouth, a third laid
        // across them on their tops.
        let upright = stones.filter { $0.model.c1.y > 0.5 }, laid = stones.filter { abs($0.model.c1.y) < 0.1 }
        XCTAssertEqual(upright.count, 2)
        XCTAssertEqual(laid.count, 1)
        // Where each stone's model reaches as it stands in the world.
        let stone = Library.model(.furnishing(.standingStone)).mesh.bounds
        func reach(_ instance: ModelInstance) -> (min: Vec3, max: Vec3) {
            var low = Vec3(.infinity, .infinity, .infinity), high = Vec3(-.infinity, -.infinity, -.infinity)
            for x in [stone.min.x, stone.max.x] {
                for y in [stone.min.y, stone.max.y] {
                    for z in [stone.min.z, stone.max.z] {
                        let point = instance.model.transformPoint(Vec3(x, y, z))
                        low = Vec3(min(low.x, point.x), min(low.y, point.y), min(low.z, point.z))
                        high = Vec3(max(high.x, point.x), max(high.y, point.y), max(high.z, point.z))
                    }
                }
            }
            return (low, high)
        }
        let tops = upright.map { reach($0).max.y }
        let lintel = reach(laid[0])
        print("STAGE barrow: standing stones' tops at \(tops), the stone across from \(lintel.min.y) to \(lintel.max.y)")
        XCTAssertEqual(lintel.min.y, tops.max() ?? 0, accuracy: 0.01, "laid on the standing stones' tops, the higher where the ground slopes")
        XCTAssertGreaterThanOrEqual(lintel.min.y, (tops.min() ?? 0) - 0.001, "never sunk into the lower")
        // Across the mouth: its middle between the two, reaching over both.
        let between = (position(upright[0]) + position(upright[1])) * 0.5
        XCTAssertEqual((lintel.min.x + lintel.max.x) / 2, between.x, accuracy: 0.03)
        XCTAssertEqual((lintel.min.z + lintel.max.z) / 2, between.z, accuracy: 0.03)
        let span = hypot(lintel.max.x - lintel.min.x, lintel.max.z - lintel.min.z)
        let gap = hypot(position(upright[0]).x - position(upright[1]).x, position(upright[0]).z - position(upright[1]).z)
        XCTAssertEqual(gap, WorldStage.barrowMouthWidth, accuracy: 0.001)
        XCTAssertGreaterThan(span, gap, "reaching over both")
        // The mouth at the mound's foot, not buried in it.
        let mound = Library.model(.furnishing(.barrowMound)).mesh.bounds
        let foot = WorldStage.barrowMoundScale * max(mound.max.z, mound.max.x)
        XCTAssertEqual(WorldStage.barrowMouth, foot, accuracy: 0.12, "its mouth where the mound meets the ground")
        XCTAssertTrue(stage.finds([]).batches.isEmpty)
    }
}
