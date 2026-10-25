import XCTest
@testable import NullmereCore

final class WorldTests: XCTestCase {
    private let seeds = ["the still water", "moonlight on salt", "seven houses", "black mirror", "a long night"]

    func testTheSameSeedMakesTheSameWorld() {
        let a = WorldGenerator(seed: Seed.from("black mirror")).generate()
        let b = WorldGenerator(seed: Seed.from("black mirror")).generate()
        XCTAssertEqual(a.map, b.map)
        XCTAssertEqual(a.seats, b.seats)
        let c = WorldGenerator(seed: Seed.from("white mirror")).generate()
        XCTAssertNotEqual(a.map, c.map)
    }

    func testEveryWorldIsABasinAroundAGreatLake() {
        for text in seeds {
            let world = WorldGenerator(seed: Seed.from(text)).generate()
            let map = world.map
            let water = (0..<map.count).filter { map[$0].terrain.isWater }.count
            XCTAssertGreaterThan(water * 100 / map.count, 15, "\(text): the lake is the heart of the world")
            XCTAssertEqual(map[Hex.origin]?.terrain.isWater, true, "\(text): the centre is lake")
            for hex in map.hexes where hex.length == map.radius {
                XCTAssertEqual(map[hex]?.terrain, .spine, "\(text): the Spine walls the world")
            }
        }
    }

    func testSeatsAreFairAndFarApart() {
        for text in seeds {
            let world = WorldGenerator(seed: Seed.from(text)).generate()
            XCTAssertEqual(world.seats.count, 5)
            for (i, seat) in world.seats.enumerated() {
                XCTAssertEqual(world.map[seat]?.terrain, .greyfield)
                for other in world.seats[(i + 1)...] {
                    XCTAssertGreaterThanOrEqual(seat.distance(to: other), 8, "\(text): seats too close")
                }
                let near = seat.spiral(5).compactMap { world.map[$0] }
                XCTAssertTrue(near.contains { $0.terrain == .saltFlat }, "\(text): every seat has moonsalt in reach")
                XCTAssertTrue(seat.spiral(2).compactMap { world.map[$0] }.contains { $0.terrain == .blackwood })
            }
        }
    }

    func testEveryRuinAndSeatCanBeReachedOnFoot() {
        for text in seeds {
            let world = WorldGenerator(seed: Seed.from(text)).generate()
            let map = world.map
            var seen: Set<Hex> = [world.seats[0]]
            var queue = [world.seats[0]]
            while let hex = queue.popLast() {
                for next in map.neighbors(of: hex) where !seen.contains(next) && map[next]!.terrain.isPassable {
                    seen.insert(next)
                    queue.append(next)
                }
            }
            for seat in world.seats {
                XCTAssertTrue(seen.contains(seat), "\(text): seat \(seat) cut off")
            }
            for hex in map.hexes where map[hex]?.feature == .drownedRuin {
                XCTAssertTrue(seen.contains(hex), "\(text): ruin \(hex) cut off")
            }
        }
    }
}
