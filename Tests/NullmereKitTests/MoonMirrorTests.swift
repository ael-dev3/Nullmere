import NullmereCore
import XCTest
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
}
