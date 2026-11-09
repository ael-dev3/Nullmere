import Foundation
import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

/// The blackwood burning as the world draws it: three fires to each tile
/// alight among its trees, on the ground, the nearest to the view first and
/// so many at most; flames licking up from them under embers, smoke and
/// firelight; and once burnt, its trees standing dead and its undergrowth
/// gone, until it grows back.
final class WildfireStageTests: XCTestCase {
    private static let state = GameState(settings: GameSettings(seedText: "stage", houseCount: 4, radius: 12, keepers: 1))
    private static let relief = Relief(map: state.map)

    private func stage() -> WorldStage {
        WorldStage(map: Self.state.map, relief: Self.relief)
    }

    private static func pieces(_ batches: [ModelBatch], in hex: Hex) -> [ModelKey: Int] {
        var counted: [ModelKey: Int] = [:]
        let at = SIMD2(Int32(hex.q), Int32(hex.r))
        for batch in batches {
            for instance in batch.instances where instance.hex == at { counted[batch.key, default: 0] += 1 }
        }
        return counted
    }

    func testBurntWoodStandsDeadWithItsUndergrowthGone() throws {
        let stage = stage()
        let map = Self.state.map
        let all = stage.furnish(occupied: [], holds: [])
        let wooded = try XCTUnwrap(map.hexes.first { hex in
            map[hex]?.terrain == .blackwood && hex.neighbors.allSatisfy { map[$0]?.terrain == .blackwood }
                && Self.pieces(all, in: hex)[.furnishing(.fir)] != nil
        }, "A wooded hex in the blackwood")
        let before = Self.pieces(all, in: wooded)
        let trees: [Furnishing] = [.fir, .birch, .elderTree, .deadTree]
        let standing = trees.reduce(0) { $0 + (before[.furnishing($1)] ?? 0) }
        XCTAssertGreaterThan(standing, 0)

        let burnt = stage.furnish(occupied: [], holds: [], burnt: [wooded])
        XCTAssertEqual(stage.furnitureVersion, 2, "laid out again, and sent again")
        let after = Self.pieces(burnt, in: wooded)
        XCTAssertEqual(after[.furnishing(.deadTree)], standing, "every tree stands dead where it stood")
        for key in after.keys { XCTAssertEqual(WorldStage.burnt(key), key, "\(key) is what the fire leaves") }
        for furnishing: Furnishing in [.fir, .birch, .elderTree, .grass, .fern, .heather, .reeds] {
            XCTAssertNil(after[.furnishing(furnishing)], "no \(furnishing) left")
        }
        for hex in wooded.neighbors { XCTAssertEqual(Self.pieces(burnt, in: hex), Self.pieces(all, in: hex), "nothing beside it touched") }
        XCTAssertEqual(stage.furnish(occupied: [], holds: [], burnt: [wooded]), burnt, "kept, not laid out again")
        XCTAssertEqual(stage.furnitureVersion, 2)
        XCTAssertEqual(stage.furnish(occupied: [], holds: []), all, "grown back, as it stood")
        // Stone, salt and the rest are as they were.
        XCTAssertEqual(WorldStage.burnt(.furnishing(.boulder)), .furnishing(.boulder))
        XCTAssertEqual(WorldStage.burnt(.furnishing(.standingStone)), .furnishing(.standingStone))
        XCTAssertEqual(WorldStage.burnt(.keep(seat: true)), .keep(seat: true))
    }

    func testTheBlackwoodBurnsAmongItsTreesNearestTheViewFirst() throws {
        let stage = stage()
        let map = Self.state.map
        let woods = map.hexes.filter { map[$0]?.terrain == .blackwood }
        XCTAssertGreaterThan(woods.count, WorldStage.mostWoodFires)
        let focus = Vec3(Relief.centre(of: woods[0]).x, 0, Relief.centre(of: woods[0]).z)
        let spots = stage.woodFires(woods, near: focus)
        XCTAssertEqual(spots, stage.woodFires(woods, near: focus), "drawn alike every frame")
        XCTAssertEqual(spots.count, 3 * WorldStage.mostWoodFires, "three to a tile, so many tiles at most")
        func far(_ hex: Hex) -> Float {
            let c = Relief.centre(of: hex)
            return (c.x - focus.x) * (c.x - focus.x) + (c.z - focus.z) * (c.z - focus.z)
        }
        let drawn = woods.sorted { (far($0), $0.q, $0.r) < (far($1), $1.q, $1.r) }.prefix(WorldStage.mostWoodFires)
        for (index, hex) in drawn.enumerated() {
            let centre = Relief.centre(of: hex)
            for spot in spots[(3 * index)..<(3 * index + 3)] {
                let reach = ((spot.at.x - centre.x) * (spot.at.x - centre.x) + (spot.at.z - centre.z) * (spot.at.z - centre.z)).squareRoot()
                XCTAssertLessThan(reach, 0.45, "among its own tile's trees")
                XCTAssertEqual(spot.at.y, stage.ground(atX: spot.at.x, z: spot.at.z), accuracy: 0.0001, "on the ground")
                XCTAssertTrue(spot.strength > 0.7 && spot.strength <= 1)
            }
        }
        XCTAssertEqual(Set(spots.map(\.seed)).count, spots.count, "each its own fire")
        XCTAssertEqual(stage.woodFires([], near: focus), [])
    }

    func testFlamesLickUpFromTheWoodUnderEmbersSmokeAndFirelight() {
        let origin = Vec3(1, 0.4, -2)
        // Flames rise from where they are thrown, narrowing as they climb, warm.
        let flames = Burst(.flames, at: origin, start: 0, count: 40, seed: 11)
        let early = Effects.motes(bursts: [flames], emitters: [], at: 0.05)
        let late = Effects.motes(bursts: [flames], emitters: [], at: 0.3)
        XCTAssertFalse(early.isEmpty)
        XCTAssertFalse(late.isEmpty)
        func height(_ motes: [Mote]) -> Float { motes.map(\.place.y).reduce(0, +) / Float(max(motes.count, 1)) }
        func size(_ motes: [Mote]) -> Float { motes.map(\.place.w).reduce(0, +) / Float(max(motes.count, 1)) }
        XCTAssertGreaterThan(height(late), height(early), "rising")
        XCTAssertLessThan(size(late), size(early), "narrowing")
        XCTAssertTrue((early + late).allSatisfy { $0.colour.w == 0 && $0.colour.x >= $0.colour.y && $0.colour.y >= $0.colour.z },
                      "warm light, hiding nothing")
        // A tile alight: flames, embers and smoke over it, and its firelight.
        var happenings = Happenings()
        happenings.woodFires = [Happenings.Spot(at: origin, strength: 1, seed: 5)]
        let (motes, lights) = happenings.effects(at: 3)
        XCTAssertTrue(motes.contains { $0.colour.w > 0 && $0.place.y > origin.y + 0.3 }, "smoke rolling up")
        XCTAssertTrue(motes.contains { $0.colour.w == 0 && $0.colour.x > 0.5 }, "fire")
        XCTAssertEqual(lights.count, 1)
        XCTAssertGreaterThan(lights[0].colour.x, lights[0].colour.z, "firelight")
        XCTAssertTrue(happenings.effects(at: 3, leaving: [.flames, .embers, .smoke]).motes.isEmpty, "all of it the fire's")
    }
}
