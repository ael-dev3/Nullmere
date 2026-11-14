import Foundation
@testable import NullmereLive
import NullmereRealm
import XCTest

/// The realm's rows as the client reads them into a world, and what it
/// reckons from them between the realm's own words.
final class LiveWorldTests: XCTestCase {
    private func n(_ value: Double) -> JSONValue { .number(value) }

    func testAHexIsKeptAsOneNumberAsTheModuleKeepsIt() {
        for (q, r) in [(0, 0), (-128, 127), (300, -7), (-1, -1)] {
            let hex = LiveHex(q: q, r: r)
            XCTAssertEqual(LiveHex(packed: hex.packed), hex)
        }
        // As realm/src/hex.rs packs them: both halves offset by 32768.
        XCTAssertEqual(LiveHex(q: 0, r: 0).packed, 0x8000_8000)
        XCTAssertEqual(LiveHex(q: 1, r: -1).packed, 0x8001_7FFF)
        XCTAssertEqual(LiveHex(q: 3, r: -2).distance(to: LiveHex(q: 0, r: 0)), 3)
        XCTAssertEqual(LiveHex(q: -3, r: 5).distance(to: LiveHex(q: 0, r: 0)), 5)
        XCTAssertEqual(LiveHex(q: 2, r: 2).centre.x, 3.0.squareRoot() * 3, accuracy: 1e-12)
        XCTAssertEqual(LiveHex(q: 2, r: 2).centre.y, 3, accuracy: 1e-12)
    }

