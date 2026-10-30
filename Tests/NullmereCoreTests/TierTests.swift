import Foundation
import XCTest
@testable import NullmereCore

/// Companies of war muster in tiers I to V: each stronger, hardier, dearer,
/// hungrier and slower to train than the last, and each needing a Muster
/// Hall as high as itself and the study that opens it. Lanterns and
/// Founders muster in one.
final class TierTests: XCTestCase {
    /// A keeper's House that has studied every tier: here only its hall
    /// stands between it and a tier.
    private func world() throws -> (GameState, seat: Hold) {
        var state = Scene.world("tiers")
        state.richen(state.player)
        for study in [Study.drill, .ironRanks, .greyCompanies, .moonsteel] {
            state.houses[state.player].research.learn(study, grade: 1)
        }
        let seat = try XCTUnwrap(state.seat(of: state.player))
        return (state, seat)
    }

    private func refusal(_ command: Command, in state: GameState, as house: Int) -> RuleError? {
        var trial = state
        do {
            try trial.perform(command, as: house)
            return nil
        } catch {
            return error
        }
    }

    func testOnlyCompaniesOfWarMusterInTiers() throws {
        var (state, seat) = try world()
        let me = state.player
        state.holds[try XCTUnwrap(state.holdIndex(seat.id))].levels[.musterHall] = 5
        XCTAssertEqual(refusal(.train(hold: seat.id, kind: .lantern, tier: 2), in: state, as: me), .oneTierOnly(.lantern))
        XCTAssertEqual(refusal(.train(hold: seat.id, kind: .founder, tier: 5), in: state, as: me), .oneTierOnly(.founder))
        XCTAssertEqual(refusal(.train(hold: seat.id, kind: .spear, tier: 6), in: state, as: me), .noSuchTier)
        XCTAssertEqual(refusal(.train(hold: seat.id, kind: .spear, tier: 0), in: state, as: me), .noSuchTier)
        XCTAssertNil(refusal(.train(hold: seat.id, kind: .lantern, tier: 1), in: state, as: me))
        XCTAssertEqual(UnitKind.lantern.highestTier, 1)
        XCTAssertEqual(UnitKind.rider.highestTier, 5)
        XCTAssertEqual(RuleError.oneTierOnly(.lantern).description, "Lanterns muster in one tier only.")
        XCTAssertEqual(RuleError.noSuchTier.description, "Companies muster in tiers I to V.")
    }

    func testATierNeedsAMusterHallAsHighAsItself() throws {
        var (state, seat) = try world()
        let me = state.player
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        state.holds[index].levels[.musterHall] = 2
        XCTAssertEqual(refusal(.train(hold: seat.id, kind: .spear, tier: 3), in: state, as: me), .needsMusterHall(3))
        XCTAssertEqual(refusal(.train(hold: seat.id, kind: .rider, tier: 1), in: state, as: me), .needsMusterHall(3))
        XCTAssertEqual(state.highestTier(of: .spear, at: state.holds[index], for: me), 2)
        XCTAssertEqual(state.highestTier(of: .lantern, at: state.holds[index], for: me), 1)
        state.holds[index].levels[.musterHall] = 3
        XCTAssertEqual(state.highestTier(of: .rider, at: state.holds[index], for: me), 3)
        XCTAssertEqual(UnitKind.rider.requiredMuster(tier: 2), 3, "A rider's own hall first")
        XCTAssertEqual(UnitKind.spear.requiredMuster(tier: 4), 4)
        XCTAssertEqual(BuildingKind.musterHall.maxLevel, 5, "Raised to the fifth tier's")

        let before = state.houses[me].stock
        let events = try state.perform(.train(hold: seat.id, kind: .spear, tier: 3), as: me)
        XCTAssertEqual(events, [.trainingStarted(hold: seat.id, kind: .spear)])
        XCTAssertEqual(state.houses[me].stock.shortfall(for: before), UnitKind.spear.cost(tier: 3), "Paid at its tier")
        let training = try XCTUnwrap(state.holds[index].training)
        XCTAssertEqual(training.musteredTier, 3)
        XCTAssertEqual(training.watchesLeft, UnitKind.spear.trainWatches(tier: 3) - 1, "A third hall musters a watch sooner")
        let count = state.units(of: me).count
        for _ in 0..<training.watchesLeft { _ = state.endWatch() }
        XCTAssertEqual(state.units(of: me).count, count + 1)
        let mustered = try XCTUnwrap(state.units(of: me).max { $0.id < $1.id })
        XCTAssertEqual(mustered.tier, 3, "It musters at its tier")
        XCTAssertEqual(mustered.kind, .spear)
    }

