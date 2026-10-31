import Foundation
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

/// Each age of the realm lies on a lake of its own shape: every shape must
/// seat twelve Houses fairly, with every seat reachable on foot.
final class LakeShapeTests: XCTestCase {
    private func reachable(from start: Hex, in map: WorldMap) -> Set<Hex> {
        var seen: Set<Hex> = [start]
        var frontier = [start]
        while let hex = frontier.popLast() {
            for next in map.neighbors(of: hex) where !seen.contains(next) && (map[next]?.terrain.isPassable ?? false) {
                seen.insert(next)
                frontier.append(next)
            }
        }
        return seen
    }

    /// The widest lakes seat their Houses as fairly as the realm proper's:
    /// forty-eight round a lake of radius 72, each shape, every seat with
    /// room and reachable on foot.
    func testEveryLakeSeatsFortyEightFairly() {
        for lake in Lake.allCases {
            let world = WorldGenerator(seed: Seed.from("wide shape"), radius: 72, houseCount: 48, lake: lake).generate()
            XCTAssertEqual(Set(world.seats).count, 48, "\(lake)")
            var nearest = Int.max
            for (index, seat) in world.seats.enumerated() {
                for other in world.seats[(index + 1)...] { nearest = min(nearest, seat.distance(to: other)) }
            }
            XCTAssertGreaterThanOrEqual(nearest, 6, "Room between the seats on \(lake)")
            let walk = reachable(from: world.seats[0], in: world.map)
            XCTAssertTrue(world.seats.allSatisfy(walk.contains), "Every seat reachable on foot on \(lake)")
        }
    }

    func testEveryLakeSeatsTwelveFairly() {
        var masks: [Lake: [Bool]] = [:]
        for lake in Lake.allCases {
            for text in ["shape one", "shape two", "shape three"] {
                let world = WorldGenerator(seed: Seed.from(text), radius: 36, houseCount: 12, lake: lake).generate()
                XCTAssertEqual(world.seats.count, 12, "\(lake) \(text)")
                var nearest = Int.max
                for (index, seat) in world.seats.enumerated() {
                    for other in world.seats[(index + 1)...] { nearest = min(nearest, seat.distance(to: other)) }
                }
                XCTAssertGreaterThanOrEqual(nearest, 6, "Room between the seats on \(lake) (\(text))")
                let walk = reachable(from: world.seats[0], in: world.map)
                XCTAssertTrue(world.seats.allSatisfy(walk.contains), "Every seat reachable on foot on \(lake) (\(text))")
                let water = world.map.tiles.filter { $0.terrain.isWater }.count
                let share = Double(water) / Double(world.map.count)
                XCTAssertTrue((0.08...0.45).contains(share), "\(lake): \(Int(share * 100))% water")
                if text == "shape one" { masks[lake] = world.map.tiles.map { $0.terrain.isWater } }
            }
        }
        // Each shape its own.
        for a in Lake.allCases {
            for b in Lake.allCases where a.rawValue < b.rawValue {
                let differ = zip(masks[a]!, masks[b]!).filter { $0 != $1 }.count
                XCTAssertGreaterThan(differ, masks[a]!.count / 25, "\(a) and \(b) look alike")
            }
        }
    }

    func testEachAgeHasItsLake() throws {
        XCTAssertEqual((1...5).map { Lake.of(age: $0) }, [.round, .twin, .crescent, .isles, .round])
        var realm = RealmState(name: "The Nullmere", seed: "ages", seats: 4, radius: 18, now: 0)
        XCTAssertEqual(realm.status(now: 0).lake, "the Nullmere")
        try realm.arrive("a", name: "Ama", now: 0)
        realm.world.outcome = Outcome(winner: 0, kind: .dominion, watch: realm.world.watch)
        _ = realm.tick(now: 1e12)
        XCTAssertEqual(realm.age, 2)
        XCTAssertEqual(realm.world.settings.lake, .twin)
        XCTAssertEqual(realm.status(now: 0).lake, "the Twin Waters")
        XCTAssertTrue(realm.world.chronicle.first?.text.contains("the Twin Waters") ?? false)
        // Worlds kept before lakes had shapes are round.
        let old = #"{"seedText":"x","houseCount":3,"radius":16,"playerHouse":"Aurel","keepers":1}"#
        XCTAssertEqual(try JSONDecoder().decode(GameSettings.self, from: Data(old.utf8)).lake, .round)
    }
}
