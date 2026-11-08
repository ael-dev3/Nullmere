import Foundation
import XCTest
@testable import NullmereCore

/// Vigils for the fallen: a light set on the water by a keeper whose House
/// has lost companies of war, seen by the whole realm, carried round the
/// lake, guttering out after its watches; honoured once by each other
/// keeper, binding them from striking the mourning House while it burns,
/// and counted toward its keeper's renown as the age ends.
final class VigilTests: XCTestCase {
    /// A lake with two keepers at war, the first's hold beside the water.
    private func world() throws -> (GameState, me: Int, other: Int, hold: Int) {
        var state = Scene.world("vigils", houses: 4, radius: 16)
        let me = state.player
        let other = (me + 1) % 4
        state.houses[other].isPlayer = true
        state.houses[me].stock = Stock(grain: 500, timber: 100, stone: 100, moonsalt: 10)
        let shore = try XCTUnwrap(state.map.hexes.first { hex in
            state.map[hex]?.terrain.isSettleable == true && state.hold(at: hex) == nil && state.unit(at: hex) == nil
                && state.map.neighbors(of: hex).contains { [.still, .shallows].contains(state.map[$0]?.terrain) }
        })
        let hold = Hold(id: state.takeID(), name: "Mournwater", owner: me, position: shore, isSeat: false, foundedWatch: 1)
        state.holds.append(hold)
        return (state, me, other, hold.id)
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

    /// A company of war of a House's, struck down where it stands.
    private func fall(_ house: Int, in state: inout GameState) throws {
        let at = try XCTUnwrap(state.map.hexes.first { state.map[$0]?.terrain.isPassable == true && state.unit(at: $0) == nil && state.hold(at: $0) == nil })
        let unit = Unit(id: state.takeID(), kind: .spear, owner: house, position: at)
        state.units.append(unit)
        var events: [GameEvent] = []
        XCTAssertTrue(state.applyDamage(1_000, to: unit.id, events: &events))
    }

    func testAVigilIsKeptForCompaniesFallenAndSeenByAll() throws {
        var (state, me, other, hold) = try world()
        XCTAssertEqual(refusal(.keepVigil(words: "For the spears at the ford", hold: hold), in: state, as: me), .noneUnmourned,
                       "None fallen, none to keep a vigil for")
        try fall(me, in: &state)
        try fall(me, in: &state)
        try fall(other, in: &state)
        XCTAssertEqual(state.unmourned(by: me), 2)
        // A steward's House mourns no one.
        let steward = (me + 2) % 4
        try fall(steward, in: &state)
        XCTAssertEqual(state.unmourned(by: steward), 0)

        let timber = state.houses[me].stock.timber, moonsalt = state.houses[me].stock.moonsalt
        let events = try state.perform(.keepVigil(words: "  For the spears at the ford.  ", hold: hold), as: me)
        let vigil = try XCTUnwrap(state.vigilsOnTheLake.last)
        XCTAssertEqual(events, [.vigilKept(vigil)])
        XCTAssertEqual(vigil.words, "For the spears at the ford.")
        XCTAssertEqual(vigil.fallen, 2)
        XCTAssertEqual(vigil.house, me)
        XCTAssertEqual(vigil.lit, state.watch)
        XCTAssertEqual(vigil.until, state.watch + GameState.vigilBurns)
        XCTAssertTrue([.still, .shallows].contains(state.map[vigil.position]?.terrain), "Set on the water")
        XCTAssertEqual(state.houses[me].stock.timber, timber - GameState.vigilCost.timber)
        XCTAssertEqual(state.houses[me].stock.moonsalt, moonsalt - GameState.vigilCost.moonsalt)
        XCTAssertEqual(state.unmourned(by: me), 0, "Those fallen are mourned")
        XCTAssertEqual(refusal(.keepVigil(words: "Again", hold: hold), in: state, as: me), .noneUnmourned)

        // Every keeper hears of it and sees its words; the unmourned are the House's own.
        XCTAssertEqual(state.events(events, heardBy: other).count, 1)
        XCTAssertEqual(state.tidings(of: .vigilKept(vigil), for: me)?.text,
                       "Your vigil's light is on the water, lit for 2 companies lost: “For the spears at the ford.” "
                           + "A House that honours it may not strike yours while it burns.")
        XCTAssertEqual(state.tidings(of: .vigilKept(vigil), for: other)?.text,
                       "\(state.houses[me].title) keeps a vigil on the water for its fallen, lit for 2 companies lost: “For the spears at the ford.”")
        try fall(me, in: &state)
        let view = state.view(for: other)
        XCTAssertEqual(view.vigilsOnTheLake, state.vigilsOnTheLake)
        XCTAssertNil(view.houses[me].unmourned, "Another House's dead uncounted are its own")
        XCTAssertEqual(state.view(for: me).houses[me].unmourned, 1)
        XCTAssertEqual(state.problems().filter { $0.hasPrefix("Vigil") }, [])
    }

    func testAVigilRefusesWhatTheRulesDoNot() throws {
        var (state, me, other, hold) = try world()
        try fall(me, in: &state)
        XCTAssertEqual(refusal(.keepVigil(words: "For them", hold: hold), in: state, as: other), .notYours)
        XCTAssertEqual(refusal(.keepVigil(words: "For them", hold: 987_654), in: state, as: me), .unknownHold)
        XCTAssertEqual(refusal(.keepVigil(words: "   ", hold: hold), in: state, as: me), .nothingToSay)
        let inland = try XCTUnwrap(state.holds.first { $0.owner == me && state.castingWater(beside: $0) == nil })
        XCTAssertEqual(refusal(.keepVigil(words: "For them", hold: inland.id), in: state, as: me), .noWaterBeside)
        XCTAssertEqual(refusal(.keepVigil(words: "For them", hold: hold), in: state, as: (me + 2) % 4), .notAKeeper)
        state.houses[me].stock = .zero
        XCTAssertEqual(refusal(.keepVigil(words: "For them", hold: hold), in: state, as: me),
                       .shortOf(Stock.zero.shortfall(for: GameState.vigilCost)))
        XCTAssertEqual(RuleError.noneUnmourned.description, "Your House has lost no company of war in battle since its last vigil.")
        XCTAssertEqual(GameState.vigilSaid,
                       "A light set on the water for your House's fallen, with your words for them. The whole realm sees it drift until it gutters out, "
                           + "12 watches on. A House that honours it may strike none of yours while it burns, and each honour adds to your renown "
                           + "at the age's end. It costs 5 timber, 1 moonsalt, once your House has lost companies since its last.")
    }

    func testAnHonouredVigilBindsTheHonouringHouseWhileItBurns() throws {
        var (state, me, other, hold) = try world()
        try fall(me, in: &state)
        _ = try state.perform(.keepVigil(words: "For the riders of the reeds", hold: hold), as: me)
        let vigil = try XCTUnwrap(state.vigilsOnTheLake.last)
        XCTAssertEqual(refusal(.honourVigil(vigil.id), in: state, as: me), .ownVigil)
        XCTAssertEqual(refusal(.honourVigil(vigil.id), in: state, as: (me + 2) % 4), .notAKeeper)
        XCTAssertEqual(refusal(.honourVigil(987_654), in: state, as: other), .noSuchVigil)

        // At war, and a company of the other's beside the mourning House's hold.
        state.setStance(.war, between: me, and: other, by: other)
        let mine = try XCTUnwrap(state.hold(hold))
        let beside = try XCTUnwrap(state.map.neighbors(of: mine.position).first {
            state.map[$0]?.terrain.isPassable == true && state.unit(at: $0) == nil && state.hold(at: $0) == nil
        })
        let striker = Unit(id: state.takeID(), kind: .spear, owner: other, position: beside)
        state.units.append(striker)
        XCTAssertNil(refusal(.attack(unit: striker.id, target: mine.position), in: state, as: other), "Free to strike before honouring")

        let events = try state.perform(.honourVigil(vigil.id), as: other)
        XCTAssertEqual(events, [.vigilHonoured(vigil: vigil.id, house: me, by: other)])
        XCTAssertEqual(state.vigil(vigil.id)?.honouredBy, [other])
        XCTAssertEqual(state.houses[me].honoured, 1)
        XCTAssertEqual(refusal(.honourVigil(vigil.id), in: state, as: other), .honouredAlready)
        XCTAssertEqual(refusal(.attack(unit: striker.id, target: mine.position), in: state, as: other), .mourning(until: vigil.until))
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.text,
                       "\(state.houses[other].title) honours your vigil for the fallen: it may not strike your House while the light burns.")
        XCTAssertEqual(state.tidings(of: events[0], for: other)?.text,
                       "Your House honours \(state.houses[me].title)'s vigil for its fallen: it may not strike them while the light burns, "
                           + "until watch \(vigil.until).")
        let third = (me + 3) % 4
        XCTAssertEqual(state.tidings(of: events[0], for: third)?.text,
                       "\(state.houses[other].title) honours \(state.houses[me].title)'s vigil for its fallen.")
        XCTAssertEqual(state.events(events, heardBy: third).count, 1, "The whole realm sees who honours it")
        XCTAssertEqual(RuleError.mourning(until: 30).description,
                       "Your House honoured a vigil of that House's for its fallen: it may not strike them, nor rally on their holds, "
                           + "while its light burns, until watch 30.")

        // The light drifts with the current, staying on the water, and goes out at its watch.
        var drifted = state
        drifted.watch = vigil.until - 1
        _ = drifted.tendVigils()
        let carried = try XCTUnwrap(drifted.vigil(vigil.id))
        XCTAssertNotEqual(carried.position, vigil.position, "Carried on")
        XCTAssertTrue([.still, .shallows].contains(drifted.map[carried.position]?.terrain))
        drifted.watch = vigil.until
        let out = drifted.tendVigils()
        XCTAssertEqual(out, [.vigilOut(vigil: vigil.id, house: me, honours: 1)])
        XCTAssertNil(drifted.vigils, "None burns")
        XCTAssertEqual(drifted.tidings(of: out[0], for: me)?.text, "Your vigil's light has gone out on the water, honoured by 1 House.")
        XCTAssertNil(drifted.tidings(of: out[0], for: other))
        XCTAssertEqual(drifted.events(out, heardBy: other).count, 0)
        XCTAssertNil(refusal(.attack(unit: striker.id, target: mine.position), in: drifted, as: other), "Its light out, the truce ends")
        XCTAssertEqual(drifted.houses[me].honoured, 1, "The honour kept for the age's end")
    }

