import Foundation
import XCTest
@testable import NullmereCore

/// Drill: a company of war standing at or beside one of its House's holds
/// with a Muster Hall takes on troops there as each watch turns, as many as
/// the hall drills, up to as many as it can lead, paid for in grain and
/// never more than its House's grain can feed; and every troop counts, in
/// battle, in its hunger and in its House's strength.
final class DrillTests: XCTestCase {
    /// A keeper's House with its seat's Muster Hall at a level, stores to
    /// spend, its own companies cleared, and a Spear of a tier in the seat.
    private func drillYard(_ seed: String, hall: Int = 2, tier: Int = 1) throws -> (state: GameState, me: Int, spear: Int, seat: Hold) {
        var state = Scene.world(seed, houses: 4, radius: 18)
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        state.holds[index].levels[.musterHall] = hall
        state.units.removeAll { $0.owner == me }
        state.richen(me)
        let spear = state.put(.spear, tier: tier, of: me, at: seat.position)
        return (state, me, spear, state.holds[index])
    }

    private func drilled(_ events: [GameEvent]) -> [(unit: Int, troops: Int, whole: Bool)] {
        events.compactMap { event in
            if case .drilled(let unit, _, let troops, let whole) = event { return (unit, troops, whole) }
            return nil
        }
    }

    func testACompanyDrillsAtItsHallAsTheWatchTurns() throws {
        var (state, me, spear, seat) = try drillYard("drilled at the hall")
        let before = state.houses[me].stock
        XCTAssertNil(state.drillRefusal(of: try XCTUnwrap(state.unit(spear))))
        XCTAssertEqual(try state.perform(.drill(unit: spear), as: me), [], "Told as the watch turns")
        let ordered = try XCTUnwrap(state.unit(spear))
        XCTAssertEqual(ordered.drillAt, seat.position)
        XCTAssertTrue(state.isDrilling(ordered))
        XCTAssertEqual(state.drillCapacity(of: ordered), 10_800, "Once, and four times more for each of the hall's two levels")
        XCTAssertEqual(state.drillRate(of: ordered, hall: 2), 1_200, "Half its first muster for each level")

        let events = state.drillCompanies(territory: state.territory())
        XCTAssertEqual(drilled(events).map(\.troops), [1_200])
        XCTAssertEqual(drilled(events).map(\.whole), [false])
        let grown = try XCTUnwrap(state.unit(spear))
        XCTAssertEqual(grown.drilled, 1_200)
        XCTAssertEqual(state.fullMuster(of: grown), 2_400)
        XCTAssertEqual(state.troops(of: grown), 2_400, "The drilled stand whole")
        XCTAssertEqual(grown.health, 100)
        XCTAssertEqual(state.musterPercent(of: grown), 200)
        XCTAssertEqual(before.grain - state.houses[me].stock.grain, 12, "Twelve grain a first muster's worth")
        XCTAssertEqual(before.moonsalt, state.houses[me].stock.moonsalt, "Grain alone")
        XCTAssertEqual(state.drillCost(of: grown, troops: 500), Stock(grain: 5), "Rounded up")

        // Watch after watch, until it musters as many as it may lead.
        var watches = 1
        while state.unit(spear)?.drillAt != nil, watches < 20 {
            watches += 1
            for (unit, _, whole) in drilled(state.drillCompanies(territory: state.territory())) where unit == spear && whole {
                XCTAssertEqual(state.fullMuster(of: try XCTUnwrap(state.unit(spear))), 10_800)
            }
        }
        XCTAssertEqual(watches, 8, "Nine thousand six hundred, twelve hundred a watch")
        let whole = try XCTUnwrap(state.unit(spear))
        XCTAssertNil(whole.drillAt, "Drilled whole, it drills no more")
        XCTAssertFalse(state.isDrilling(whole))
        XCTAssertEqual(state.drillRefusal(of: whole), .drilledWhole)
        XCTAssertEqual(state.army(of: me), 10_800)
        // Told once it is drilled whole; not before, nor to another House.
        let told = GameEvent.drilled(unit: spear, owner: me, troops: 1_200, whole: true)
        XCTAssertEqual(state.tidings(of: told, for: me), Tidings("Your Spears at \(seat.name) are drilled whole: 10,800 troops.", .good))
        XCTAssertNil(state.tidings(of: .drilled(unit: spear, owner: me, troops: 1_200, whole: false), for: me))
        XCTAssertNil(state.tidings(of: told, for: (me + 1) % state.houses.count))
        XCTAssertEqual(state.upkeep(of: whole), 3, "A quarter as much again for each first muster drilled")
        XCTAssertThrowsError(try state.perform(.drill(unit: spear), as: me)) { error in
            XCTAssertEqual(error as? RuleError, .drilledWhole)
        }
    }

