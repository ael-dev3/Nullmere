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
        // A whole view after 100 watches; views travel in parts, only what
        // changed resent, so this bounds the first sending. Raised from 192
        // KB as the realm's systems grew and its ages ran busier; to 212 KB
        // as the Lyceum, sitting at the hundred-and-first watch, carried
        // its five questions in every view.
        XCTAssertLessThan(later, 212 * 1024)
    }

    /// A keeper's view of a realm of forty-eight seats: the other Houses'
    /// ground, unexplored as a view tells it, travels as its count alone,
    /// not as the map's length in zeros, and comes back as long.
    func testAWideRealmsViewCarriesNoGroundOfOthers() throws {
        var wide = RealmState(name: "The Wide Nullmere", seed: "small views", seats: 48, now: 0)
        try wide.arrive("a", name: "Ama", now: 0)
        let view = try XCTUnwrap(wide.view(for: "a"))
        let data = try JSONEncoder().encode(view)
        print("PERF a keeper's view of a realm of 48 seats: \(data.count / 1024) KB at the first watch")
        XCTAssertLessThan(data.count, 192 * 1024)
        let unexplored = "\"\(wide.world.map.count):\(Bits.noneSet)\""
        XCTAssertEqual(String(decoding: data, as: UTF8.self).components(separatedBy: unexplored).count - 1, 47)
        let decoded = try JSONDecoder().decode(RealmView.self, from: data)
        XCTAssertEqual(decoded.world.houses.filter { $0.id != view.world.player }.map(\.explored),
                       Array(repeating: Explored(repeating: false, count: wide.world.map.count), count: 47))
        XCTAssertEqual(decoded, view)
    }

    func testAMarchTravelsAsItsWay() throws {
        let route = [Hex(3, -2), Hex(4, -2), Hex(4, -1), Hex(3, 0), Hex(3, -1)]
        let march = March(unit: 7, owner: 1, route: route, destination: Hex(9, 9), arrives: 12)
        let data = try JSONEncoder().encode(march)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains(#""way":"3,-2:0542""#))
        XCTAssertEqual(try JSONDecoder().decode(March.self, from: data), march)

        let alone = March(unit: 7, owner: 1, route: [Hex(-5, 2)], destination: nil, arrives: nil)
        XCTAssertEqual(March.way(of: alone.route), "-5,2")
        XCTAssertEqual(try JSONDecoder().decode(March.self, from: try JSONEncoder().encode(alone)), alone)

        // A route that leaps, or none, is written out whole.
        for odd in [[Hex(0, 0), Hex(2, 0)], []] {
            let kept = March(unit: 1, owner: 0, route: odd, destination: nil, arrives: nil)
            XCTAssertNil(March.way(of: odd))
            XCTAssertEqual(try JSONDecoder().decode(March.self, from: try JSONEncoder().encode(kept)), kept)
        }

        // Views from before ways still open.
        let old: [String: Any] = ["unit": 4, "owner": 2, "route": [["q": 1, "r": 1], ["q": 2, "r": 1]], "arrives": 9]
        let opened = try JSONDecoder().decode(March.self, from: try JSONSerialization.data(withJSONObject: old))
        XCTAssertEqual(opened, March(unit: 4, owner: 2, route: [Hex(1, 1), Hex(2, 1)], destination: nil, arrives: 9))

        for bad in ["", "3", "3,x", "1,2:9", "1,2:0a"] {
            let text = #"{"unit":1,"owner":0,"way":"\#(bad)"}"#
            XCTAssertThrowsError(try JSONDecoder().decode(March.self, from: Data(text.utf8)), bad)
        }
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

        let relation: [String: Any] = ["first": 2, "second": 5, "stance": "war", "since": 40, "aggressor": 5, "betrayals": 1]
        let kept = try JSONDecoder().decode(Relation.self, from: try JSONSerialization.data(withJSONObject: relation))
        XCTAssertEqual([kept.first, kept.second, kept.since, kept.aggressor, kept.betrayals], [2, 5, 40, 5, 1])
        XCTAssertEqual(kept.stance, .war)
        XCTAssertNil(kept.tributePaid)
    }

    /// A relation travels as one line, what it holds beyond its stance only
    /// as far as it holds any, and comes back exactly.
    func testARelationTravelsAsOneLine() throws {
        func line(_ relation: Relation) throws -> String { String(decoding: try JSONEncoder().encode(relation), as: UTF8.self) }
        var relation = Relation(first: 7, second: 3)
        XCTAssertEqual(try line(relation), #""3,7,peace,1""#)
        relation.stance = .war
        relation.since = 55
        relation.aggressor = 7
        XCTAssertEqual(try line(relation), #""3,7,war,55,7""#)
        relation.tributeRefused = 60
        XCTAssertEqual(try line(relation), #""3,7,war,55,7,,,60""#)
        relation.betrayals = 2
        relation.tributePaid = 30
        relation.aggressor = nil
        XCTAssertEqual(try line(relation), #""3,7,war,55,,2,30,60""#)
        for kept in [Relation(first: 0, second: 1), relation] {
            XCTAssertEqual(try JSONDecoder().decode(Relation.self, from: try JSONEncoder().encode(kept)), kept)
        }
        for bad in ["", "3,7,peace", "3,7,truce,1", "x,7,peace,1", "3,7,peace,1,a", "3,7,peace,1,,,,,9"] {
            XCTAssertThrowsError(try JSONDecoder().decode(Relation.self, from: Data("\"\(bad)\"".utf8)), bad)
        }
        // A realm of forty-eight seats keeps 1,128 relations: as lines, a
        // tenth of a keeper's first view, not half.
        let wide = RealmState.world(seed: "relations", age: 1, seats: 48, radius: RealmState.radius(forSeats: 48))
        XCTAssertEqual(wide.relations.count, 48 * 47 / 2)
        let size = try JSONEncoder().encode(wide.relations).count
        print("PERF a realm of 48 seats' relations: \(size / 1024) KB")
        XCTAssertLessThan(size, 20 * 1024)
    }

    /// A company travels as one line, what it has beyond what every
    /// company has only as far as it has any, its errand, load, drilling
    /// ground and way beside it; and comes back exactly. A company written
    /// field by field, as companies were, reads as it did.
    func testACompanyTravelsAsOneLine() throws {
        func json(_ unit: NullmereCore.Unit) throws -> String { String(decoding: try JSONEncoder().encode(unit), as: UTF8.self) }
        var unit = NullmereCore.Unit(id: 7, kind: .bow, owner: 2, position: Hex(3, -1))
        XCTAssertEqual(try json(unit), #"{"u":"7,bow,2,3,-1,100,\#(UnitKind.bow.movement),0,0,0,1"}"#)
        unit.fortified = true
        unit.acted = true
        unit.experience = 4
        unit.tier = 3
        unit.health = 61
        unit.movesLeft = 0
        unit.drilled = 2_500
        XCTAssertEqual(unit.line, "7,bow,2,3,-1,61,0,1,1,4,3,,,,2500")
        unit.destination = Hex(-4, 9)
        unit.leader = 12
        unit.second = 13
        XCTAssertEqual(unit.line, "7,bow,2,3,-1,61,0,1,1,4,3,-4:9,12,13,2500")
        unit.errand = .homeward
        unit.load = Stock(grain: 5, moonsalt: 1)
        unit.drillAt = Hex(1, 1)
        for kept in [NullmereCore.Unit(id: 0, kind: .spear, owner: 0, position: Hex(0, 0)), unit] {
            XCTAssertEqual(try JSONDecoder().decode(NullmereCore.Unit.self, from: try JSONEncoder().encode(kept)), kept)
        }
        for bad in ["", "7,bow,2,3,-1,100,4,0,0,0", "7,axe,2,3,-1,100,4,0,0,0,1", "7,bow,2,3,-1,100,4,2,0,0,1", "x,bow,2,3,-1,100,4,0,0,0,1",
                    "7,bow,2,3,-1,100,4,0,0,0,1,", "7,bow,2,3,-1,100,4,0,0,0,1,4", "7,bow,2,3,-1,100,4,0,0,0,1,4:x",
                    "7,bow,2,3,-1,100,4,0,0,0,1,,,,,9", "7,bow,2,3,-1,100,4,0,0,0,1,,a"] {
            XCTAssertThrowsError(try JSONDecoder().decode(NullmereCore.Unit.self, from: Data(#"{"u":"\#(bad)"}"#.utf8)), bad)
        }

        // Written field by field, as companies were before.
        var fields: [String: Any] = ["id": 7, "kind": "bow", "owner": 2, "position": ["q": 3, "r": -1], "health": 61, "movesLeft": 0,
                                     "fortified": true, "acted": true, "experience": 4, "tier": 3, "destination": ["q": -4, "r": 9],
                                     "leader": 12, "second": 13, "drilled": 2_500, "drillAt": ["q": 1, "r": 1]]
        fields["errand"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Errand.homeward))
        fields["load"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(unit.load))
        XCTAssertEqual(try JSONDecoder().decode(NullmereCore.Unit.self, from: JSONSerialization.data(withJSONObject: fields)), unit)

        // A wide realm's companies as lines: a fifth of what they were.
        let wide = RealmState.world(seed: "companies", age: 1, seats: 48, radius: RealmState.radius(forSeats: 48))
        let size = try JSONEncoder().encode(Array(wide.units)).count
        let named = try wide.units.reduce(0) { total, unit in
            let fields: [String: Any] = ["id": unit.id, "kind": unit.kind.rawValue, "owner": unit.owner, "position": ["q": unit.position.q, "r": unit.position.r],
                                         "health": unit.health, "movesLeft": unit.movesLeft, "fortified": unit.fortified, "acted": unit.acted,
                                         "experience": unit.experience, "tier": unit.tier]
            return total + (try JSONSerialization.data(withJSONObject: fields)).count + 1
        }
        print("PERF a realm of 48 seats' companies: \(size / 1024) KB as lines, \(named / 1024) KB field by field")
        XCTAssertLessThan(size * 3, named)
    }

    /// Stored worlds name terrains and features by their place in these
    /// lists: new ones go at the end, and none moves.
    func testTheOrderOfTerrainsAndFeaturesHolds() {
        XCTAssertEqual(Terrain.allCases.map(\.rawValue), ["still", "shallows", "strand", "saltFlat", "greyfield", "blackwood", "barrow", "spine", "ford",
                                                         "stream", "shoal"])
        XCTAssertEqual(Feature.allCases.map(\.rawValue), ["moonsaltBed", "elderGrove", "stoneSeam", "darkLoam", "drownedRuin"])
        XCTAssertEqual(Bits.decode(Bits.encode([true, false, true, true, false, false, false, false, true])), [true, false, true, true, false, false, false, false, true])
        XCTAssertNil(Bits.decode("9:AAA"), "Too few bytes for the count")
        // None set travels as its count alone, and comes back as many; the
        // full form of none set still reads.
        XCTAssertEqual(Bits.encode([false, false, false]), "3:-")
        XCTAssertEqual(Bits.decode("3:-"), [false, false, false])
        XCTAssertEqual(Bits.decode("0:-"), [])
        XCTAssertEqual(Bits.decode("3:AA=="), [false, false, false])
        XCTAssertNil(Bits.decode("-1:-"))
        XCTAssertNil(WorldMap.tiles(fromCells: Data([200, 0, 0]).base64EncodedString()), "No such terrain")
    }
}

private extension GameState {
    mutating func stewardTurnAll() {
        for house in houses where !house.isEliminated { _ = stewardTurn(for: house.id) }
        _ = endWatch()
    }
}