    func testHonoursCountTowardRenownAsTheAgeEnds() throws {
        var (state, me, other, _) = try world()
        state.houses[me].honoured = GameState.honoursThatCount + 3
        XCTAssertEqual(state.honoursCounted(of: me), GameState.honoursThatCount, "At the most")
        XCTAssertEqual(state.honoursCounted(of: other), 0)
        XCTAssertEqual(state.honoursCounted(of: 9_999), 0)
        var realm = RealmState(name: "R", world: state, keeper: "ash", now: 0)
        let keeper = try XCTUnwrap(realm.keepers.firstIndex { $0.id == "ash" })
        XCTAssertEqual(realm.keepers[keeper].house, me)
        realm.world.outcome = Outcome(winner: other, kind: .ascendancy, watch: state.watch)
        var plain = realm
        plain.world.houses[me].honoured = nil
        realm.rememberTheAge()
        plain.rememberTheAge()
        XCTAssertEqual((realm.keepers[keeper].renown ?? 0) - (plain.keepers[keeper].renown ?? 0),
                       GameState.renownPerHonour * GameState.honoursThatCount)
    }

    func testAVigilIsToldAlikeOnTheMacAndThePhone() throws {
        let (state, me, other, _) = try world()
        let third = (me + 2) % 4, fourth = (me + 3) % 4
        let vigil = Vigil(id: 1, house: me, words: "For them", fallen: 3, lit: 4, position: .origin)
        XCTAssertEqual(state.vigilTitle(vigil, for: me), "Your House's vigil")
        XCTAssertEqual(state.vigilTitle(vigil, for: other), "\(state.houses[me].title)'s vigil")
        XCTAssertEqual(state.vigilLine(vigil, for: other), "For 3 companies fallen: “For them” Lit in watch 4, honoured by none yet; it burns until watch 16.")
        var honoured = vigil
        honoured.honouredBy = [other, third]
        XCTAssertEqual(state.vigilLine(honoured, for: other),
                       "For 3 companies fallen: “For them” Lit in watch 4, honoured by your House and \(state.houses[third].title); it burns until watch 16.")
        honoured.honouredBy = [other, third, fourth, 77]
        XCTAssertEqual(state.vigilLine(honoured, for: me), "For 3 companies fallen: “For them” Lit in watch 4, honoured by 4 Houses; it burns until watch 16.")
        honoured.honouredBy = [77]
        XCTAssertTrue(state.vigilLine(honoured, for: me).contains("honoured by a fallen House"))
        // A House that is no more: told as fallen, its tidings to none.
        let orphan = Vigil(id: 2, house: 77, words: "For them", fallen: 1, lit: 4, position: .origin)
        XCTAssertEqual(state.vigilTitle(orphan, for: me), "A fallen House's vigil")
        XCTAssertEqual(state.honourSaid(orphan), "Honour it, and your House may not strike its House, nor rally on its holds, until watch 16; "
                           + "the honour adds to its keeper's renown as the age ends.")
        XCTAssertNil(state.tidings(of: .vigilKept(orphan), for: me))
        XCTAssertNil(state.tidings(of: .vigilHonoured(vigil: 2, house: 77, by: me), for: me))
        XCTAssertNil(state.tidings(of: .vigilHonoured(vigil: 1, house: me, by: 77), for: me))
        XCTAssertEqual(state.unmourned(by: 77), 0)
        XCTAssertNil(state.vigilHonoured(by: other, of: me), "Nothing burns, nothing binds")
        // Where the device's model writes no words for the dead, the keeper is told why, and that they are theirs to write.
        XCTAssertEqual(CounselTrouble.slow.unwritten,
                       "No answer came from Apple's on-device model in time, so the words for your dead are yours to write.")
    }