    func testTheWatchItselfDrillsAndTellsTheHouseAlone() throws {
        var (state, me, spear, _) = try drillYard("drilled through the watch")
        _ = try state.perform(.drill(unit: spear), as: me)
        let events = state.endWatch()
        XCTAssertEqual(drilled(events).filter { $0.unit == spear }.map(\.troops), [1_200], "As the watch turns")
        XCTAssertEqual(state.unit(spear)?.drilled, 1_200)
        let foe = (me + 1) % state.houses.count
        XCTAssertEqual(drilled(state.events(events, heardBy: me)).filter { $0.unit == spear }.count, 1, "Its own House hears of it")
        XCTAssertTrue(drilled(state.events(events, heardBy: foe)).filter { $0.unit == spear }.isEmpty, "No other does")
        // Another House that sees the company sees how many it is, not that it drills.
        let index = try XCTUnwrap(state.unitIndex(spear))
        state.units[index].drillAt = state.units[index].position
        let seenByFoe = state.view(for: foe).unit(spear)
        if let seen = seenByFoe {
            XCTAssertNil(seen.drillAt)
            XCTAssertEqual(seen.drilled, 1_200)
        }
        XCTAssertEqual(state.view(for: me).unit(spear)?.drillAt, state.units[index].position)
    }

    func testOnlyACompanyOfWarInItsOwnHoldWithAHallDrills() throws {
        var (state, me, spear, seat) = try drillYard("drill refused")
        let out = try XCTUnwrap(state.freeHex(near: seat.position, within: 2...3))
        let afield = state.put(.spear, of: me, at: out)
        XCTAssertThrowsError(try state.perform(.drill(unit: afield), as: me)) { error in
            XCTAssertEqual(error as? RuleError, .drillsAtMusterHall, "Out in the field")
        }
        XCTAssertEqual(RuleError.drillsAtMusterHall.description, "A company of war drills at or beside one of your holds with a Muster Hall.")
        // Beside the hold, as at it: as many as stand round it.
        let beside = state.put(.bow, of: me, at: try XCTUnwrap(state.freeHex(near: seat.position, within: 1...1)))
        XCTAssertEqual(state.drillHold(for: try XCTUnwrap(state.unit(beside)))?.id, seat.id)
        _ = try state.perform(.drill(unit: beside), as: me)
        _ = try state.perform(.drill(unit: spear), as: me)
        XCTAssertEqual(Set(drilled(state.drillCompanies(territory: state.territory())).map(\.unit)), [spear, beside])
        state.units.removeAll { $0.id == beside }
        XCTAssertTrue(RuleError.drilledWhole.description.hasPrefix("That company musters as many as it can lead"))
        let foe = (me + 1) % state.houses.count
        XCTAssertThrowsError(try state.perform(.drill(unit: spear), as: foe)) { error in
            XCTAssertEqual(error as? RuleError, .notYours)
        }
        // Lanterns and Founders drill nothing.
        state.units.removeAll { $0.id == spear }
        let lantern = state.put(.lantern, of: me, at: seat.position)
        XCTAssertEqual(state.drillRefusal(of: try XCTUnwrap(state.unit(lantern))), .drillsAtMusterHall)
        // A hold with no Muster Hall, and another House's hold.
        state.units.removeAll { $0.id == lantern }
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        state.holds[index].levels[.musterHall] = nil
        let bare = state.put(.spear, of: me, at: seat.position)
        XCTAssertEqual(state.drillRefusal(of: try XCTUnwrap(state.unit(bare))), .drillsAtMusterHall)
        let theirs = try XCTUnwrap(state.seat(of: foe))
        let theirIndex = try XCTUnwrap(state.holdIndex(theirs.id))
        state.holds[theirIndex].levels[.musterHall] = 3
        state.units.removeAll { $0.position == theirs.position }
        let visitor = state.put(.spear, of: me, at: theirs.position)
        XCTAssertEqual(state.drillRefusal(of: try XCTUnwrap(state.unit(visitor))), .drillsAtMusterHall)
    }