    func testEachTierIsStrongerHardierDearerHungrierAndSlower() throws {
        let (state, _) = try world()
        for kind in [UnitKind.spear, .bow, .rider] {
            for tier in 2...5 {
                let lower = Unit(id: 1, kind: kind, owner: 0, position: .origin, tier: tier - 1)
                let higher = Unit(id: 2, kind: kind, owner: 0, position: .origin, tier: tier)
                XCTAssertGreaterThan(state.attackPercent(of: higher), state.attackPercent(of: lower))
                XCTAssertGreaterThan(state.defensePercent(of: higher), state.defensePercent(of: lower))
                XCTAssertGreaterThan(state.bodyPercent(of: higher), state.bodyPercent(of: lower))
                XCTAssertGreaterThan(state.strength(of: higher), state.strength(of: lower))
                XCTAssertGreaterThan(kind.cost(tier: tier).grain, kind.cost(tier: tier - 1).grain)
                XCTAssertGreaterThanOrEqual(kind.upkeep(tier: tier), kind.upkeep(tier: tier - 1))
                XCTAssertGreaterThanOrEqual(kind.trainWatches(tier: tier), kind.trainWatches(tier: tier - 1))
                XCTAssertGreaterThanOrEqual(kind.attack(tier: tier), kind.attack(tier: tier - 1))
            }
            XCTAssertGreaterThan(kind.upkeep(tier: 5), kind.upkeep(tier: 1))
            XCTAssertGreaterThan(kind.trainWatches(tier: 5), kind.trainWatches(tier: 1))
            XCTAssertGreaterThan(kind.cost(tier: 3).moonsalt, kind.cost(tier: 2).moonsalt, "Moonsalt from the third")
            XCTAssertEqual(kind.cost(tier: 1), kind.cost)
            XCTAssertEqual(kind.attack(tier: 1), kind.attack)
            XCTAssertEqual(kind.defense(tier: 1), kind.defense)
        }
        XCTAssertEqual(UnitKind.lantern.upkeep(tier: 4), 0, "A lantern eats nothing at any tier")
        XCTAssertEqual(UnitKind.founder.cost(tier: 3), UnitKind.founder.cost, "A founder has but one")
    }

    /// The first tier fights, eats and weighs as every company did before
    /// tiers: nothing of an older game changes. (Its House's heritage is one
    /// that changes no company's figures.)
    func testTheFirstTierIsWhatEveryCompanyWas() throws {
        var (state, _) = try world()
        state.houses[0].heritage = .strandfolk
        for kind in UnitKind.allCases {
            var unit = Unit(id: 1, kind: kind, owner: 0, position: .origin)
            unit.health = 73
            XCTAssertEqual(state.strength(of: unit), (kind.attack + kind.defense) * 73 / 10)
            XCTAssertEqual(state.upkeep(of: unit), kind.upkeep)
            XCTAssertEqual(state.wardDamage(by: unit), Hold.strikeDamage(attack: kind.attack, health: 73))
            XCTAssertEqual(state.movement(of: unit), kind.movement)
        }
    }

    /// A blow lands inside its forecast whatever the tiers on either side,
    /// and a higher tier takes less of a like blow.
    func testBlowsBetweenTiersLandInsideTheirForecasts() throws {
        var state = Scene.world("tiered blows")
        let me = state.player, foe = 1
        state.units.removeAll()
        let ground = try XCTUnwrap(state.map.hexes.first { hex in
            state.map[hex]?.terrain == .greyfield && state.map.neighbors(of: hex).allSatisfy { state.map[$0]?.terrain == .greyfield }
                && hex.spiral(3).allSatisfy { state.hold(at: $0) == nil }
        })
        _ = try state.perform(.declareWar(on: foe), as: me)
        var taken: [Int: Int] = [:]
        for (mine, theirs) in [(1, 1), (5, 1), (1, 5), (3, 4), (5, 5)] {
            for round in 0..<6 {
                var trial = state
                trial.draws = UInt64(round * 7)
                let striker = trial.put(.spear, tier: mine, of: me, at: ground)
                let there = ground + Hex.directions[0]
                trial.put(.spear, tier: theirs, of: foe, at: there)
                let forecast = try XCTUnwrap(trial.forecast(unit: striker, at: there))
                let events = try trial.perform(.attack(unit: striker, target: there), as: me)
                for case .battle(let battle) in events {
                    XCTAssertTrue(forecast.dealt.contains(battle.damageDealt), "\(mine) on \(theirs): \(battle.damageDealt) vs \(forecast.dealt)")
                    XCTAssertTrue(forecast.taken.contains(battle.damageTaken), "\(mine) on \(theirs): \(battle.damageTaken) vs \(forecast.taken)")
                    if mine == 1 { taken[theirs, default: 0] += battle.damageDealt }
                }
            }
        }
        XCTAssertLessThan(taken[5] ?? 0, taken[1] ?? 0, "A fifth tier takes less of a first tier's blows")

        // And at a hold's ward.
        var siege = Scene.world("tiered siege")
        let seat = try XCTUnwrap(siege.seat(of: foe))
        siege.units.removeAll { $0.owner == foe }
        let spot = try XCTUnwrap(siege.freeHex(near: seat.position))
        let first = siege.put(.spear, of: me, at: spot)
        _ = try siege.perform(.declareWar(on: foe), as: me)
        let low = try XCTUnwrap(siege.forecast(unit: first, at: seat.position))
        siege.units.removeAll { $0.id == first }
        let fifth = siege.put(.spear, tier: 5, of: me, at: spot)
        let high = try XCTUnwrap(siege.forecast(unit: fifth, at: seat.position))
        XCTAssertGreaterThan(high.dealt.lowerBound, low.dealt.lowerBound, "A fifth tier breaks a ward faster")
        XCTAssertLessThan(high.taken.upperBound, low.taken.upperBound, "and takes less from its walls")
        let events = try siege.perform(.attack(unit: fifth, target: seat.position), as: me)
        for case .battle(let battle) in events {
            XCTAssertTrue(high.dealt.contains(battle.damageDealt))
            XCTAssertTrue(high.taken.contains(battle.damageTaken))
        }
    }

