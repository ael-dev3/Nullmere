import Foundation
import XCTest
@testable import NullmereCore

/// Drowned ages: as a new age begins, the holds of the age before lie
/// drowned where they stood, named, wherever the new lake has ground a
/// company may reach clear of the new seats; the first to search one finds
/// what its works held, and the map remembers where each stood.
final class DrownedTests: XCTestCase {
    /// An age gone by, its seats grown, and a new age's world of another
    /// lake of the same width.
    private func ages() -> (before: GameState, after: GameState) {
        var before = Scene.world("an age gone by", houses: 6, radius: 18)
        for index in before.holds.indices {
            before.holds[index].levels[.granary] = 3
            before.holds[index].levels[.walls] = 2
        }
        let spire = before.holds.indices.first!
        before.holds[spire].levels[.moonspire] = 2
        let after = Scene.world("an age to come", houses: 6, radius: 18)
        return (before, after)
    }

    func testANewAgeOpensOnTheHoldsOfTheLastDrowned() throws {
        var (before, after) = ages()
        after.drown(before, age: 2)
        let drowned = after.drownedHolds
        XCTAssertFalse(drowned.isEmpty, "Some of the last age's holds lie where this lake has ground")
        XCTAssertLessThanOrEqual(drowned.count, GameState.drownedAtMost)
        for hold in drowned {
            let tile = try XCTUnwrap(after.map[hold.position])
            XCTAssertEqual(tile.feature, .drownedRuin)
            XCTAssertTrue(tile.terrain.isPassable, "Ground a company may reach: \(tile.terrain)")
            XCTAssertTrue(after.holds.allSatisfy { $0.position.distance(to: hold.position) >= GameState.drownedFromSeats }, "Clear of the new seats")
            let old = try XCTUnwrap(before.holds.first { $0.position == hold.position })
            XCTAssertEqual(hold.name, old.name)
            XCTAssertEqual(hold.house, before.houses[old.owner].title)
            XCTAssertEqual(hold.age, 1)
            XCTAssertEqual(hold.works, old.levels.values.reduce(0, +))
        }
        XCTAssertTrue(after.chronicle.contains { $0.kind == .beginning && $0.text.hasPrefix("The water has risen over the first age: \(drowned.count) of its holds") })
        XCTAssertEqual(after.problems(), [])

        // Kept as the world is; a keeper knows of those whose ground they have seen.
        let data = try JSONEncoder().encode(after)
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: data), after)
        let me = after.player
        let view = after.view(for: me)
        XCTAssertEqual(view.drownedHolds, drowned.filter { after.isExplored($0.position, by: me) })
        after.reveal(around: drowned[0].position, range: 0, for: me)
        XCTAssertTrue(after.view(for: me).drownedHolds.contains(drowned[0]))

        // A first age has none; nor a world drowning an age with no holds.
        XCTAssertTrue(Scene.world("a first age", houses: 6, radius: 18).drownedHolds.isEmpty)
        var empty = Scene.world("nothing before", houses: 6, radius: 18)
        var nothing = before
        nothing.holds = []
        empty.drown(nothing, age: 2)
        XCTAssertNil(empty.drowned)
    }

    func testTheFirstToSearchADrownedHoldFindsWhatItsWorksHeld() throws {
        var (before, after) = ages()
        after.drown(before, age: 3)
        let hold = try XCTUnwrap(after.drownedHolds.first)
        XCTAssertEqual(hold.title, "\(hold.name), \(hold.house)'s in the second age")
        XCTAssertEqual(hold.told(searched: false),
                       "Here lies \(hold.name) drowned, \(hold.house)'s hold in the second age: the first company to reach it searches what its works held.")
        XCTAssertEqual(hold.told(searched: true), "Here stood \(hold.name), \(hold.house)'s hold in the second age; its ruin has been searched.")
        let spoils = GameState.spoils(of: hold)
        XCTAssertEqual(spoils.grain, min(hold.works * 10, 200))
        XCTAssertEqual(spoils.moonsalt, min(hold.works * 2, 60) + 20 * hold.spire)
        XCTAssertEqual(GameState.spoils(of: DrownedHold(position: .origin, name: "Spire", house: "House Aurel", age: 1, works: 40, spire: 3)),
                       Stock(grain: 200, timber: 200, stone: 200, moonsalt: 120), "Two hundred at most of each, and the Moonspire's moonsalt")

        // A company of the keeper's walks onto it.
        let me = after.player
        let next = try XCTUnwrap(hold.position.neighbors.first { hex in
            after.map[hex]?.terrain.isPassable == true && after.isClear(hex) && after.wild(at: hex) == nil
        })
        after.units.append(NullmereCore.Unit(id: after.takeID(), kind: .rider, owner: me, position: next))
        let rider = try XCTUnwrap(after.units.last)
        after.reveal(around: hold.position, range: 1, for: me)
        let stock = after.houses[me].stock
        let events = try after.perform(.move(unit: rider.id, to: hold.position), as: me)
        let found = try XCTUnwrap(events.compactMap { event -> Stock? in
            if case .ruinSearched(hold.position, me, let reward) = event { return reward } else { return nil }
        }.first)
        XCTAssertGreaterThanOrEqual(found.grain, spoils.grain, "What its works held, with a ruin's own")
        XCTAssertGreaterThanOrEqual(after.houses[me].stock.moonsalt, min(stock.moonsalt + spoils.moonsalt, after.storage(of: me)))
        XCTAssertNil(after.map[hold.position]?.feature, "Searched")
        XCTAssertEqual(after.drowned(at: hold.position), hold, "Remembered where it stood")
        XCTAssertTrue(after.chronicle.contains { $0.kind == .discovery && $0.text.contains("searches the drowned hold of \(hold.title)") })

        // A hold drowned outside the world is unsound.
        var unsound = after
        unsound.drowned = [DrownedHold(position: Hex(500, 500), name: "Nowhere", house: "House Aurel", age: 1, works: 0, spire: 0)]
        XCTAssertEqual(unsound.problems().filter { $0.hasPrefix("The drowned hold of Nowhere") }.count, 1)
    }

    /// The Moonspire the last age raised stands broken in the next, a holy
    /// site from its first watch whose holders' works cost less and rise
    /// sooner.
    func testTheLastAgesMoonspireStandsBroken() throws {
        var (before, after) = ages()
        let raiser = before.holds[before.holds.indices.first!]
        after.drown(before, age: 2)
        let spire = try XCTUnwrap(after.brokenSpire)
        XCTAssertLessThanOrEqual(spire.position.distance(to: raiser.position), 3)
        XCTAssertEqual(spire.stages, 2)
        XCTAssertEqual(spire.age, 1)
        XCTAssertEqual(spire.house, before.houses[raiser.owner].title)
        XCTAssertEqual(after.map[spire.position]?.terrain.isWater, false)
        XCTAssertTrue(after.holds.allSatisfy { $0.position.distance(to: spire.position) >= GameState.drownedFromSeats })
        XCTAssertTrue(after.chronicle.contains { $0.text == "The Moonspire \(spire.house) raised in the first age stands broken by the new water, "
            + "2 stages high: whoever holds it takes its stones." })

        // A holy site, among those the lake raises.
        let shrine = try XCTUnwrap(after.holySites.first { $0.kind == .brokenSpire })
        XCTAssertEqual(shrine.position, spire.position)
        XCTAssertEqual(Set(after.holySites.map(\.id)).count, after.holySites.count)
        let raised = after.holySites.filter { $0.kind != .brokenSpire }
        XCTAssertEqual(raised.map(\.kind), raised.indices.map { ShrineKind.raised[$0 % ShrineKind.raised.count] }, "The lake's own, as ever")
        XCTAssertEqual(after.problems(), [])
        // Raised with the lake's own, where they are raised later.
        var later = after
        later.shrines = nil
        later.raiseShrines()
        XCTAssertEqual(later.holySites.last?.kind, .brokenSpire)
        XCTAssertEqual(later.holySites.last?.position, spire.position)

        // Held, its stones raise its holders' works for less, and sooner.
        let house = after.player
        let cost = after.buildCost(of: .walls, toLevel: 2, for: house)
        let index = try XCTUnwrap(after.shrines?.firstIndex { $0.kind == .brokenSpire })
        after.shrines![index].holder = house
        XCTAssertEqual(after.shrineBonus(.buildCost, for: house), 15)
        XCTAssertEqual(after.shrineBonus(.buildSpeed, for: house), 15)
        XCTAssertLessThan(after.buildCost(of: .walls, toLevel: 2, for: house).stone, cost.stone)
        XCTAssertEqual(ShrineKind.brokenSpire.title, "Broken Spire")
        let data = try JSONEncoder().encode(after)
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: data), after)

        // An age that raised no Moonspire leaves none.
        var plain = Scene.world("an age to come", houses: 6, radius: 18)
        var unraised = before
        for index in unraised.holds.indices { unraised.holds[index].levels[.moonspire] = nil }
        plain.drown(unraised, age: 2)
        XCTAssertNil(plain.brokenSpire)
        var unsound = after
        unsound.brokenSpire = BrokenSpire(position: Hex(500, 500), house: "House Aurel", age: 1, stages: 1)
        XCTAssertEqual(unsound.problems().filter { $0.hasPrefix("The broken Spire") }.count, 1)
    }

    /// A realm's new age opens on the last one's holds.
    func testARealmsNextAgeIsBuiltOnTheLast() throws {
        var realm = RealmState(name: "R", seed: "ages drowned", seats: 4, radius: 16, watchLength: 60, now: 0)
        _ = try realm.arrive("a", name: "Ama", now: 0)
        for index in realm.world.holds.indices { realm.world.holds[index].levels[.granary] = 4 }
        let before = realm.world
        realm.world.outcome = Outcome(winner: 0, kind: .ascendancy, watch: realm.world.watch)
        _ = realm.tick(now: 1e9)
        XCTAssertEqual(realm.age, 2)
        for hold in realm.world.drownedHolds {
            XCTAssertTrue(before.holds.contains { $0.name == hold.name && $0.position == hold.position })
            XCTAssertEqual(hold.age, 1)
        }
        XCTAssertEqual(realm.world.problems(), [])
    }
}
