import Foundation
import XCTest
@testable import NullmereCore

/// A keeper's view crosses the network whenever it changes, and the realm
/// keeps the world in SpacetimeDB: both are kept small, and still read
/// what was kept before they were.
final class CompactWorldTests: XCTestCase {
    func testTheWorldComesBackExactly() throws {
        for seed in ["compact a", "compact b", "compact c"] {
            var realm = RealmState(name: "The Nullmere", seed: seed, now: 0)
            try realm.arrive("a", name: "Ama", now: 0)
            for _ in 0..<5 { realm.world.stewardTurnAll() }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(realm)
            let back = try JSONDecoder().decode(RealmState.self, from: data)
            XCTAssertEqual(back.world, realm.world, seed)
            let again = try encoder.encode(back)
            if again != data {
                let a = String(decoding: data, as: UTF8.self), b = String(decoding: again, as: UTF8.self)
                let start = zip(a, b).prefix { $0 == $1 }.count
                print("DIFF at \(start): \(a.dropFirst(max(0, start - 120)).prefix(240)) ||| \(b.dropFirst(max(0, start - 120)).prefix(240))")
            }
            XCTAssertEqual(again, data, "Stable when written again")
        }
    }

    func testAViewIsSmallEnoughToSendOften() throws {
        var realm = RealmState(name: "The Nullmere", seed: "small views", now: 0)
        try realm.arrive("a", name: "Ama", now: 0)
        let first = try JSONEncoder().encode(try XCTUnwrap(realm.view(for: "a"))).count
        for _ in 0..<100 { realm.world.stewardTurnAll() }
        let later = try JSONEncoder().encode(try XCTUnwrap(realm.view(for: "a"))).count
        print("PERF a keeper's view: \(first / 1024) KB at the first watch, \(later / 1024) KB after 100")
        XCTAssertLessThan(first, 64 * 1024)
        XCTAssertLessThan(later, 192 * 1024)
    }

    func testWorldsKeptInTheOldFormStillOpen() throws {
        let house: [String: Any] = [
            "id": 0, "name": "Ama", "sigil": 0, "isPlayer": true, "temperament": "ambitious",
            "stock": ["grain": 1, "timber": 2, "stone": 3, "moonsalt": 4],
            "explored": [true, false, false, true], "isEliminated": false,
        ]
        let decoded = try JSONDecoder().decode(House.self, from: try JSONSerialization.data(withJSONObject: house))
        XCTAssertEqual(decoded.explored, [true, false, false, true])
        XCTAssertEqual(decoded.stock.timber, 2)

        let map: [String: Any] = [
            "radius": 1,
            "tiles": (0..<7).map { index -> [String: Any] in
                index == 3 ? ["terrain": "blackwood", "feature": "elderGrove", "relief": 40] : ["terrain": "still", "relief": 0]
            },
        ]
        let world = try JSONDecoder().decode(WorldMap.self, from: try JSONSerialization.data(withJSONObject: map))
        XCTAssertEqual(world.tiles[3], Tile(terrain: .blackwood, feature: .elderGrove, relief: 40))
        XCTAssertEqual(world.tiles[0].terrain, .still)
    }

    /// Stored worlds name terrains and features by their place in these
    /// lists: new ones go at the end, and none moves.
    func testTheOrderOfTerrainsAndFeaturesHolds() {
        XCTAssertEqual(Terrain.allCases.map(\.rawValue), ["still", "shallows", "strand", "saltFlat", "greyfield", "blackwood", "barrow", "spine"])
        XCTAssertEqual(Feature.allCases.map(\.rawValue), ["moonsaltBed", "elderGrove", "stoneSeam", "darkLoam", "drownedRuin"])
        XCTAssertEqual(Bits.decode(Bits.encode([true, false, true, true, false, false, false, false, true])), [true, false, true, true, false, false, false, false, true])
        XCTAssertNil(Bits.decode("9:AAA"), "Too few bytes for the count")
        XCTAssertNil(WorldMap.tiles(fromCells: Data([200, 0, 0]).base64EncodedString()), "No such terrain")
    }
}

private extension GameState {
    mutating func stewardTurnAll() {
        for house in houses where !house.isEliminated { _ = stewardTurn(for: house.id) }
        _ = endWatch()
    }
}