    func testDrillingWaitsOutAWatchItActedAndEndsWhenItLeaves() throws {
        var (state, me, spear, seat) = try drillYard("drill kept and left")
        _ = try state.perform(.drill(unit: spear), as: me)
        let index = try XCTUnwrap(state.unitIndex(spear))
        state.units[index].acted = true
        XCTAssertTrue(drilled(state.drillCompanies(territory: state.territory())).isEmpty, "Not in a watch it fought or marched")
        XCTAssertEqual(state.unit(spear)?.drillAt, seat.position, "Still drilling")
        state.units[index].acted = false
        state.units[index].position = try XCTUnwrap(state.freeHex(near: seat.position, within: 1...1))
        XCTAssertFalse(state.isDrilling(try XCTUnwrap(state.unit(spear))))
        XCTAssertTrue(drilled(state.drillCompanies(territory: state.territory())).isEmpty)
        XCTAssertNil(state.unit(spear)?.drillAt, "Gone from the hall, it drills no more")
        // Back, it drills again only when ordered to.
        state.units[index].position = seat.position
        XCTAssertTrue(drilled(state.drillCompanies(territory: state.territory())).isEmpty)
        // An order to drill lets a march go.
        state.units[index].destination = try XCTUnwrap(state.freeHex(near: seat.position, within: 4...5))
        _ = try state.perform(.drill(unit: spear), as: me)
        XCTAssertNil(state.unit(spear)?.destination)
    }

    func testAHallDrillsOnlyWhatTheHouseCanPayForAndFeed() throws {
        var (state, me, spear, seat) = try drillYard("drill paid and fed")
        _ = try state.perform(.drill(unit: spear), as: me)
        // Short of grain: nothing.
        state.houses[me].stock.grain = 0
        XCTAssertTrue(drilled(state.drillCompanies(territory: state.territory())).isEmpty)
        XCTAssertEqual(state.unit(spear)?.drillAt, seat.position, "It waits for the stores")
        // Five grain buys five hundred.
        state.houses[me].stock.grain = 5
        let unit = try XCTUnwrap(state.unit(spear))
        XCTAssertEqual(state.troopsAffordable(for: unit, with: state.houses[me].stock), 500)
        XCTAssertEqual(drilled(state.drillCompanies(territory: state.territory())).map(\.troops), [500])
        XCTAssertEqual(state.houses[me].stock.grain, 0)
        // A House eating all its grain grows drills nothing more.
        state.richen(me)
        let owners = state.territory()
        let spare = state.income(of: me, territory: owners).grain - state.upkeep(of: me)
        for step in 0...spare {
            let hungry = try XCTUnwrap(state.freeHex(near: seat.position, within: 2...(4 + step / 8)))
            state.put(.spear, of: me, at: hungry)
        }
        XCTAssertLessThan(state.income(of: me, territory: owners).grain - state.upkeep(of: me), 0)
        XCTAssertTrue(drilled(state.drillCompanies(territory: owners)).isEmpty, "No troops it can't feed")
    }

    func testAHigherHallAndACommanderLeadMore() throws {
        var (state, me, spear, seat) = try drillYard("drill led", hall: 1, tier: 5)
        let unit = try XCTUnwrap(state.unit(spear))
        XCTAssertEqual(state.drillTimes(of: unit), 5)
        XCTAssertEqual(state.drillCapacity(of: unit), 12_000)
        XCTAssertEqual(state.drillCost(of: unit, troops: 2_400), Stock(grain: 60), "Dearer by tier, as mustering is")
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        state.holds[index].levels[.musterHall] = 5
        XCTAssertEqual(state.drillTimes(of: unit), 21, "The House's best hall")
        let commander = try XCTUnwrap(state.commanders(of: me).first)
        _ = try state.perform(.assign(commander: commander.id, unit: spear), as: me)
        let led = try XCTUnwrap(state.unit(spear))
        XCTAssertEqual(state.drillTimes(of: led), 21 + commander.level / 3)
        let commanderIndex = try XCTUnwrap(state.commanders?.firstIndex { $0.id == commander.id })
        state.commanders![commanderIndex].experience = Commander.experience(forLevel: 20)
        XCTAssertEqual(state.drillTimes(of: led), 27, "Once more for every three of its levels")
        XCTAssertEqual(state.drillCapacity(of: led), 64_800)
    }