    func testRowsAreReadIntoAWorld() throws {
        let hex = LiveHex(q: 12, r: -30)
        let snapshot: [String: [[JSONValue]]] = [
            "realm": [[n(0), n(42), n(1_000), n(60), n(1_000), n(2), n(128)]],
            "player": [[n(1), n(99), .string("Ada"), n(1_000), .bool(true), n(1_010)], [n(2), n(98), .string("Bryn"), n(1_005), .bool(false), n(1_006)]],
            "city": [[n(7), n(1), n(Double(hex.packed)), .string("Ada"), n(3), n(940), n(1_000), n(1)]],
            "place": [[n(Double(hex.packed)), n(1), n(7)], [n(Double(LiveHex(q: 13, r: -30).packed)), n(2), n(5)]],
            "site": [[n(5), n(Double(LiveHex(q: 13, r: -30).packed)), n(2), n(4), n(80_000), n(0)]],
            "blueprint": [[n(Double(1 << 32 | 2)), n(1), n(2), .string("Keep"), n(0), n(620), n(310), n(0), n(8), n(400), n(400), n(300), n(0),
                           n(1), n(0), n(0), n(400)]],
            "soldier": [[n(Double(1 << 8 | 1)), n(1), n(1), .string("Spearmen"), n(90), n(110), n(110), n(60), n(12), n(1), n(50), n(50), n(0),
                         n(0), n(8_000), n(7), n(1)]],
            "land": [[n(Double(LiveHex(q: 0, r: -2).packed)), .string(String(repeating: "07", count: 255) + "08")]],
            "me": [[n(1), n(99), .string("Ada"), n(1_000), .bool(true), n(1_010)]],
            "my_city": [[n(7), n(1), n(Double(hex.packed)), .string("Ada"), n(3), n(940), n(1_000), n(1)]],
            "my_buildings": [[n(22), n(7), n(2), n(1)], [n(21), n(7), n(1), n(3)]],
            "my_jobs": [[n(4), n(7), n(1), n(21), n(4), n(0), n(2_000), n(2_180), n(9)]],
            "my_stock": [[n(7), n(6_000), n(8_000), n(29_990), n(0), n(2_000), n(1_300), n(1_300), n(300), n(0), n(0), n(1_800), n(0), n(0), n(30_000)]],
            "my_troops": [[n(Double(7 << 16 | 2 << 8 | 1)), n(7), n(2), n(1), n(40), n(3)], [n(Double(7 << 16 | 1 << 8 | 1)), n(7), n(1), n(1), n(60), n(0)]],
            "my_squads": [[n(Double(3 << 16 | 1 << 8 | 1)), n(3), n(1), n(1), n(20), n(4)]],
            "my_hauls": [[n(3), n(1), n(0), n(240), n(0), n(0)]],
            "barrow": [[n(9), n(Double(LiveHex(q: 14, r: -30).packed)), n(3), n(0)]],
            "my_hunt": [[n(1), n(940), n(2_000), n(1_000), n(8_000), n(2)]],
            "my_reports": [
                [n(31), n(1), n(1_900), n(1), n(Double(LiveHex(q: 14, r: -31).packed)), .bool(true), n(2), n(3), n(200), n(6), n(0), n(60), n(60),
                 n(1_600), n(1_600), n(0), n(0), .string("Your army cleared a level 2 barrow of the Unquiet."), .bool(true)],
                [n(32), n(1), n(1_950), n(1), n(Double(LiveHex(q: 14, r: -30).packed)), n(0), n(3), n(5), n(40), n(30), n(10), n(105), n(31),
                 n(0), n(0), n(0), n(0), .string("Your army was beaten at a level 3 barrow of the Unquiet."), n(0)],
            ],
        ]
        let world = LiveWorld(snapshot: snapshot)
        XCTAssertEqual(world.realm.map { [$0.opened, $0.pace, $0.radius] }, [1_000, 60, 128])
        XCTAssertEqual(world.players.count, 2)
        XCTAssertEqual(world.players[2]?.name, "Bryn")
        XCTAssertEqual(world.players[2]?.online, false)
        // A pushed row may carry true and false as 1 and 0.
        let pushed = LiveWorld(snapshot: ["player": [[n(3), n(1), .string("Cai"), n(5), n(1), n(6)], [n(4), n(1), .string("Dag"), n(5), n(0), n(6)]]])
        XCTAssertEqual(pushed.players[3]?.online, true)
        XCTAssertEqual(pushed.players[4]?.online, false)
        XCTAssertEqual(world.me?.name, "Ada")
        let city = try XCTUnwrap(world.city)
        XCTAssertEqual(city.hex, hex)
        XCTAssertEqual([city.keep, city.builders, city.founded], [3, 1, 1_000])
        XCTAssertEqual(world.cities[7], city)
        XCTAssertEqual(world.places[hex]?.kind, LivePlace.city)
        XCTAssertEqual(world.places[LiveHex(q: 13, r: -30)]?.id, 5)
        XCTAssertEqual(world.sites[5]?.left, 80_000)
        XCTAssertEqual(world.buildings.map(\.kind), [1, 2], "by kind")
        XCTAssertEqual(world.building(1)?.level, 3)
        XCTAssertNil(world.building(9))
        let keep = try XCTUnwrap(world.blueprint(1, level: 2))
        XCTAssertEqual(keep.name, "Keep")
        XCTAssertEqual(keep.cost, LiveGoods(timber: 620, stone: 310))
        XCTAssertEqual(keep.hourly, LiveGoods(grain: 400, timber: 400, stone: 300))
        XCTAssertEqual([keep.seconds, keep.opensAt, keep.needsBuilding], [8, 1, 0])
        XCTAssertNil(world.blueprint(1, level: 3))
        let spear = try XCTUnwrap(world.soldier(1, tier: 1))
        XCTAssertEqual(spear.cost, LiveGoods(grain: 50, timber: 50))
        XCTAssertEqual([spear.pace, spear.millis, spear.building, spear.needsLevel], [60, 8_000, 7, 1])
        XCTAssertEqual(world.troops.map { [$0.kind, Int($0.ready), Int($0.wounded)] }, [[1, 60, 0], [2, 40, 3]])
        XCTAssertEqual(world.squads.first.map { [$0.count, $0.wounded] }, [20, 4], "twenty fit to fight, four carried wounded")
        XCTAssertEqual(world.hauls.first?.goods, LiveGoods(timber: 240))
        XCTAssertTrue(LiveGoods(grain: 5, timber: 620, stone: 400).covers(keep.cost))
        XCTAssertFalse(LiveGoods(timber: 619, stone: 400).covers(keep.cost))

        // The Unquiet's barrows, where they stand; the player's energy as
        // it grows back; and what their armies did, the latest first.
        XCTAssertEqual(world.places.count, 2)
        var withBarrow = snapshot
        withBarrow["place"]?.append([n(Double(LiveHex(q: 14, r: -30).packed)), n(3), n(9)])
        let found = LiveWorld(snapshot: withBarrow)
        XCTAssertEqual(found.barrow(at: LiveHex(q: 14, r: -30))?.level, 3)
        XCTAssertNil(found.barrow(at: LiveHex(q: 13, r: -30)), "a site stands there, not a barrow")
        XCTAssertNil(found.barrow(at: LiveHex(q: 0, r: 0)))
        XCTAssertEqual(world.barrows[9].map { [$0.level, Int($0.fighter)] }, [3, 0])
        let hunt = try XCTUnwrap(world.hunt)
        XCTAssertEqual([hunt.energy, hunt.most, hunt.cleared, hunt.mayAttack], [940, 1_000, 2, 3])
        XCTAssertEqual(hunt.energy(at: 2_000), 940)
        XCTAssertEqual(hunt.energy(at: 2_007.9), 940, "a point every eight seconds")
        XCTAssertEqual(hunt.energy(at: 2_008), 941)
        XCTAssertEqual(hunt.energy(at: 2_480), 1_000)
        XCTAssertEqual(hunt.energy(at: 99_999), 1_000, "never past the most a player keeps")
        XCTAssertEqual(hunt.energy(at: 0), 940, "time never runs back")
        XCTAssertEqual(world.reports.map(\.id), [32, 31])
        XCTAssertEqual(world.unread, 1)
        let lost = try XCTUnwrap(world.reports.first)
        XCTAssertEqual(lost.kind, LiveReport.hunt)
        XCTAssertFalse(lost.won)
        XCTAssertEqual(lost.hex, LiveHex(q: 14, r: -30))
        XCTAssertEqual([lost.foe, lost.fought, lost.wounded, lost.dead, lost.stood, lost.fell], [3, 40, 30, 10, 105, 31])
        XCTAssertEqual([lost.rounds, lost.at], [5, 1_950])
        XCTAssertTrue(lost.spoils.isNone)
        XCTAssertEqual(lost.words, "Your army was beaten at a level 3 barrow of the Unquiet.")
        let won = world.reports[1]
        XCTAssertTrue(won.won && won.read)
        XCTAssertEqual(won.spoils, LiveGoods(grain: 1_600, timber: 1_600))
        XCTAssertNil(LiveWorld(snapshot: [:]).hunt)

        // Work under way: how far along, and how long left.
        let job = try XCTUnwrap(world.jobs.first)
        XCTAssertEqual([job.kind, Int(job.subject), job.level], [LiveJob.raise, 21, 4])
        XCTAssertEqual(job.progress(at: 2_090), 0.5, accuracy: 1e-9)
        XCTAssertEqual(job.progress(at: 1_000), 0)
        XCTAssertEqual(job.progress(at: 9_999), 1)
        XCTAssertEqual(job.left(at: 2_100), 80)
        XCTAssertEqual(job.left(at: 3_000), 0)

        // Goods grow between the realm's words as the realm reckons them.
        let stock = try XCTUnwrap(world.stock)
        XCTAssertEqual(stock.goods(at: 2_000), LiveGoods(grain: 6_000, timber: 8_000, stone: 29_990))
        XCTAssertEqual(stock.goods(at: 5_600), LiveGoods(grain: 7_300, timber: 9_300, stone: 30_000), "an hour on; stone stops at what the city holds")
        XCTAssertEqual(stock.goods(at: 2_005).timber, 8_002, "timber had half a unit earned already: 1,800 of 3,600, and five seconds more")
        XCTAssertEqual(stock.goods(at: 1_000), stock.goods, "time never runs back")

        // The land: a byte a hex, sixteen by sixteen, chunks keyed by their own place.
        XCTAssertEqual(world.ground(at: LiveHex(q: 0, r: -32)), 7)
        XCTAssertEqual(world.ground(at: LiveHex(q: 15, r: -17)), 8, "the chunk's last hex")
        XCTAssertNil(world.ground(at: LiveHex(q: 16, r: -17)), "a chunk not known")
        XCTAssertNil(world.ground(at: LiveHex(q: -1, r: -32)))

        // Nothing at all is an empty world, and rows that don't read are left out.
        XCTAssertEqual(LiveWorld(snapshot: [:]), LiveWorld())
        XCTAssertTrue(LiveWorld(snapshot: ["city": [[.string("x")]], "my_stock": [[]]]).cities.isEmpty)
    }

