import Foundation
import XCTest
@testable import NullmereCore

/// A company raised a tier where it stands by its House's Muster Hall
/// (Rise of Kingdoms' troop upgrade): paid for as the two tiers' musters
/// differ, as many times over as its whole muster is its first; whole
/// after, its drilled troops kept and its ranks filled to the new tier's
/// first muster; told to its House alone; and refused, in the realm's words,
/// wherever the rules say no.
final class RaisedTiersTests: XCTestCase {
    /// A keeper's House with its seat's Muster Hall at a level, stores to
    /// spend, the study that opens the second tier, its own companies
    /// cleared, and a Spear of the first tier in the seat.
    private func yard(_ seed: String, hall: Int = 3) throws -> (state: GameState, me: Int, spear: Int, seat: Hold) {
        var state = Scene.world(seed, houses: 4, radius: 18)
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        state.holds[index].levels[.musterHall] = hall
        state.units.removeAll { $0.owner == me }
        state.richen(me)
        state.houses[me].research.learn(.drill, grade: 1)
        let spear = state.put(.spear, tier: 1, of: me, at: seat.position)
        return (state, me, spear, state.holds[index])
    }

    /// What the second tier's muster costs over the first's, for the House.
    private func step(_ state: GameState, _ house: Int, from tier: Int = 1) -> Stock {
        let next = state.trainingCost(of: .spear, tier: tier + 1, for: house), now = state.trainingCost(of: .spear, tier: tier, for: house)
        var step = Stock()
        for resource in Resource.allCases { step[resource] = max(next[resource] - now[resource], 0) }
        return step
    }

    func testACompanyIsRaisedATierByItsHall() throws {
        var (state, me, spear, seat) = try yard("raised a tier")
        let unit = try XCTUnwrap(state.unit(spear))
        let cost = state.raiseCost(of: unit)
        XCTAssertEqual(cost, step(state, me), "Undrilled, the two musters' difference")
        XCTAssertFalse(cost.isZero)
        XCTAssertEqual(state.raiseSaid(of: unit), "Raise to Spears II: \(cost.listedSaid)")
        XCTAssertNil(state.raiseRefusal(of: unit, as: me))

        var paid = state.houses[me].stock
        paid.debit(cost)
        let events = try state.perform(.raiseTier(unit: spear), as: me)
        XCTAssertEqual(events, [.tierRaised(unit: spear, owner: me, tier: 2)])
        let raised = try XCTUnwrap(state.unit(spear))
        XCTAssertEqual(raised.tier, 2)
        XCTAssertEqual(raised.movesLeft, 0, "It spends the watch at it")
        XCTAssertEqual(state.houses[me].stock, paid)
        XCTAssertEqual(state.fullMuster(of: raised), UnitKind.spear.troops(tier: 2), "Its ranks filled to the new tier's first muster")
        XCTAssertGreaterThan(state.strength(of: raised), state.strength(of: unit))

        // Told to its House alone, where it was raised.
        let other = (me + 1) % state.houses.count
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.text,
                       "Your Spears at \(seat.name) are raised to Spears II: \(GameState.counted(UnitKind.spear.troops(tier: 2))) troops.")
        XCTAssertNil(state.tidings(of: events[0], for: other))
        XCTAssertEqual(state.events(events, heardBy: me), events)
        XCTAssertTrue(state.events(events, heardBy: other).isEmpty)

