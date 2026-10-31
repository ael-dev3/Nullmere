import Foundation
import XCTest
@testable import NullmereCore

/// The Frontier, where the kingdoms of several realms meet: a keeper
/// crosses from home for the season open there, with a levy of their
/// House's companies of war; the Frontier seats only those its bordering
/// realms list, each for their realm's kingdom and at war with every
/// other's; strikes across kingdoms score; the season ends after its
/// watches, and is told home once, the prevailing kingdom's keepers' Houses
/// given its spoils.
final class FrontierTests: XCTestCase {
    private func home(_ name: String = "The Nullmere", seed: String = "west") -> RealmState {
        RealmState(name: name, seed: seed, seats: 4, radius: 18, watchLength: 60, now: 0)
    }

    private func frontier() -> RealmState {
        RealmState(frontier: "The Lost Shore", seed: "frontier", seats: 4, radius: 18, watchLength: 60, now: 0)
    }

    private func news(open: Bool = true, season: Int = 1, last: FrontierResult? = nil) -> FrontierNews {
        FrontierNews(address: "http://127.0.0.1:3000/frontier", season: season, watch: 3, lasts: FrontierState.lasts, open: open,
                     standings: [], last: last)
    }

    func testAKeeperCrossesForTheSeasonOpenThereWithTheirHousesLevy() throws {
        var home = home()
        let ilsen = try home.arrive("id-ilsen", name: "Ilsen", now: 1)
        let house = try XCTUnwrap(ilsen.house)
        XCTAssertThrowsError(try home.cross("id-ilsen")) { XCTAssertEqual($0 as? RealmError, .refused("No season is open at the Frontier.")) }
        XCTAssertNil(home.status(now: 2).frontier)
        XCTAssertNil(home.status(now: 2).crossings, "No Frontier heard of, nothing to list")
        home.hearFrontier(news(open: false))
        XCTAssertThrowsError(try home.cross("id-ilsen"), "Closed between seasons")
        home.hearFrontier(news())
        XCTAssertThrowsError(try home.cross("id-stranger")) { XCTAssertEqual($0 as? RealmError, .unknownKeeper) }
        XCTAssertEqual(home.status(now: 2).crossings, [], "None yet")

        // The levy: the House's strongest companies of war, at most six.
        let levy = home.levy(of: house)
        XCTAssertFalse(levy.isEmpty)
        XCTAssertLessThanOrEqual(levy.count, FrontierState.levyMost)
        XCTAssertTrue(levy.allSatisfy(\.kind.isMilitary))
        XCTAssertEqual(levy.map(\.tier), levy.map(\.tier).sorted(by: >), "Strongest first")

        // As the keeper's client sends it: an order.
        let events = try home.perform(.crossToFrontier, by: "id-ilsen")
        XCTAssertEqual(events, [.frontier(.crossed(house: house, season: 1, levy: levy.count))])
        XCTAssertThrowsError(try home.cross("id-ilsen")) { XCTAssertEqual($0 as? RealmError, .refused("You have crossed for this season already.")) }
        let status = home.status(now: 3)
        XCTAssertEqual(status.frontier?.address, "http://127.0.0.1:3000/frontier")
        let crossing = try XCTUnwrap(status.crossings?.first)
        XCTAssertEqual(crossing, Crossing(keeper: "id-ilsen", name: "Ilsen", realm: "The Nullmere", season: 1,
                                          heritage: home.world.heritage(of: house), levy: levy))
        XCTAssertTrue(home.world.chronicle.contains { $0.text.contains("across to the Frontier for its first season") })
        // Heard by the keeper's House alone.
        XCTAssertNotNil(home.world.tidings(of: events[0], for: house))
        XCTAssertNil(home.world.tidings(of: events[0], for: (house + 1) % 4))
        XCTAssertEqual(home.world.events(events, heardBy: house), events)
        XCTAssertEqual(home.world.events(events, heardBy: (house + 1) % 4), [])
        // The lake alone sends no one anywhere.
        var world = home.world
        XCTAssertThrowsError(try world.perform(.crossToFrontier, as: house)) { XCTAssertEqual($0 as? RuleError, .notApplicable) }
        // A Frontier sends no one on.
        var lost = frontier()
        lost.frontierNews = news()
        XCTAssertEqual(lost.crossings, [])
    }

