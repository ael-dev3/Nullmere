import XCTest
@testable import NullmereCore
@testable import NullmereKit

final class MoonMirrorTests: XCTestCase {
    func testTheMoonLiesInTheDeepestWaterOfEveryLake() throws {
        for lake in Lake.allCases {
            let world = WorldGenerator(seed: Seed.from("moon on \(lake.rawValue)"), radius: 36, houseCount: 12, lake: lake).generate()
            let (hex, depth) = try XCTUnwrap(MoonMirror.deepest(in: world.map), "\(lake)")
            XCTAssertEqual(world.map[hex]?.terrain, .still, "\(lake): in open water")
            XCTAssertGreaterThanOrEqual(depth, 2, "\(lake): deep enough to hold it")
            let moon = MoonMirror.place(in: world.map)
            XCTAssertEqual(moon.w, 1, "\(lake): it shows")
            XCTAssertLessThanOrEqual(moon.z, 1.05)
            // Every hex the disc covers is open water.
            let centre = HexLayout(size: 1).center(of: hex)
            for neighbour in hex.spiral(1) {
                let point = HexLayout(size: 1).center(of: neighbour)
                let apart = ((point.x - centre.x) * (point.x - centre.x) + (point.y - centre.y) * (point.y - centre.y)).squareRoot()
                if apart < Double(moon.z) { XCTAssertEqual(world.map[neighbour]?.terrain, .still, "\(lake)") }
            }
            if lake == .twin {
                XCTAssertGreaterThan(abs(centre.x), 6, "On the Twin Waters, in one of the lakes, not on the neck between")
            }
        }
        // A world with no open water has no moon in it.
        let dry = WorldMap(radius: 3, fill: Tile(terrain: .greyfield))
        XCTAssertEqual(MoonMirror.place(in: dry).w, 0)
    }

    /// A keeper's view, the unexplored left as land, still shows the moon
    /// where the whole lake puts it, from the first watch; a world from
    /// before the realm found it falls back to the map as known.
    func testTheMoonStaysPutAsTheLakeIsExplored() throws {
        var world = GameState(settings: GameSettings(seedText: "moon in the fog", keepers: 0))
        let whole = MoonMirror.place(in: world.map)
        XCTAssertEqual(world.moonWater?.hex, MoonMirror.deepest(in: world.map)?.0)
        let view = world.view(for: 0)
        XCTAssertNotEqual(MoonMirror.place(in: view.map), whole, "The fogged map alone would put it elsewhere")
        XCTAssertEqual(MoonMirror.place(for: view), whole)
        world.moonWater = nil
        XCTAssertEqual(MoonMirror.place(for: world), whole)
    }
}