    func testAHigherTierEatsMoreAndWeighsMoreInItsHousesStrength() throws {
        var (state, seat) = try world()
        let me = state.player
        let spot = try XCTUnwrap(state.freeHex(near: seat.position, within: 2...3))
        let upkeep = state.upkeep(of: me)
        let strength = state.strength(of: me)
        let id = state.put(.rider, tier: 5, of: me, at: spot)
        XCTAssertEqual(state.upkeep(of: me), upkeep + 3)
        let rider = try XCTUnwrap(state.unit(id))
        XCTAssertEqual(state.strength(of: me), strength + state.strength(of: rider))
        XCTAssertGreaterThan(state.strength(of: rider), (UnitKind.rider.attack + UnitKind.rider.defense) * 10 * 2)
    }

    /// A world with a company of a tier no kind has is unsound, and said so.
    func testATierOutOfRangeIsUnsound() throws {
        var (state, _) = try world()
        let index = try XCTUnwrap(state.units.firstIndex { $0.kind == .lantern })
        state.units[index].tier = 2
        XCTAssertTrue(state.problems().contains { $0.contains("tier 2") })
    }

    /// Games and orders from before tiers: every company of the first, a
    /// company mustering of the first, and an order to train read as one
    /// for the first.
    func testOlderSavesAndOrdersAreOfTheFirstTier() throws {
        var (state, seat) = try world()
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        state.holds[index].levels[.musterHall] = 3
        _ = try state.perform(.train(hold: seat.id, kind: .bow, tier: 3), as: state.player)
        state.units[0].tier = 2
        let old = try Scene.without(["tier"], in: state)
        let loaded = try JSONDecoder().decode(GameState.self, from: old)
        XCTAssertTrue(loaded.units.allSatisfy { $0.tier == 1 })
        XCTAssertEqual(loaded.holds[index].training?.musteredTier, 1)

        let order = try JSONDecoder().decode(Command.self, from: Data(#"{"train":{"hold":4,"kind":"spear"}}"#.utf8))
        XCTAssertEqual(order, .train(hold: 4, kind: .spear))
        XCTAssertEqual(order, .train(hold: 4, kind: .spear, tier: nil))
        let tiered = Command.train(hold: 4, kind: .rider, tier: 4)
        XCTAssertEqual(try JSONDecoder().decode(Command.self, from: JSONEncoder().encode(tiered)), tiered)
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state, "And comes back whole")
    }

    /// The Muster Hall's line names the tiers only its last two levels add;
    /// the first three open theirs with their own companies.
    func testTheMusterHallSaysTheTiersItOpens() {
        XCTAssertEqual(BuildingKind.musterHall.effect(atLevel: 4), "Trains companies of war of tier IV, once studied")
        XCTAssertEqual(BuildingKind.musterHall.effect(atLevel: 5), "Trains companies of war of tier V, once studied")
    }

    /// A steward with the studies, stores to spare and a high enough hall
    /// musters above the first tier; a poor one, or one unstudied, the first.
    func testAWealthyStewardMustersHigherTiers() throws {
        var state = Scene.world("tiered stewards")
        let steward = try XCTUnwrap(state.houses.first { !$0.isPlayer }?.id)
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == steward && $0.isSeat })
        state.holds[seat].levels[.musterHall] = 3
        state.holds[seat].levels[.granary] = 5
        state.watch = 30
        state.richen(steward)
        let hold = state.holds[seat]
        XCTAssertEqual(RivalMind(house: steward).chooseTier(of: .spear, at: hold, in: state), 1, "Unstudied, the first")
        state.houses[steward].research.learn(.drill, grade: 1)
        state.houses[steward].research.learn(.ironRanks, grade: 1)
        XCTAssertEqual(RivalMind(house: steward).chooseTier(of: .spear, at: hold, in: state), 3)
        state.houses[steward].stock = UnitKind.spear.cost(tier: 2) * 2
        XCTAssertEqual(RivalMind(house: steward).chooseTier(of: .spear, at: hold, in: state), 2, "Not its last stores")
        state.houses[steward].stock = UnitKind.spear.cost
        XCTAssertEqual(RivalMind(house: steward).chooseTier(of: .spear, at: hold, in: state), 1)
        XCTAssertEqual(RivalMind(house: steward).chooseTier(of: .lantern, at: hold, in: state), 1)
    }
}
