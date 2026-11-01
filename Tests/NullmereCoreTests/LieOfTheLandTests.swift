import Foundation
import XCTest
@testable import NullmereCore

/// The lie of the land: each tile's cheapest cost to a goal over the
/// ground alone. A far march's search in a wide lake, guided by it, finds
/// a way as cheap as the plain search's, looking over far fewer tiles; the
/// lie is kept with the map while its ground stays and let go of when it
/// changes; and a lake of twelve seats, or a near march, is never guided.
final class LieOfTheLandTests: XCTestCase {
    /// What a way costs: the steps of the ground it enters.
    private func cost(of way: [Hex], on map: WorldMap) -> Int {
        way.reduce(0) { $0 + Int(map.steps[map.index(of: $1)!]) }
    }

    private func land(of map: WorldMap) -> [Int] {
        map.hexes.indices.filter { map.steps[$0] != 0 }
    }

    /// Two tiles of land at the lake's far ends.
    private func farEnds(of map: WorldMap) throws -> (start: Int, goal: Int) {
        let land = land(of: map)
        return (try XCTUnwrap(land.min { map.hexes[$0].q < map.hexes[$1].q }), try XCTUnwrap(land.max { map.hexes[$0].q < map.hexes[$1].q }))
    }

    func testTheLieIsTheCheapestCostOverTheGround() throws {
        let map = Scene.world("the lie of the land", houses: 6, radius: 48).map
        let land = land(of: map)
        let goal = land[land.count / 2]
        let lie = LieOfTheLand.measure(toward: goal, on: map)
        XCTAssertEqual(lie[goal], 0)
        var search = WaySearch(count: map.count)
        let open = [Bool](repeating: false, count: map.count)
        for tile in stride(from: 0, to: land.count, by: land.count / 40).map({ land[$0] }) where tile != goal {
            if let way = search.way(on: map, from: tile, to: goal, around: open) {
                XCTAssertEqual(Int(lie[tile]), cost(of: way, on: map), "The cheapest from \(map.hexes[tile])")
            } else {
                XCTAssertEqual(lie[tile], LieOfTheLand.unreached)
            }
        }
        let water = try XCTUnwrap(map.hexes.indices.first { map.steps[$0] == 0 })
        XCTAssertEqual(lie[water], LieOfTheLand.unreached, "No way over the ground onto water")
    }

    func testAFarMarchIsGuidedToAWayAsCheapLookingOverFarFewerTiles() throws {
        let state = Scene.world("guided round the lake", houses: 6, radius: 48)
        let map = state.map
        let (start, goal) = try farEnds(of: map)
        XCTAssertGreaterThanOrEqual(map.hexes[start].distance(to: map.hexes[goal]), WorldMap.guidedFrom)
        let guide = try XCTUnwrap(map.guide(from: start, to: goal))
        // The companies of the lake stand in the way.
        var blocked = [Bool](repeating: false, count: map.count)
        for unit in state.units { if let index = map.index(of: unit.position) { blocked[index] = true } }
        blocked[start] = false
        var plain = WaySearch(count: map.count), guided = WaySearch(count: map.count)
        let theirs = try XCTUnwrap(plain.way(on: map, from: start, to: goal, around: blocked))
        let ours = try XCTUnwrap(guided.way(on: map, from: start, to: goal, around: blocked, guide: guide))
        XCTAssertEqual(ours.last, map.hexes[goal])
        XCTAssertTrue(zip([map.hexes[start]] + ours, ours).allSatisfy { $0.distance(to: $1) == 1 }, "Step by step")
        // Round the companies about its start; those farther along it meets
        // as it comes to them, and is never the dearer for them.
        XCTAssertFalse(ours.dropLast().contains { blocked[map.index(of: $0)!] && $0.distance(to: map.hexes[start]) <= WaySearch.seen },
                       "Round the companies about its start")
        XCTAssertLessThanOrEqual(cost(of: ours, on: map), cost(of: theirs, on: map))
        XCTAssertGreaterThanOrEqual(cost(of: ours, on: map), Int(guide[start]), "No cheaper than the ground gives")
        XCTAssertLessThan(guided.reached * 4, plain.reached, "Looking over far fewer tiles: \(guided.reached) against \(plain.reached)")
        // With none in the way at all, as cheap as the plain search's.
        let open = [Bool](repeating: false, count: map.count)
        let clear = try XCTUnwrap(guided.way(on: map, from: start, to: goal, around: open, guide: guide))
        XCTAssertEqual(cost(of: clear, on: map), cost(of: try XCTUnwrap(plain.way(on: map, from: start, to: goal, around: open)), on: map))
        XCTAssertEqual(cost(of: clear, on: map), Int(guide[start]))

        // A goal ringed round, or one no ground leads to, has no way.
        var ringed = blocked
        for side in 0..<6 {
            let next = Int(map.neighbours[goal * 6 + side])
            if next >= 0 { ringed[next] = true }
        }
        XCTAssertNil(guided.way(on: map, from: start, to: goal, around: ringed, guide: guide))
        var cut = map
        for side in 0..<6 {
            let next = Int(map.neighbours[goal * 6 + side])
            if next >= 0 { cut.set(index: next, Tile(terrain: .still)) }
        }
        XCTAssertNil(guided.way(on: cut, from: start, to: goal, around: blocked, guide: LieOfTheLand.measure(toward: goal, on: cut)))

        // From water beside the land, as a company on a ford as it closes
        // would stand, a way as cheap as the plain search's.
        let shore = try XCTUnwrap(map.hexes.indices.first { tile in
            map.steps[tile] == 0 && map.hexes[tile].distance(to: map.hexes[goal]) >= WorldMap.guidedFrom
                && (0..<6).contains { side in
                    let next = Int(map.neighbours[tile * 6 + side])
                    return next >= 0 && map.steps[next] != 0 && !blocked[next]
                }
        })
        let wading = try XCTUnwrap(guided.way(on: map, from: shore, to: goal, around: open, guide: guide))
        XCTAssertEqual(cost(of: wading, on: map), cost(of: try XCTUnwrap(plain.way(on: map, from: shore, to: goal, around: open)), on: map))
        var drowned = map
        for side in 0..<6 {
            let next = Int(map.neighbours[shore * 6 + side])
            if next >= 0 { drowned.set(index: next, Tile(terrain: .still)) }
        }
        XCTAssertNil(guided.way(on: drowned, from: shore, to: goal, around: open, guide: LieOfTheLand.measure(toward: goal, on: drowned)),
                     "Water all round, and no way")
    }