    func testTheLakeCarriesSoManyLightsAndAnUnsoundOneIsFound() throws {
        var (state, me, _, hold) = try world()
        let water = try XCTUnwrap(state.castingWater(beside: XCTUnwrap(state.hold(hold))))
        state.vigils = (0..<GameState.vigilsBurning).map { Vigil(id: 10_000 + $0, house: me, words: "x", fallen: 1, lit: state.watch, position: water) }
        try fall(me, in: &state)
        let events = try state.perform(.keepVigil(words: "One more", hold: hold), as: me)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events.last, .vigilOut(vigil: 10_000, house: me, honours: 0))
        XCTAssertEqual(state.vigilsOnTheLake.count, GameState.vigilsBurning)
        var unsound = state
        unsound.vigils = [Vigil(id: 2, house: me, words: "x", fallen: 1, lit: 1, position: Hex(400, 400))]
        XCTAssertEqual(unsound.problems().filter { $0.hasPrefix("Vigil 2") }.count, 1)
        XCTAssertEqual(unsound.tidings(of: .vigilOut(vigil: 2, house: me, honours: 0), for: me)?.text,
                       "Your vigil's light has gone out on the water, honoured by no House.")
        XCTAssertEqual(unsound.tidings(of: .vigilOut(vigil: 2, house: me, honours: 3), for: me)?.text,
                       "Your vigil's light has gone out on the water, honoured by 3 Houses.")
    }
}
