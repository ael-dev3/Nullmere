import Foundation
import XCTest
@testable import NullmereCore

/// A House's might, its deeds and its charges in an age; a keeper's
/// renown, titles and deeds across the ages, and nothing more carried.
final class ProgressTests: XCTestCase {
    func testMightRanksTheHouses() throws {
        var state = Scene.world("might", houses: 3)
        let me = state.player
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        state.holds[seat].levels[.granary] = 2
        state.holds[seat].levels[.archive] = 1
        state.houses[me].research.known = [Learned(study: .furrowLore, grade: 2), Learned(study: .drill, grade: 1)]
        let leading = state.commanders(of: me).reduce(0) { $0 + $1.level }
        XCTAssertEqual(state.might(of: me), state.strength(of: me) + 10 * 3 + 8 * 3 + 4 * leading)
        XCTAssertEqual(state.byMight.first, me)
        XCTAssertEqual(Set(state.byMight), Set(state.livingHouses.map(\.id)))
        XCTAssertEqual(state.might(of: 99), 0)
        let theirs = state.view(for: 1)
        XCTAssertEqual(theirs.might(of: me), state.might(of: me), "Known to all, though its learning is not")
        XCTAssertEqual(theirs.houses[me].research.known, [])
        XCTAssertEqual(theirs.byMight, state.byMight)
    }

    func testDeedsAreDoneOnceAndToldAsTheWatchTurns() throws {
        var state = Scene.world("deeds", houses: 3)
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        let veteran = state.put(.spear, tier: 5, of: me, at: try XCTUnwrap(state.freeHex(near: seat.position)))
        state.houses[me].research.known = [Learned(study: .furrowLore, grade: 3), Learned(study: .drill, grade: 3),
                                           Learned(study: .woodcraft, grade: 2), Learned(study: .stonecutting, grade: 2)]
        let hunt = Hunt(attacker: veteran, attackerOwner: me, attackerKind: .spear, wild: 1, wildKind: .barrowkin, level: 8, at: seat.position,
                        damageDealt: 40, damageTaken: 5, attackerFell: false, wildFell: true, spoils: .zero)
        let everything: [GameEvent] = [
            .holdFounded(hold: seat.id), .hunted(hunt), .delivered(unit: veteran, owner: me, hold: seat.id, load: Stock(grain: 20)),
            .studyCompleted(house: me, study: .drill, grade: 3), .unitTrained(unit: veteran, hold: seat.id),
            .buildingCompleted(hold: seat.id, kind: .walls, level: 5), .buildingCompleted(hold: seat.id, kind: .moonspire, level: 1),
            .allianceJoined(alliance: 1, house: me), .rallyStruck(rally: 1, caller: me, target: 2, defender: 1, taken: true),
            .holdCaptured(hold: 2, from: 1, by: me), .happeningEnded(kind: .raising, leaders: [me, 1]),
            .commanderRose(commander: 1, house: me, level: 10),
        ]
        state.noteDeeds(everything)
        XCTAssertEqual(Set(state.deeds(of: me)), Set(Deed.allCases))
        XCTAssertEqual(state.deeds(of: 1), [], "Second in a happening is no deed")
        state.noteDeeds(everything)
        XCTAssertEqual(state.deeds(of: me).count, Deed.allCases.count, "Each once")
        state.noteDeeds([.commanderRose(commander: 2, house: 1, level: 9), .buildingCompleted(hold: seat.id, kind: .walls, level: 4),
                         .rallyStruck(rally: 2, caller: 2, target: 3, defender: 1, taken: false)])
        XCTAssertEqual(state.deeds(of: 1) + state.deeds(of: 2), [])

        let told = state.tellDeeds()
        XCTAssertEqual(told.count, Deed.allCases.count)
        XCTAssertEqual(Set(told.compactMap { event -> Deed? in if case .deedDone(me, let deed) = event { return deed } else { return nil } }), Set(Deed.allCases))
        XCTAssertEqual(state.tellDeeds(), [], "Told once")
        XCTAssertEqual(state.events(told, heardBy: 1), [])
        XCTAssertEqual(state.events(told, heardBy: me), told)
        XCTAssertEqual(state.tidings(of: .deedDone(house: me, deed: .wildbane), for: me),
                       Tidings("A deed of your House, Wildbane: it has struck down a company of the wilds.", .good))
        XCTAssertNil(state.tidings(of: .deedDone(house: me, deed: .wildbane), for: 1))
        XCTAssertEqual(Set(Deed.allCases.map(\.title)).count, Deed.allCases.count)
        XCTAssertEqual(Set(Deed.allCases.map(\.deed)).count, Deed.allCases.count)
    }