        // No higher than the House has studied.
        XCTAssertEqual(state.refusal(of: .raiseTier(unit: spear), as: me), .needsStudy(.ironRanks, 1))
        state.houses[me].research.learn(.ironRanks, grade: 1)
        state.units[try XCTUnwrap(state.unitIndex(spear))].movesLeft = 1
        XCTAssertNil(state.refusal(of: .raiseTier(unit: spear), as: me))
        XCTAssertEqual(try state.perform(.raiseTier(unit: spear), as: me), [.tierRaised(unit: spear, owner: me, tier: 3)])
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state)
    }

    func testARaiseIsPaidForTheWholeMusterAndKeepsWhatWasDrilled() throws {
        var (state, me, spear, _) = try yard("raised when drilled")
        let index = try XCTUnwrap(state.unitIndex(spear))
        let first = UnitKind.spear.troops(tier: 1)
        state.units[index].drilled = first
        let unit = state.units[index]
        XCTAssertEqual(state.musterPercent(of: unit), 200)
        var twice = Stock()
        for resource in Resource.allCases { twice[resource] = step(state, me)[resource] * 2 }
        XCTAssertEqual(state.raiseCost(of: unit), twice, "Twice its first muster, twice the price")
        _ = try state.perform(.raiseTier(unit: spear), as: me)
        let raised = try XCTUnwrap(state.unit(spear))
        XCTAssertEqual(raised.drilled, first, "What was drilled stays drilled")
        XCTAssertEqual(state.fullMuster(of: raised), UnitKind.spear.troops(tier: 2) + first)
        XCTAssertEqual(raised.leader, unit.leader)
        XCTAssertEqual(raised.health, unit.health)
    }

    /// Raised to the fifth tier of its heritage's kind, a company is its
    /// House's own, named so on its panel, the phone and the tidings alike.
    func testTheFifthTierOfAHousesOwnKindIsNamedItsOwn() throws {
        var (state, me, spear, seat) = try yard("raised its own", hall: UnitKind.spear.highestTier)
        state.houses[me].heritage = .saltborn
        let index = try XCTUnwrap(state.unitIndex(spear))
        state.units[index].tier = UnitKind.spear.highestTier - 1
        for study in [Study.ironRanks, .greyCompanies, .moonsteel] { state.houses[me].research.learn(study, grade: 1) }
        state.houses[me].stock = Stock(grain: 1_000_000, timber: 1_000_000, stone: 1_000_000, moonsalt: 1_000_000)
        XCTAssertEqual(state.hold(seat.id)?.level(.musterHall), UnitKind.spear.highestTier)
        let unit = state.units[index]
        XCTAssertEqual(state.raisedName(of: unit), "Salt Wardens")
        XCTAssertTrue(state.raiseSaid(of: unit).hasPrefix("Raise to Salt Wardens: "))
        XCTAssertNil(state.raiseRefusal(of: unit, as: me))
        let events = try state.perform(.raiseTier(unit: spear), as: me)
        XCTAssertTrue(state.isSignature(try XCTUnwrap(state.unit(spear))))
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.text.contains("are raised to Salt Wardens: "), true)
        // Of another heritage, the kind's fifth tier by its numeral.
        state.houses[me].heritage = .fenfolk
        state.units[index].tier = UnitKind.spear.highestTier - 1
        XCTAssertEqual(state.raisedName(of: state.units[index]), "Spears V")
    }

    /// Raised from the order book: RAISE raises a company a tier where it
    /// stands, the briefing telling the model which may and for what; where
    /// it can't, told why in the realm's own words; and a commander may put
    /// it forward, knowing which of the House's companies may be raised.
    func testACompanyIsRaisedFromTheBookAndCounselMayProposeIt() throws {
        var (state, me, spear, _) = try yard("raised from the book")
        let unit = try XCTUnwrap(state.unit(spear))
        let companies = SpokenOrders.companies(in: state, player: me)
        let handle = "C\(try XCTUnwrap(companies.firstIndex { $0.id == spear }) + 1)"
        XCTAssertTrue(SpokenOrders.forms.contains("RAISE <company>"))
        let said = ", which may be raised to Spears II where it stands for \(state.raiseCost(of: unit).listedSaid) (RAISE)"
        let briefing = SpokenOrders.briefing(for: state, player: me).split(separator: "\n").map(String.init)
        XCTAssertTrue(briefing.contains { $0.hasPrefix("\(handle): ") && $0.hasSuffix(said) }, "\(briefing)")
        let raise = try XCTUnwrap(SpokenOrders.read("raise \(handle)", in: state, player: me).first)
        XCTAssertEqual(raise.command, .raiseTier(unit: spear))
        XCTAssertNil(raise.why)
        XCTAssertEqual(raise.told, "Your \(SpokenOrders.named(unit, in: state)) are raised to Spears II.")

        // A commander leading it knows it may be raised, and may put it forward.
        let commander = try XCTUnwrap(state.commanders(of: me).first)
        state.units[try XCTUnwrap(state.unitIndex(spear))].leader = commander.id
        let counsel = try XCTUnwrap(CommanderCounsel(state: state, player: me, commander: commander.id))
        XCTAssertTrue(counsel.briefing.contains(", which may be raised to Spears II where it stands for \(state.raiseCost(of: unit).listedSaid)"),
                      counsel.briefing)
        XCTAssertTrue(CommanderCounsel.actions.contains("raise"))
        XCTAssertTrue(CommanderCounsel.onlyThese.contains("raise (a tier, by a Muster Hall of your House where it stands)"))
        let ownHandle = try XCTUnwrap(counsel.handle(of: unit))
        let proposed = counsel.propose("raise", company: ownHandle, place: "")
        XCTAssertEqual(proposed.line, "RAISE \(ownHandle)")
        XCTAssertEqual(proposed.command, .raiseTier(unit: spear))
        XCTAssertNil(proposed.why)

        // Away from any hall: told why, and the briefing no longer offers it.
        let away = try XCTUnwrap(unit.position.spiral(4).first { $0.distance(to: unit.position) == 3 && state.map[$0] != nil })
        state.units[try XCTUnwrap(state.unitIndex(spear))].position = away
        XCTAssertEqual(try XCTUnwrap(SpokenOrders.read("RAISE \(handle)", in: state, player: me).first).why,
                       RuleError.raisedAtMusterHall.description)
        XCTAssertFalse(SpokenOrders.briefing(for: state, player: me).contains("(RAISE)"))
        // Of a kind of one tier, told so, not named a tier it can't be.
        let lantern = state.put(.lantern, of: me, at: away)
        let lanterns = "C\(try XCTUnwrap(SpokenOrders.companies(in: state, player: me).firstIndex { $0.id == lantern }) + 1)"
        let one = try XCTUnwrap(SpokenOrders.read("RAISE \(lanterns)", in: state, player: me).first)
        XCTAssertEqual(one.told, "Your \(SpokenOrders.named(try XCTUnwrap(state.unit(lantern)), in: state)) are raised a tier.")
        XCTAssertEqual(one.why, RuleError.oneTierOnly(.lantern).description)
    }

    func testARaiseIsRefusedWhereTheRulesSayNo() throws {
        let (state, me, spear, seat) = try yard("raise refused")
        let index = try XCTUnwrap(state.unitIndex(spear))
        func refused(_ change: (inout GameState) -> Void, as house: Int? = nil, unit: Int? = nil) -> RuleError? {
            var changed = state
            change(&changed)
            return changed.refusal(of: .raiseTier(unit: unit ?? spear), as: house ?? me)
        }
        XCTAssertEqual(refused({ _ in }, as: (me + 1) % state.houses.count), .notYours)
        XCTAssertEqual(refused({ _ in }, unit: 999_999), .unknownUnit)
        var lanterns = state
        let lantern = lanterns.put(.lantern, of: me, at: seat.position)
        XCTAssertEqual(lanterns.refusal(of: .raiseTier(unit: lantern), as: me), .oneTierOnly(.lantern))
        XCTAssertEqual(refused({ $0.units[index].tier = UnitKind.spear.highestTier }), .atHighestTier)
        let away = try XCTUnwrap(seat.position.spiral(4).first { $0.distance(to: seat.position) == 3 && state.map[$0] != nil })
        XCTAssertEqual(refused({ $0.units[index].destination = away }), .raisedStandingStill, "On the march")
        XCTAssertEqual(refused({ $0.units[index].errand = .reinforce(hold: seat.id) }), .raisedStandingStill, "About an errand")
        XCTAssertEqual(refused({ $0.units[index].position = away }), .raisedAtMusterHall, "Away from any hall")
        let hall = try XCTUnwrap(state.holdIndex(seat.id))
        XCTAssertEqual(refused({ $0.holds[hall].levels[.musterHall] = 1 }), .needsMusterHall(2))
        XCTAssertEqual(refused({ $0.houses[me].research = Research() }), .needsStudy(.drill, 1))
        XCTAssertEqual(refused({ $0.houses[me].stock = .zero }), .shortOf(state.raiseCost(of: state.units[index])))
        // In a field of battle, not out of the fighting.
        XCTAssertEqual(refused { world in
            var field = Field(id: 77, at: seat.position, joined: world.watch, first: me, second: (me + 1) % world.houses.count)
            field.fighters.append(Fighter(unit: spear, owner: me, side: 0, kind: .spear, tier: 1, leader: nil, troops: 1_200))
            world.fields = [field]
        }, .raisedOutOfBattle)
        XCTAssertEqual(RuleError.raisedOutOfBattle.description, "A company is raised a tier out of the fighting, not in a field of battle.")
    }
}
