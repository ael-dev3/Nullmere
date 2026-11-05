import Foundation
import XCTest
@testable import NullmereCore

/// The nearest hex of a terrain: found ring by ring, the same as a search of
/// the whole map would find it; kept with the map while its ground stays,
/// let go of when it changes, and never given to a map of other ground.
final class NearestTests: XCTestCase {
    /// What a search of every hex would find.
    private func everywhere(_ terrain: Terrain, to hex: Hex, on map: WorldMap) -> Hex? {
        map.hexes.filter { map[$0]?.terrain == terrain }.min { ($0.distance(to: hex), $0.q, $0.r) < ($1.distance(to: hex), $1.q, $1.r) }
    }

    func testTheNearestIsWhatASearchOfTheWholeMapFinds() throws {
        let map = Scene.world("the nearest ridge", houses: 6, radius: 18).map
        for hex in stride(from: 0, to: map.count, by: map.count / 25).map({ map.hexes[$0] }) {
            for terrain in [Terrain.spine, .blackwood, .still] {
                XCTAssertEqual(map.nearest(terrain, to: hex), everywhere(terrain, to: hex, on: map), "\(terrain) from \(hex)")
                XCTAssertEqual(map.nearest(terrain, to: hex), everywhere(terrain, to: hex, on: map), "and again, as kept")
            }
        }
    }

    func testItIsLetGoOfWhenTheGroundChanges() throws {
        var map = Scene.world("a ridge raised", houses: 4, radius: 14).map
        let from = try XCTUnwrap(map.hexes.first { map[$0]?.terrain != .spine })
        let far = try XCTUnwrap(map.nearest(.spine, to: from))
        XCTAssertGreaterThan(far.distance(to: from), 0)
        let copy = map
        // A ridge raised where the hex itself stands is now nearest.
        var tile = try XCTUnwrap(map[from])
        tile.terrain = .spine
        map.set(from, tile)
        XCTAssertEqual(map.nearest(.spine, to: from), from)
        XCTAssertEqual(copy.nearest(.spine, to: from), far, "A copy of the ground before keeps its own")
        // A terrain the map has none of: none, and none again as kept.
        if let absent = Terrain.allCases.first(where: { terrain in !map.hexes.contains { map[$0]?.terrain == terrain } }) {
            XCTAssertNil(map.nearest(absent, to: from))
            XCTAssertNil(map.nearest(absent, to: from))
        }
    }

    func testMapsOfOtherGroundAreToldApart() throws {
        let a = Scene.world("one lake", houses: 4, radius: 14).map, b = Scene.world("another lake", houses: 4, radius: 14).map
        XCTAssertEqual(a.count, b.count, "The same size of map")
        for hex in stride(from: 0, to: a.count, by: a.count / 20).map({ a.hexes[$0] }) {
            XCTAssertEqual(a.nearest(.spine, to: hex), everywhere(.spine, to: hex, on: a))
            XCTAssertEqual(b.nearest(.spine, to: hex), everywhere(.spine, to: hex, on: b), "Each map's own ridge, never the other's")
        }
    }
}