    /// What a call carries goes in its body as the module reads it: a
    /// hex's place may be below zero, and a march's soldiers are records
    /// by name.
    func testACallsArgumentsGoAsTheModuleReadsThem() throws {
        let arguments: [ReducerArgument] = [.signed(-3), .signed(5), .integer(2), .records([["kind": 1, "tier": 2, "count": 20]])]
        XCTAssertEqual(arguments[0].json as? Int64, -3)
        XCTAssertEqual(arguments[3].json as? [[String: UInt64]], [["kind": 1, "tier": 2, "count": 20]])
        let body = try JSONSerialization.data(withJSONObject: arguments.map(\.json), options: [.sortedKeys])
        XCTAssertEqual(String(decoding: body, as: UTF8.self), #"[-3,5,2,[{"count":20,"kind":1,"tier":2}]]"#)
    }

    func testAMarchIsSomewhereAlongItsWayAtEveryMoment() throws {
        // Three hexes east, as the module keeps a way: q then r, sixteen bits each, low byte first.
        let way = [LiveHex(q: -1, r: 2), LiveHex(q: 0, r: 2), LiveHex(q: 1, r: 2), LiveHex(q: 2, r: 2)]
        let bytes = way.flatMap { hex -> [UInt8] in
            let (q, r) = (UInt16(bitPattern: Int16(hex.q)), UInt16(bitPattern: Int16(hex.r)))
            return [UInt8(q & 0xFF), UInt8(q >> 8), UInt8(r & 0xFF), UInt8(r >> 8)]
        }
        XCTAssertEqual(Array(bytes.prefix(4)), [0xFF, 0xFF, 0x02, 0x00])
        let hexText = bytes.map { String(format: "%02x", $0) }.joined()
        func march(state: Int, route: JSONValue) -> [JSONValue] {
            [n(3), n(1), n(7), n(1), n(Double(state)), n(Double(way[0].packed)), n(Double(way[3].packed)), n(5), n(100), n(118), n(20), route, n(4)]
        }
        let going = try XCTUnwrap(LiveMarch(march(state: LiveMarch.going, route: .string(hexText))))
        XCTAssertEqual(going.route, way)
        XCTAssertEqual([going.from, going.to], [way[0], way[3]])
        XCTAssertEqual(going.soldiers, 20)
        XCTAssertEqual(going.progress(at: 109), 0.5, accuracy: 1e-9)
        let start = going.position(at: 100), middle = going.position(at: 109), end = going.position(at: 118)
        XCTAssertEqual(start.x, way[0].centre.x, accuracy: 1e-9)
        XCTAssertEqual(end.x, way[3].centre.x, accuracy: 1e-9)
        XCTAssertEqual(middle.x, (way[1].centre.x + way[2].centre.x) / 2, accuracy: 1e-9, "half way along, between its second and third hexes")
        XCTAssertEqual(middle.y, way[0].centre.y, accuracy: 1e-9)
        XCTAssertEqual(going.position(at: 50).x, start.x, "not yet gone")
        XCTAssertEqual(going.position(at: 500).x, end.x, "and no further than its end")

        // The same way as a list of numbers reads the same; at work it stands at its site.
        let listed = try XCTUnwrap(LiveMarch(march(state: LiveMarch.working, route: .array(bytes.map { n(Double($0)) }))))
        XCTAssertEqual(listed.route, way)
        XCTAssertEqual(listed.position(at: 109).x, way[3].centre.x, accuracy: 1e-9)
        XCTAssertTrue(listed.stands)
        XCTAssertFalse(going.stands)
        // In a fight it stands at its barrow as long as the fight lasts.
        let fighting = try XCTUnwrap(LiveMarch(march(state: LiveMarch.fighting, route: .string(hexText))))
        XCTAssertTrue(fighting.stands)
        XCTAssertEqual(fighting.position(at: 100).x, way[3].centre.x, accuracy: 1e-9)
        XCTAssertEqual(fighting.position(at: 109).x, way[3].centre.x, accuracy: 1e-9)
        XCTAssertEqual([LiveMarch.gather, LiveMarch.hunt], [1, 2])
        XCTAssertNil(LiveMarch(march(state: 1, route: .string("xyz"))), "a way that doesn't read")

        var world = LiveWorld()
        world.marches = [3: going]
        XCTAssertTrue(world.myMarches.isEmpty, "no player, no marches of theirs")
        world.me = LivePlayer([n(1), n(9), .string("Ada"), n(0), .bool(true), n(0)])
        XCTAssertEqual(world.myMarches.map(\.id), [3])
    }
}