    func testOnlyThoseCrossingTakeItsSeatsEachForTheirKingdomAtWarWithTheOthers() throws {
        var frontier = frontier()
        XCTAssertEqual(frontier.frontierReport?.season, 1)
        XCTAssertEqual(frontier.frontierReport?.open, true)
        XCTAssertThrowsError(try frontier.arrive("id-stranger", name: "Stranger", now: 1)) { error in
            guard case .refused = error as? RealmError else { return XCTFail("\(error)") }
        }
        let west = Crossing(keeper: "id-ilsen", name: "Ilsen", realm: "The Nullmere", season: 1, heritage: .moundClans,
                            levy: [Levy(kind: .spear, tier: 3), Levy(kind: .bow, tier: 2)])
        let east = Crossing(keeper: "id-orla", name: "Ilsen", realm: "The Farmere", season: 1, heritage: nil, levy: [Levy(kind: .rider, tier: 2)])
        let impostor = Crossing(keeper: "id-mallow", name: "Mallow", realm: "The Nullmere", season: 1, heritage: nil, levy: [])
        let stale = Crossing(keeper: "id-old", name: "Old", realm: "The Farmere", season: 0, heritage: nil, levy: [])
        frontier.admit([west], from: "The Nullmere")
        frontier.admit([east, impostor, stale], from: "The Farmere")
        XCTAssertEqual(Set(frontier.frontier.map { Array($0.admitted.keys) } ?? []), ["id-ilsen", "id-orla"], "A realm lists its own, for this season")
        XCTAssertThrowsError(try frontier.arrive("id-mallow", name: "Mallow", now: 1))

        let ilsen = try frontier.arrive("id-ilsen", name: "Someone Else", now: 2)
        XCTAssertEqual(ilsen.name, "Ilsen", "By the name they go by at home")
        let mine = try XCTUnwrap(ilsen.house)
        XCTAssertEqual(frontier.takeArrivals(), [.frontier(.raised(house: mine, realm: "The Nullmere", levy: 2))])
        XCTAssertEqual(frontier.takeArrivals(), [], "Told once")
        let orla = try frontier.arrive("id-orla", name: nil, now: 3)
        XCTAssertEqual(orla.name, "Ilsen of Farmere", "Another of the same name goes by their realm's")
        let theirs = try XCTUnwrap(orla.house)
        XCTAssertEqual(frontier.takeArrivals(), [.frontier(.raised(house: theirs, realm: "The Farmere", levy: 1))])
        XCTAssertEqual(frontier.frontier?.kingdom(of: mine), "The Nullmere")
        XCTAssertEqual(frontier.frontier?.kingdom(of: theirs), "The Farmere")
        XCTAssertNil(frontier.frontier?.kingdom(of: (0..<4).first { $0 != mine && $0 != theirs }!), "The Lost Shore's own Houses stand for none")
        XCTAssertTrue(frontier.world.isAtWar(mine, theirs), "Kingdoms meet at war")
        XCTAssertEqual(frontier.world.heritage(of: mine), .moundClans, "In their people's way")
        let levied = frontier.world.units.filter { $0.owner == mine }.map { Levy(kind: $0.kind, tier: $0.tier) }
        XCTAssertTrue(levied.contains(Levy(kind: .spear, tier: 3)) && levied.contains(Levy(kind: .bow, tier: 2)), "Their levy raised")
        XCTAssertTrue(frontier.world.units.contains { $0.owner == theirs && $0.kind == .rider && $0.tier == 2 })
        // A returning keeper is not raised twice.
        frontier.depart("id-ilsen", now: 4)
        _ = try frontier.arrive("id-ilsen", name: nil, now: 5)
        XCTAssertEqual(frontier.takeArrivals(), [])

        let report = try XCTUnwrap(frontier.status(now: 6).frontier)
        XCTAssertEqual(report.standings.map(\.realm), ["The Farmere", "The Nullmere"], "Level, by name")
        XCTAssertEqual(report.standings.map(\.keepers), [1, 1])
        XCTAssertNil(frontier.status(now: 6).crossings, "The Frontier lists no crossings of its own")
    }

