import Foundation
import XCTest
@testable import NullmereCore

/// Prisoners who talk: a keeper's company that fells a company led by a
/// commander takes the commander prisoner; questioned once a watch, they
/// tell one true thing of their House in turn; their House ransoms them,
/// or the captor lets them go, or they slip away; stewards take none.
final class PrisonersTests: XCTestCase {
    /// A keeper at war with a steward, the steward's commander at the head
    /// of a company beside one of the keeper's, the company all but spent.
    private func atWar(_ seed: String) throws -> (GameState, me: Int, steward: Int, mine: Int, theirs: Int, commander: Int) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let steward = try XCTUnwrap(state.houses.first { !$0.isPlayer }?.id)
        _ = try state.perform(.declareWar(on: steward), as: me)
        let seat = try XCTUnwrap(state.seat(of: me)).position
        let ground = seat.spiral(4).dropFirst().filter { hex in
            state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && !state.isOccupied(hex) && state.hold(at: hex) == nil
        }
        let at = try XCTUnwrap(ground.first)
        let beside = try XCTUnwrap(ground.first { $0.distance(to: at) == 1 })
        let mine = state.put(.spear, tier: 3, of: me, at: at)
        let theirs = state.put(.spear, of: steward, at: beside)
        let commander = try XCTUnwrap(state.commanders(of: steward).first).id
        state.units[try XCTUnwrap(state.unitIndex(theirs))].leader = commander
        state.units[try XCTUnwrap(state.unitIndex(theirs))].health = 1
        return (state, me, steward, mine, theirs, commander)
    }

    private func fell(_ theirs: Int, with mine: Int, in state: inout GameState, as me: Int) throws -> [GameEvent] {
        let at = try XCTUnwrap(state.unit(theirs)).position
        let events = try state.perform(.attack(unit: mine, target: at), as: me)
        XCTAssertNil(state.unit(theirs), "Felled")
        return events
    }

    func testAKeepersCompanyTakesALedCompanysCommanderPrisoner() throws {
        var (state, me, steward, mine, theirs, commander) = try atWar("prisoners taken")
        let events = try fell(theirs, with: mine, in: &state, as: me)
        XCTAssertTrue(events.contains(.commanderTaken(commander: commander, house: steward, by: me)), "\(events)")
        XCTAssertFalse(events.contains(.commanderWounded(commander: commander, house: steward)), "Taken, not carried home")
        let prisoner = try XCTUnwrap(state.commander(commander))
        XCTAssertEqual(prisoner.captive?.by, me)
        XCTAssertEqual(prisoner.captive?.since, state.watch)
        XCTAssertEqual(prisoner.owner, steward, "Still of their own House")
        XCTAssertEqual(state.prisoners(heldBy: me).map(\.id), [commander])
        XCTAssertTrue(state.chronicle.last { $0.kind == .commander }?.text.contains("prisoner") == true)
        let taken = GameEvent.commanderTaken(commander: commander, house: steward, by: me)
        XCTAssertTrue(state.tidings(of: taken, for: me)?.text.hasPrefix("Your company takes \(prisoner.name) of \(state.houses[steward].title) prisoner") == true)
        XCTAssertEqual(state.tidings(of: taken, for: steward)?.tone, .bad)
        let other = try XCTUnwrap(state.houses.first { $0.id != me && $0.id != steward }?.id)
        XCTAssertNil(state.tidings(of: taken, for: other))
        XCTAssertEqual(state.events([taken], heardBy: other), [])
        // The captor sees its prisoner; held, they lead no company.
        XCTAssertTrue(state.view(for: me).roster.contains { $0.id == commander && $0.captive?.by == me })
        let ward = try XCTUnwrap(state.units.first { $0.owner == steward && $0.kind.isMilitary && $0.leader == nil })
        XCTAssertEqual(state.assignRefusal(of: commander, to: ward.id, as: steward), .commanderCaptive)
        XCTAssertEqual(RuleError.commanderCaptive.description, "That commander is held prisoner.")
        // Kept with the world.
        let kept = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(kept.commander(commander), prisoner)

        // A steward's company felling a keeper's commander's company takes no one.
        var (other2, me2, steward2, mine2, _, _) = try atWar("stewards take no prisoners")
        let mineCommander = try XCTUnwrap(other2.commanders(of: me2).first).id
        other2.units[try XCTUnwrap(other2.unitIndex(mine2))].leader = mineCommander
        other2.units[try XCTUnwrap(other2.unitIndex(mine2))].health = 1
        let striker = try XCTUnwrap(other2.units.first { $0.owner == steward2 && $0.kind.isMilitary }).id
        let lost = try XCTUnwrap(other2.unit(mine2)).position
        _ = other2.fight(attacker: striker, defender: mine2, at: lost)
        XCTAssertNil(other2.unit(mine2))
        XCTAssertNil(other2.commander(mineCommander)?.captive, "Carried home wounded")
        XCTAssertTrue(other2.commander(mineCommander)?.isWounded(at: other2.watch) == true)
    }

    func testAPrisonerQuestionedTellsOneTrueThingAWatchInTurn() throws {
        var (state, me, steward, mine, theirs, commander) = try atWar("prisoners questioned")
        _ = try fell(theirs, with: mine, in: &state, as: me)
        let known = state.knowledge(of: steward)
        XCTAssertGreaterThanOrEqual(known.count, 4, "\(known)")
        let title = state.houses[steward].title
        XCTAssertTrue(known[0].hasPrefix("\(title) has ") && known[0].contains("of war"), known[0])
        XCTAssertTrue(known[1].hasPrefix("The greatest company of \(title) is its "), known[1])
        XCTAssertTrue(known[2].hasSuffix(" in store."), known[2])
        XCTAssertTrue(known.contains { $0.contains("the seat of \(title)") })

        let first = try state.perform(.question(commander: commander), as: me)
        XCTAssertEqual(first, [.prisonerQuestioned(commander: commander, by: me, word: known[0])])
        XCTAssertEqual(state.questionRefusal(commander, as: me), .questionedThisWatch)
        XCTAssertEqual(state.questionRefusal(commander, as: steward), .notYourPrisoner)
        XCTAssertEqual(state.tidings(of: first[0], for: me)?.text, "\(try XCTUnwrap(state.commander(commander)).name) tells you: \(known[0])")
        let other = try XCTUnwrap(state.houses.first { $0.id != me && $0.id != steward }?.id)
        XCTAssertEqual(state.events(first, heardBy: steward), [], "Only the captor hears it")
        XCTAssertEqual(state.events(first, heardBy: other), [])
        state.watch += 1
        let second = try state.perform(.question(commander: commander), as: me)
        XCTAssertEqual(second, [.prisonerQuestioned(commander: commander, by: me, word: state.knowledge(of: steward)[1])])
        XCTAssertEqual(state.commander(commander)?.captive?.questioned, 2)
    }

    func testAPrisonerIsRansomedLetGoOrSlipsAway() throws {
        var (state, me, steward, mine, theirs, commander) = try atWar("prisoners ransomed")
        _ = try fell(theirs, with: mine, in: &state, as: me)
        let price = GameState.ransom(for: try XCTUnwrap(state.commander(commander)))
        XCTAssertEqual(price.moonsalt, max(20, 10 * (state.commander(commander)?.level ?? 1)))
        XCTAssertEqual(state.ransomRefusal(commander, as: me), .notAPrisoner, "Only its own House ransoms it")

        // Too poor to pay twice over, a steward leaves them; rich enough, it pays.
        var poor = state
        poor.houses[steward].stock.moonsalt = price.moonsalt
        _ = poor.stewardTurn(for: steward)
        XCTAssertNotNil(poor.commander(commander)?.captive)
        var rich = state
        rich.houses[steward].stock.moonsalt = price.moonsalt * 3
        rich.houses[me].stock.moonsalt = 0
        _ = rich.stewardTurn(for: steward)
        XCTAssertNil(rich.commander(commander)?.captive, "Ransomed")
        XCTAssertEqual(rich.houses[me].stock.moonsalt, price.moonsalt, "The ransom in the captor's stores")
        XCTAssertTrue(rich.commander(commander)?.isWounded(at: rich.watch) == true, "Home to mend")

        // Let go by the captor, for nothing.
        var released = state
        let events = try released.perform(.release(commander: commander), as: me)
        XCTAssertEqual(events, [.prisonerFreed(commander: commander, house: steward, by: me, why: .released)])
        XCTAssertNil(released.commander(commander)?.captive)
        XCTAssertEqual(released.tidings(of: events[0], for: steward)?.tone, .good)
        XCTAssertThrowsError(try released.perform(.release(commander: commander), as: me)) {
            XCTAssertEqual($0 as? RuleError, .notYourPrisoner)
        }

        // Held their full time, they slip away as the watch turns.
        var held = state
        held.watch += GameState.captivityLasts - 1
        XCTAssertEqual(held.keepPrisoners(), [])
        held.watch += 1
        XCTAssertEqual(held.keepPrisoners(), [.prisonerFreed(commander: commander, house: steward, by: me, why: .escaped)])
        XCTAssertNil(held.commander(commander)?.captive)
        // Their captor fallen, they walk free.
        var fallen = state
        fallen.houses[me].isEliminated = true
        XCTAssertEqual(fallen.keepPrisoners().count, 1)
    }

    /// A world of stewards takes no prisoners, and goes as it always did.
    func testStewardsTakeNone() {
        var stewards = GameState(settings: GameSettings(seedText: "stewards take no one", houseCount: 4, radius: 18))
        for _ in 0..<40 { _ = stewards.endWatch() }
        XCTAssertTrue(stewards.roster.allSatisfy { $0.captive == nil })
    }
}