    /// A company's route in a wide lake is the guided one, the same from the
    /// realm's copy of the world and from a keeper's routes; a near march,
    /// or any in a lake of twelve seats, the plain one.
    func testOnlyFarMarchesInWideLakesAreGuided() throws {
        let wide = Scene.world("wide", houses: 4, radius: 48)
        let (start, goal) = try farEnds(of: wide.map)
        XCTAssertNotNil(wide.map.guide(from: start, to: goal))
        let near = try XCTUnwrap(land(of: wide.map).first { wide.map.hexes[$0].distance(to: wide.map.hexes[start]) == 3 })
        XCTAssertNil(wide.map.guide(from: start, to: near), "A near march")
        let narrow = Scene.world("narrow", houses: 4, radius: RealmState.defaultRadius).map
        let ends = try farEnds(of: narrow)
        XCTAssertGreaterThanOrEqual(narrow.hexes[ends.start].distance(to: narrow.hexes[ends.goal]), WorldMap.guidedFrom)
        XCTAssertNil(narrow.guide(from: ends.start, to: ends.goal), "A lake of twelve seats")

        var state = wide
        let unit = try XCTUnwrap(state.units.first)
        let target = wide.map.hexes[goal]
        guard let route = state.path(for: unit, to: target) else { return XCTFail("A way round the lake") }
        var routes = Routes(on: state)
        XCTAssertEqual(routes.path(for: unit, to: target), route, "The same from a keeper's routes")
        // From a copy that keeps nothing yet, the same way.
        state.map = try JSONDecoder().decode(WorldMap.self, from: JSONEncoder().encode(state.map))
        XCTAssertEqual(state.map.lie.count, 0)
        XCTAssertEqual(state.path(for: unit, to: target), route, "The same whatever is kept")
        XCTAssertEqual(state.map.lie.count, 1)
    }

    func testTheLieIsKeptWhileTheGroundStaysAndLetGoWhenItChanges() throws {
        var map = Scene.world("kept", houses: 4, radius: 48).map
        let land = land(of: map)
        let goal = land[land.count / 3], other = land[land.count / 2]
        let first = map.lie.toward(goal, on: map)
        XCTAssertEqual(map.lie.toward(goal, on: map), first)
        XCTAssertEqual(map.lie.count, 1)
        // A copy shares what is kept; one whose ground changes keeps its own.
        var copy = map
        XCTAssertTrue(copy.lie === map.lie)
        copy.set(index: other, Tile(terrain: .still))
        XCTAssertFalse(copy.lie === map.lie, "A copy whose ground changes keeps a lie of its own")
        XCTAssertEqual(copy.lie.toward(goal, on: copy)[other], LieOfTheLand.unreached, "Measured anew, of its own ground")
        XCTAssertNotEqual(map.lie.toward(goal, on: map)[other], LieOfTheLand.unreached, "The other's untouched")
        // Ground that changes nothing of a step lets go of nothing; a map no
        // copy shares lets go of what it kept in place.
        let tile = map[other]
        map.set(index: other, Tile(terrain: tile.terrain, feature: tile.feature, relief: tile.relief))
        XCTAssertEqual(map.lie.count, 1)
        let kept = ObjectIdentifier(map.lie)
        map.set(index: other, Tile(terrain: .still))
        XCTAssertEqual(ObjectIdentifier(map.lie), kept, "Its own, let go of in place")
        XCTAssertEqual(map.lie.count, 0)
        // No more goals are kept than the most.
        for goal in land.prefix(LieOfTheLand.kept + 1) { _ = map.lie.toward(goal, on: map) }
        XCTAssertEqual(map.lie.count, LieOfTheLand.kept)
    }
}