    /// A deed done by a keeper's order is noted at once and told as the
    /// watch turns.
    func testADeedDoneByAnOrderIsToldAsTheWatchTurns() throws {
        var state = Scene.world("a founder's deed", houses: 3, radius: 18)
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me)).position
        let spot = try XCTUnwrap(state.map.hexes.first { hex in
            (4...6).contains(hex.distance(to: seat)) && state.isClear(hex) && state.wild(at: hex) == nil && state.canFound(at: hex, for: me) == nil
        })
        let founder = state.put(.founder, of: me, at: spot)
        _ = try state.perform(.found(unit: founder), as: me)
        XCTAssertTrue(state.hasDone(.founder, me))
        XCTAssertTrue(state.endWatch().contains(.deedDone(house: me, deed: .founder)))
        XCTAssertFalse(state.endWatch().contains(.deedDone(house: me, deed: .founder)))
    }

    func testChargesAreSetInTurnAndRewarded() throws {
        var state = Scene.world("charges", houses: 3)
        let me = state.player
        XCTAssertEqual(state.charge(of: me), .raiseGranary)
        XCTAssertEqual(state.fulfilCharges(), [])
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        state.holds[seat].levels[.granary] = 1
        state.houses[me].stock = .zero
        let first = state.fulfilCharges()
        XCTAssertEqual(first, [.chargeDone(house: me, charge: .raiseGranary, reward: Charge.raiseGranary.reward),
                               .itemsGiven(house: me, kind: .hourglass, count: 1)])
        XCTAssertEqual(state.houses[me].stock, Charge.raiseGranary.reward)
        XCTAssertEqual(state.satchel(of: me), [ItemStack(house: me, kind: .hourglass, count: 1)])
        XCTAssertEqual(state.charge(of: me), .musterCompany)
        XCTAssertEqual(state.charge(of: 1), .raiseGranary)
        XCTAssertEqual(state.tidings(of: first[0], for: me)?.text,
                       "Charge done: raise a Granary at your seat, and \(Charge.raiseGranary.reward) given. Next: muster a second company of war.")
        XCTAssertNil(state.tidings(of: first[0], for: 1))
        XCTAssertEqual(state.events(first, heardBy: 1), [])

        // Several done at once are rewarded in turn.
        state.put(.spear, of: me, at: try XCTUnwrap(state.freeHex(near: state.holds[seat].position, within: 1...2)))
        state.holds[seat].levels[.archive] = 1
        state.houses[me].research.known = [Learned(study: .furrowLore, grade: 1)]
        XCTAssertEqual(state.fulfilCharges().compactMap { event -> Charge? in if case .chargeDone(_, let charge, _) = event { return charge } else { return nil } },
                       [.musterCompany, .raiseArchive, .learnStudy])
        XCTAssertEqual(state.items(.hourglass, of: me), 4, "One, one more, and two for the Archive")
        XCTAssertEqual(state.items(.grainCache, of: me), 1)
        XCTAssertEqual(state.charge(of: me), .foundHold)

        // The last two: a Muster Hall to III, and a company drilled there.
        state.chargesDone![me] = Charge.allCases.count - 2
        state.holds[seat].levels[.musterHall] = 3
        XCTAssertEqual(state.fulfilCharges(), [.chargeDone(house: me, charge: .raiseMusterHall, reward: Charge.raiseMusterHall.reward),
                                               .itemsGiven(house: me, kind: .hourglass, count: 2), .itemsGiven(house: me, kind: .moonsaltCache, count: 1)])
        XCTAssertEqual(state.charge(of: me), .drillCompany)
        XCTAssertEqual(state.tidings(of: .chargeDone(house: me, charge: .raiseMusterHall, reward: Charge.raiseMusterHall.reward), for: me)?.text,
                       "Charge done: raise a Muster Hall to III, and \(Charge.raiseMusterHall.reward) given. Next: drill a company to twice its first muster.")
        let company = try XCTUnwrap(state.units.firstIndex { $0.owner == me && $0.kind.hasTiers })
        state.units[company].drilled = state.firstMuster(of: state.units[company]) - 1
        XCTAssertEqual(state.fulfilCharges(), [], "Not quite twice")
        state.units[company].drilled = state.firstMuster(of: state.units[company])
        XCTAssertEqual(state.fulfilCharges(), [.chargeDone(house: me, charge: .drillCompany, reward: Charge.drillCompany.reward),
                                               .itemsGiven(house: me, kind: .mendingDraught, count: 1)])
        // All done: none left to set.
        XCTAssertNil(state.charge(of: me))
        XCTAssertEqual(state.fulfilCharges(), [])
        XCTAssertEqual(state.tidings(of: .chargeDone(house: me, charge: .drillCompany, reward: Charge.drillCompany.reward), for: me)?.text,
                       "Charge done: drill a company to twice its first muster, and \(Charge.drillCompany.reward) given.")
        XCTAssertEqual(Set(Charge.allCases.map(\.title)).count, Charge.allCases.count)

        // Each charge as its House does it.
        var fresh = Scene.world("each charge", houses: 3)
        let home = try XCTUnwrap(fresh.seat(of: me))
        func met(_ charge: Charge) -> Bool { charge.isMet(by: me, in: fresh) }
        XCTAssertFalse(met(.foundHold))
        fresh.holds.append(Hold(id: fresh.takeID(), name: "Newhold", owner: me, position: try XCTUnwrap(fresh.freeHex(near: home.position, within: 5...6)),
                                isSeat: false, foundedWatch: fresh.watch))
        XCTAssertTrue(met(.foundHold))
        XCTAssertFalse(met(.leadCompany))
        let spear = try XCTUnwrap(fresh.units(of: me).first { $0.kind == .spear })
        let commander = try XCTUnwrap(fresh.commanders(of: me).first)
        _ = try fresh.perform(.assign(commander: commander.id, unit: spear.id), as: me)
        XCTAssertTrue(met(.leadCompany))
        XCTAssertFalse(met(.gatherSite) || met(.huntWild) || met(.swearBanner))
        fresh.noteDeeds([.delivered(unit: spear.id, owner: me, hold: home.id, load: Stock(grain: 20))])
        XCTAssertTrue(met(.gatherSite))
        fresh.noteDeeds([.hunted(Hunt(attacker: spear.id, attackerOwner: me, attackerKind: .spear, wild: 1, wildKind: .reavers, level: 1, at: home.position,
                                      damageDealt: 40, damageTaken: 5, attackerFell: false, wildFell: true, spoils: .zero))])
        XCTAssertTrue(met(.huntWild))
        _ = try fresh.perform(.foundAlliance(name: "First Oath"), as: me)
        XCTAssertTrue(met(.swearBanner))
        XCTAssertFalse(met(.raiseMusterHall))
        XCTAssertFalse(met(.drillCompany))

        // A fallen House is set none.
        fresh.houses[1].isEliminated = true
        fresh.holds[try XCTUnwrap(fresh.holds.firstIndex { $0.owner == 1 && $0.isSeat })].levels[.granary] = 1
        XCTAssertFalse(fresh.fulfilCharges().contains { if case .chargeDone(1, _, _) = $0 { return true } else { return false } })
    }

    func testDeedsAndChargesAreSoundAndKeptInSaves() throws {
        var state = Scene.world("kept progress", houses: 3)
        let me = state.player
        state.noteDeeds([.allianceFounded(alliance: 1, house: me)])
        state.holds[try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })].levels[.granary] = 1
        _ = state.fulfilCharges()
        XCTAssertEqual(state.problems(), [])
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state)
        let old = try JSONDecoder().decode(GameState.self, from: Scene.without(["deedsDone", "chargesDone"], in: state))
        XCTAssertNil(old.deedsDone)
        XCTAssertNil(old.chargesDone)
        XCTAssertEqual(old.charge(of: me), .raiseGranary, "A save from before charges sets every House its first")

        func caught(_ text: String, _ change: (inout GameState) -> Void) {
            var broken = state
            change(&broken)
            XCTAssertTrue(broken.problems().contains { $0.contains(text) }, "\(text): \(broken.problems())")
        }
        caught("twice") { $0.deedsDone!.append($0.deedsDone![0]) }
        caught("of no House") { $0.deedsDone!.append(DeedDone(house: 42, deed: .sworn, watch: 1, told: true)) }
        caught("charges") { $0.chargesDone![0] = Charge.allCases.count + 1 }
        caught("counted for") { $0.chargesDone! += [0, 0] }
    }

    /// The ambitious weigh all a House is, not its arms alone.
    func testTheAmbitiousWeighMight() throws {
        var state = Scene.world("ambition", houses: 6, radius: 22)
        _ = try state.perform(.foundAlliance(name: "Proud Banner"), as: 1)
        let alliance = try XCTUnwrap(state.alliance(of: 1))
        state.houses[1].temperament = .ambitious
        state.houses[2].research.known = [Learned(study: .furrowLore, grade: 3), Learned(study: .drill, grade: 3)]
        XCTAssertGreaterThan(state.might(of: 2), state.might(of: 1))
        XCTAssertFalse(RivalMind(house: 1).acceptsMember(2, to: alliance, in: state), "No House mightier than itself")
        state.holds[try XCTUnwrap(state.holds.firstIndex { $0.owner == 1 && $0.isSeat })].levels[.granary] = 5
        XCTAssertTrue(RivalMind(house: 1).acceptsMember(2, to: alliance, in: state))
    }

    func testAKeeperIsRememberedAcrossTheAges() throws {
        var realm = RealmState(name: "R", seed: "renown", seats: 4, radius: 18, watchLength: 60, now: 0)
        let ama = try XCTUnwrap(try realm.arrive("a", name: "Ama", now: 0).house)
        let bel = try XCTUnwrap(try realm.arrive("b", name: "Bel", now: 0).house)
        realm.world.noteDeeds([.allianceFounded(alliance: 1, house: ama), .holdCaptured(hold: 1, from: bel, by: ama)])
        realm.world.houses[bel].isEliminated = true
        realm.world.outcome = Outcome(winner: ama, kind: .ascendancy, watch: realm.world.watch)
        _ = realm.tick(now: 1e9)
        XCTAssertEqual(realm.age, 2)
        let a = try XCTUnwrap(realm.keeper("a"))
        XCTAssertEqual(a.renown, 5 * 2 + 10 + 50)
        XCTAssertEqual(a.titles, ["Raiser of the Moonspire, Age 1"])
        XCTAssertEqual(a.deeds, [.sworn, .conqueror])
        let b = try XCTUnwrap(realm.keeper("b"))
        XCTAssertEqual(b.renown, 0)
        XCTAssertNil(b.titles)
        XCTAssertNil(b.deeds)
        XCTAssertEqual(realm.view(for: "a")?.keeper.renown, 70, "Their own record, in their view")

        // Nothing of it goes into the new age's world.
        let house = try XCTUnwrap(a.house)
        let other = try XCTUnwrap(realm.world.houses.first { $0.id != house })
        XCTAssertEqual(realm.world.houses[house].stock, other.stock)
        XCTAssertEqual(realm.world.deeds(of: house), [])
        XCTAssertEqual(realm.world.charge(of: house), .raiseGranary)

        // A second age adds to the first.
        realm.world.noteDeeds([.allianceFounded(alliance: 1, house: house), .holdFounded(hold: try XCTUnwrap(realm.world.seat(of: house)).id)])
        realm.world.outcome = Outcome(winner: (house + 1) % realm.world.houses.count, kind: .dominion, watch: realm.world.watch)
        _ = realm.tick(now: 2e9)
        let again = try XCTUnwrap(realm.keeper("a"))
        XCTAssertEqual(again.renown, 70 + 5 * 2 + 10)
        XCTAssertEqual(again.deeds, [.founder, .sworn, .conqueror])
        XCTAssertEqual(again.titles, ["Raiser of the Moonspire, Age 1"])

        // A keeper's record from before renown has none.
        let older = try JSONDecoder().decode(Keeper.self, from: Scene.without(["renown", "titles", "deeds"], in: again))
        XCTAssertNil(older.renown)
        XCTAssertNil(older.titles)
        XCTAssertEqual(try JSONDecoder().decode(RealmState.self, from: JSONEncoder().encode(realm)), realm)
    }
}
