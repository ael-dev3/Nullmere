import Foundation
import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

/// The blackwood burning as the world draws it: three fires to each tile
/// alight among its trees, on the ground, the nearest to the view first and
/// so many at most; flames licking up from them under embers, smoke and
/// firelight; and once burnt, its trees standing dead and its undergrowth
/// gone, until it grows back; and from afar a warm glow over each tile
/// alight.
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

    func testTheBlackwoodBurningGlowsFromAfar() throws {
        let stage = stage()
        let map = Self.state.map
        let burning = Array(map.hexes.filter { map[$0]?.terrain == .blackwood }.prefix(5))
        XCTAssertEqual(burning.count, 5)
        let focus = Vec3(Relief.centre(of: burning[0]).x, 0, Relief.centre(of: burning[0]).z)
        // From afar, a warm glow high over each tile alight, light only.
        let far = stage.fireGlows(burning, near: focus, scale: Camera.minimumScale, time: 3)
        XCTAssertEqual(far.count, burning.count)
        for hex in burning {
            let centre = Relief.centre(of: hex)
            let glow = try XCTUnwrap(far.first { abs($0.place.x - centre.x) < 0.001 && abs($0.place.z - centre.z) < 0.001 }, "a glow over \(hex)")
            XCTAssertGreaterThan(glow.place.y, stage.ground(atX: centre.x, z: centre.z) + 0.3, "over its trees")
            XCTAssertEqual(glow.colour.w, 0, "light only, hiding nothing")
            XCTAssertTrue(glow.colour.x > glow.colour.y && glow.colour.y > glow.colour.z && glow.colour.z > 0, "the fire's own orange")
        }
        // Holding its size on the screen as the view draws away, and coming
        // in as the keeps' glows do: dimmer nearer, none where the fires
        // among the trees are seen.
        let nearer = stage.fireGlows(burning, near: focus, scale: 20, time: 3)
        XCTAssertEqual(nearer.map(\.place.x), far.map(\.place.x))
        XCTAssertEqual(far[0].place.w * Float(Camera.minimumScale), nearer[0].place.w * 20, accuracy: 0.001, "the same size on the screen")
        XCTAssertLessThan(nearer[0].colour.x, far[0].colour.x, "dimmer as the view comes nearer")
        XCTAssertTrue(stage.fireGlows(burning, near: focus, scale: WorldStage.glowFrom, time: 3).isEmpty)
        XCTAssertTrue(stage.fireGlows(burning, near: focus, scale: Camera.maximumScale, time: 3).isEmpty)
        // Flickering where it stands, never out.
        let later = stage.fireGlows(burning, near: focus, scale: Camera.minimumScale, time: 3.05)
        XCTAssertEqual(later.map(\.place), far.map(\.place))
        XCTAssertNotEqual(later.map(\.colour), far.map(\.colour), "flickering")
        for time in stride(from: Float(0), to: 2, by: 0.1) {
            XCTAssertTrue(stage.fireGlows(burning, near: focus, scale: Camera.minimumScale, time: time).allSatisfy { $0.colour.x > 0.12 })
        }
        // The nearest so many tiles to the view at most.
        let all = stage.fireGlows(map.hexes, near: focus, scale: Camera.minimumScale, time: 0)
        XCTAssertEqual(all.count, WorldStage.mostFireGlows)
        func away(_ hex: Hex) -> Float {
            let c = Relief.centre(of: hex)
            return (c.x - focus.x) * (c.x - focus.x) + (c.z - focus.z) * (c.z - focus.z)
        }
        let nearest = map.hexes.sorted { (away($0), $0.q, $0.r) < (away($1), $1.q, $1.r) }.prefix(WorldStage.mostFireGlows)
        XCTAssertEqual(all.map(\.place.x), nearest.map { Relief.centre(of: $0).x })
        XCTAssertEqual(all.map(\.place.z), nearest.map { Relief.centre(of: $0).z })
        XCTAssertTrue(stage.fireGlows([], near: focus, scale: Camera.minimumScale, time: 0).isEmpty)
    }

    func testTheBlackwoodBurningGlowsCloseByWhereMotionIsReduced() throws {
        let stage = stage()
        let map = Self.state.map
        let burning = Array(map.hexes.filter { map[$0]?.terrain == .blackwood }.prefix(5))
        let focus = Vec3(Relief.centre(of: burning[0]).x, 0, Relief.centre(of: burning[0]).z)
        // Where motion is reduced the fires among the trees aren't drawn, so
        // the glow stays at every distance: over each tile alight close by,
        // at least as wide as the wood, where it would otherwise be gone.
        for scale in [WorldStage.glowFrom, 60, Camera.maximumScale] {
            XCTAssertTrue(stage.fireGlows(burning, near: focus, scale: scale, time: 3).isEmpty, "the fires among the trees tell it at \(scale)")
            let close = stage.fireGlows(burning, near: focus, scale: scale, time: 3, still: true)
            XCTAssertEqual(close.count, burning.count, "at \(scale)")
            for hex in burning {
                let centre = Relief.centre(of: hex)
                let glow = try XCTUnwrap(close.first { abs($0.place.x - centre.x) < 0.001 && abs($0.place.z - centre.z) < 0.001 }, "a glow over \(hex)")
                XCTAssertGreaterThanOrEqual(glow.place.w, WorldStage.stillFireGlow, "as wide as the wood alight")
                XCTAssertEqual(glow.colour.w, 0, "light only, hiding nothing")
                XCTAssertTrue(glow.colour.x > glow.colour.y && glow.colour.y > glow.colour.z && glow.colour.z > 0, "the fire's own orange")
            }
        }
        // Steady, not flickering.
        let now = stage.fireGlows(burning, near: focus, scale: Camera.maximumScale, time: 3, still: true)
        for time in stride(from: Float(0), to: 2, by: 0.1) {
            XCTAssertEqual(stage.fireGlows(burning, near: focus, scale: Camera.maximumScale, time: time, still: true).map(\.colour), now.map(\.colour))
        }
        // From afar, as bright as the moving glow at its brightest, and the
        // same size on the screen.
        let far = stage.fireGlows(burning, near: focus, scale: Camera.minimumScale, time: 3)
        let farStill = stage.fireGlows(burning, near: focus, scale: Camera.minimumScale, time: 3, still: true)
        XCTAssertEqual(farStill.map(\.place), far.map(\.place))
        for (still, moving) in zip(farStill, far) { XCTAssertGreaterThanOrEqual(still.colour.x, moving.colour.x - 0.0001) }
        XCTAssertTrue(stage.fireGlows([], near: focus, scale: Camera.maximumScale, time: 0, still: true).isEmpty)
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