    func testEveryTroopCountsInBattle() throws {
        func duel(drilled: Int) throws -> (dealt: Int, strengths: (attack: Int, defense: Int)) {
            var state = Scene.world("drilled in battle", houses: 4, radius: 18)
            let me = state.player, foe = (me + 1) % state.houses.count
            let seat = try XCTUnwrap(state.seat(of: me))
            let at = try XCTUnwrap(state.freeHex(near: seat.position, within: 2...3))
            let beside = try XCTUnwrap(state.freeHex(near: at, within: 1...1))
            let spear = state.put(.spear, of: me, at: at)
            let theirs = state.put(.spear, of: foe, at: beside)
            state.units[try XCTUnwrap(state.unitIndex(spear))].drilled = drilled
            _ = try state.declareWar(by: me, on: foe)
            let strengths = state.strengths(of: try XCTUnwrap(state.unit(spear)), against: try XCTUnwrap(state.unit(theirs)), at: beside)
            let events = try state.perform(.attack(unit: spear, target: beside), as: me)
            let battle = try XCTUnwrap(events.compactMap { event -> Battle? in
                if case .battle(let battle) = event { return battle }
                return nil
            }.first)
            return (battle.damageDealt, strengths)
        }
        let plain = try duel(drilled: 0), thrice = try duel(drilled: 9_600)
        XCTAssertEqual(thrice.strengths.attack, plain.strengths.attack * 3, "Nine times its first muster, three times the blow")
        XCTAssertEqual(thrice.strengths.defense, plain.strengths.defense, "Against a foe as it was")
        XCTAssertGreaterThan(thrice.dealt, plain.dealt, "The greater company strikes the harder")

        // Two companies drilled alike fight as two undrilled do.
        var state = Scene.world("drilled alike", houses: 4, radius: 18)
        let me = state.player, foe = (me + 1) % state.houses.count
        var mine = Unit(id: 1, kind: .spear, owner: me, position: Hex(0, 0)), theirs = Unit(id: 2, kind: .bow, owner: foe, position: Hex(1, 0))
        let undrilled = state.strengths(of: mine, against: theirs, at: theirs.position)
        mine.drilled = 9_600
        theirs.drilled = 8_000
        let alike = state.strengths(of: mine, against: theirs, at: theirs.position)
        XCTAssertEqual(Double(alike.attack) / Double(alike.defense), Double(undrilled.attack) / Double(undrilled.defense), accuracy: 0.02)
        XCTAssertEqual(state.strength(of: mine), state.strength(of: Unit(id: 3, kind: .spear, owner: me, position: Hex(0, 0))) * 3,
                       "Its weight in its House's strength")
        var four = Unit(id: 4, kind: .bow, owner: me, position: Hex(0, 0))
        four.drilled = 3_000
        XCTAssertEqual(state.musterMight(of: four), 200, "Four times its first muster, twice as hard")
        state.units = [mine]
        XCTAssertEqual(state.army(of: me), 10_800, "Every troop counted")
    }

    func testDrilledTroopsAreKeptAndAWorldFromBeforeDrillReadsAsUndrilled() throws {
        var unit = Unit(id: 7, kind: .rider, owner: 1, position: Hex(2, -1), tier: 3)
        unit.drilled = 1_200
        unit.drillAt = Hex(2, -1)
        let kept = try JSONDecoder().decode(Unit.self, from: JSONEncoder().encode(unit))
        XCTAssertEqual(kept, unit)
        let old = try JSONDecoder().decode(Unit.self, from: Scene.without(["drilled", "drillAt"], in: unit))
        XCTAssertNil(old.drilled)
        XCTAssertNil(old.drillAt)
        let plain = Unit(id: 8, kind: .spear, owner: 1, position: Hex(0, 0))
        let text = String(decoding: try JSONEncoder().encode(plain), as: UTF8.self)
        XCTAssertFalse(text.contains("drill"), "An undrilled company keeps no more than it did")
    }

    func testStewardsDrillTheirCompaniesInTheirHolds() throws {
        var state = Scene.world("stewards drill", houses: 4, radius: 18)
        state.play(40)
        let drilledCompanies = state.units.filter { ($0.drilled ?? 0) > 0 }
        XCTAssertFalse(drilledCompanies.isEmpty, "The stewards drill")
        XCTAssertTrue(state.houses.allSatisfy { $0.isEliminated || $0.stock.grain >= 0 })
        for unit in drilledCompanies {
            XCTAssertLessThanOrEqual(state.fullMuster(of: unit), state.drillCapacity(of: unit) + state.firstMuster(of: unit) * 2,
                                     "Never far past what it may lead, though a hall may be lost after")
        }
    }
}