    func testStrikesAcrossKingdomsScoreAndTheSeasonEndsAfterItsWatches() throws {
        var frontier = frontier()
        frontier.admit([Crossing(keeper: "id-ilsen", name: "Ilsen", realm: "The Nullmere", season: 1, heritage: nil,
                                 levy: [Levy(kind: .spear, tier: 5)])], from: "The Nullmere")
        frontier.admit([Crossing(keeper: "id-orla", name: "Orla", realm: "The Farmere", season: 1, heritage: nil,
                                 levy: [Levy(kind: .bow, tier: 1)])], from: "The Farmere")
        let mine = try XCTUnwrap(try frontier.arrive("id-ilsen", name: nil, now: 1).house)
        let theirs = try XCTUnwrap(try frontier.arrive("id-orla", name: nil, now: 2).house)
        // Their levies meet in the open.
        let spear = try XCTUnwrap(frontier.world.units.last { $0.owner == mine && $0.kind == .spear && $0.tier == 5 })
        let bow = try XCTUnwrap(frontier.world.units.last { $0.owner == theirs && $0.kind == .bow })
        let ground = try XCTUnwrap(frontier.world.map.hexes.first { hex in
            frontier.world.map[hex]?.terrain.isPassable == true && frontier.world.hold(at: hex) == nil
                && frontier.world.unit(at: hex) == nil && hex.neighbors.contains { neighbour in
                    frontier.world.map[neighbour]?.terrain.isPassable == true && frontier.world.hold(at: neighbour) == nil
                        && frontier.world.unit(at: neighbour) == nil
                }
        })
        let beside = try XCTUnwrap(ground.neighbors.first { frontier.world.map[$0]?.terrain.isPassable == true
            && frontier.world.hold(at: $0) == nil && frontier.world.unit(at: $0) == nil })
        frontier.world.units[try XCTUnwrap(frontier.world.unitIndex(spear.id))].position = ground
        frontier.world.units[try XCTUnwrap(frontier.world.unitIndex(bow.id))].position = beside
        let struck = try frontier.perform(.attack(unit: spear.id, target: beside), by: "id-ilsen")
        XCTAssertTrue(struck.contains { if case .battle = $0 { return true } else { return false } })
        let scored = try XCTUnwrap(frontier.frontier?.points[mine])
        XCTAssertGreaterThan(scored, 0, "Troops of another kingdom slain count for the striker's")
        XCTAssertEqual(frontier.frontier?.points[theirs], 0)
        XCTAssertEqual(frontier.status(now: 3).frontier?.standings.first?.realm, "The Nullmere")

        // The season runs its watches, and ends.
        var now = 10.0
        var turns = 0
        while frontier.frontier?.season == 1, turns < FrontierState.lasts + 4 {
            now += 61
            _ = frontier.tick(now: now)
            turns += 1
        }
        XCTAssertEqual(frontier.frontier?.season, 2, "A new season begins")
        XCTAssertGreaterThanOrEqual(turns, FrontierState.lasts - 1)
        XCTAssertTrue(frontier.keepers.isEmpty, "No one seated until they cross again")
        XCTAssertTrue(frontier.frontier?.admitted.isEmpty == true)
        XCTAssertEqual(frontier.frontier?.points, Array(repeating: 0, count: 4))
        let result = try XCTUnwrap(frontier.frontierReport?.last)
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.prevailed, "The Nullmere")
        XCTAssertEqual(Set(result.honours.map(\.keeper)), ["id-ilsen", "id-orla"])
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(result.honours.first { $0.keeper == "id-ilsen" }).points, scored)
        XCTAssertEqual(result.standings.first?.realm, "The Nullmere")
        XCTAssertTrue(frontier.world.chronicle.contains { $0.text.contains("The Frontier's first season ends: The Nullmere prevails.") })
        // Kept as SpacetimeDB keeps it, in parts.
        XCTAssertEqual(try RealmState(parts: frontier.parts(using: JSONEncoder())), frontier)
    }

    func testTheSeasonsEndIsToldHomeOnceItsKeepersHousesGivenTheirDue() throws {
        var home = home()
        let ilsen = try home.arrive("id-ilsen", name: "Ilsen", now: 1)
        let wren = try home.arrive("id-wren", name: "Wren", now: 2)
        let idle = try home.arrive("id-idle", name: "Idle", now: 3)
        home.hearFrontier(news())
        _ = try home.cross("id-ilsen")
        _ = try home.cross("id-wren")
        _ = try home.cross("id-idle")
        let mine = try XCTUnwrap(ilsen.house), hers = try XCTUnwrap(wren.house), theirs = try XCTUnwrap(idle.house)
        let before = home.world.houses.map(\.stock)
        let won = FrontierResult(season: 1, standings: [KingdomStanding(realm: "The Nullmere", points: 40, keepers: 2),
                                                        KingdomStanding(realm: "The Farmere", points: 12, keepers: 1)],
                                 prevailed: "The Nullmere",
                                 honours: [FrontierHonour(keeper: "id-ilsen", realm: "The Nullmere", points: 30),
                                           FrontierHonour(keeper: "id-wren", realm: "The Nullmere", points: 0),
                                           FrontierHonour(keeper: "id-orla", realm: "The Farmere", points: 12)])
        let told = home.hearFrontier(news(season: 2, last: won))
        XCTAssertTrue(told.contains(.frontier(.toldHome(house: mine, season: 1, prevailed: "The Nullmere", points: 30, won: true))))
        XCTAssertTrue(told.contains(.frontier(.toldHome(house: hers, season: 1, prevailed: "The Nullmere", points: 0, won: true))))
        XCTAssertTrue(told.contains { if case .itemsGiven = $0 { return true } else { return false } }, "Its spoils' hourglasses and stones")
        XCTAssertEqual(home.world.houses[mine].stock.grain, min(before[mine].grain + FrontierState.spoils.grain, home.world.storage(of: mine)))
        XCTAssertTrue(home.keeper("id-ilsen")?.titles?.contains("Of the Frontier, Age 1") == true)
        XCTAssertNil(home.keeper("id-ilsen")?.crossing, "Home again")
        XCTAssertNil(home.keeper("id-idle")?.crossing, "One who crossed and never came is home too")
        XCTAssertEqual(home.world.houses[theirs].stock, before[theirs], "Nothing for one who took no part")
        // Told once.
        let stock = home.world.houses.map(\.stock)
        XCTAssertEqual(home.hearFrontier(news(season: 2, last: won)), [])
        XCTAssertEqual(home.world.houses.map(\.stock), stock)
        XCTAssertNotNil(home.world.tidings(of: told[0], for: mine))

        // A kingdom that didn't prevail: a share for those who struck for it.
        var east = self.home("The Farmere", seed: "east")
        let orla = try east.arrive("id-orla", name: "Orla", now: 1)
        east.hearFrontier(news())
        _ = try east.cross("id-orla")
        let held = east.world.houses[try XCTUnwrap(orla.house)].stock
        let heard = east.hearFrontier(news(season: 2, last: won))
        XCTAssertEqual(heard, [.frontier(.toldHome(house: orla.house!, season: 1, prevailed: "The Nullmere", points: 12, won: false))])
        XCTAssertGreaterThan(east.world.houses[orla.house!].stock.grain, held.grain)
        XCTAssertNotNil(east.world.tidings(of: heard[0], for: orla.house!))
        // Kept in parts with what it heard.
        XCTAssertEqual(try RealmState(parts: east.parts(using: JSONEncoder())), east)
    }
}
