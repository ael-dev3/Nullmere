import Foundation
import XCTest
@testable import NullmereCore

/// Torches on the march: a company that douses them marches dark, a tile
/// less each watch, and another House sees it, and is told of its moves,
/// only close by; its own House sees it as ever; lit again, it is seen and
/// marches as before; the realm keeps which march dark with the rest of it.
final class TorchesTests: XCTestCase {
    /// A keeper's spears in open ground near its seat, with moves.
    private func marching(_ seed: String = "torches on the march") throws -> (GameState, me: Int, unit: Int) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me)).position
        let unit = try XCTUnwrap(state.placeUnit(.spear, tier: 1, for: me, near: seat))
        let index = try XCTUnwrap(state.unitIndex(unit.id))
        state.units[index].movesLeft = state.movement(of: state.units[index])
        return (state, me, unit.id)
    }

    func testACompanyDousesItsTorchesAndMarchesATileSlower() throws {
        var (state, me, unit) = try marching()
        let pace = state.movement(of: try XCTUnwrap(state.unit(unit)))
        XCTAssertGreaterThan(pace, 1)
        XCTAssertFalse(state.isUnlit(unit))
        XCTAssertEqual(state.torchRefusal(unit, lit: true, as: me), .torchesAlready(lit: true))
        XCTAssertNil(state.torchRefusal(unit, lit: false, as: me))
        let events = try state.perform(.torches(unit: unit, lit: false), as: me)
        XCTAssertEqual(events, [.torchesSet(unit: unit, lit: false, owner: me)])
        XCTAssertTrue(state.isUnlit(unit))
        XCTAssertEqual(state.movement(of: try XCTUnwrap(state.unit(unit))), pace - 1, "A tile less")
        XCTAssertEqual(try XCTUnwrap(state.unit(unit)).movesLeft, pace - 1, "Its moves this watch no more than a dark march has")
        XCTAssertEqual(state.torchRefusal(unit, lit: false, as: me), .torchesAlready(lit: false))
        XCTAssertEqual(RuleError.torchesAlready(lit: false).description, "It marches dark already.")
        XCTAssertEqual(RuleError.torchesAlready(lit: true).description, "Its torches burn already.")
        // Told to its own keeper, and to no other.
        let told = try XCTUnwrap(state.tidings(of: events[0], for: me)).text
        XCTAssertTrue(told.hasSuffix("douse their torches: they march dark, a tile less each watch, seen by other Houses only close by."), told)
        XCTAssertNil(state.tidings(of: events[0], for: (me + 1) % state.houses.count))
        XCTAssertEqual(state.events(events, heardBy: me), events)
        XCTAssertTrue(state.events(events, heardBy: (me + 1) % state.houses.count).isEmpty)
        // As the watch turns it keeps the dark pace.
        _ = state.endWatch()
        XCTAssertEqual(try XCTUnwrap(state.unit(unit)).movesLeft, pace - 1)
        // Lit again, at its pace from the next watch.
        let lit = try state.perform(.torches(unit: unit, lit: true), as: me)
        XCTAssertEqual(lit, [.torchesSet(unit: unit, lit: true, owner: me)])
        XCTAssertFalse(state.isUnlit(unit))
        XCTAssertNil(state.unlit, "None marching dark, none kept")
        XCTAssertTrue(try XCTUnwrap(state.tidings(of: lit[0], for: me)).text.hasSuffix("light their torches again: they march at their pace, and are seen as far as any company."))
        _ = state.endWatch()
        XCTAssertEqual(try XCTUnwrap(state.unit(unit)).movesLeft, pace)
    }

    func testOnlyItsOwnHouseOrdersItsTorches() throws {
        let (state, me, unit) = try marching()
        let other = (me + 1) % state.houses.count
        XCTAssertEqual(state.torchRefusal(unit, lit: false, as: other), .notYours)
        XCTAssertEqual(state.torchRefusal(99_999, lit: false, as: me), .unknownUnit)
        var ended = state
        ended.outcome = Outcome(winner: me, kind: .ascendancy, watch: state.watch)
        XCTAssertEqual(ended.torchRefusal(unit, lit: false, as: me), .gameOver)
        // A company that goes no further than a tile goes a tile still.
        var slow = state
        let index = try XCTUnwrap(slow.unitIndex(unit))
        slow.units[index].kind = .mangonel
        let crawl = slow.movement(of: slow.units[index])
        _ = try slow.perform(.torches(unit: unit, lit: false), as: me)
        XCTAssertEqual(slow.movement(of: slow.units[index]), max(crawl - 1, 1))
    }

    /// A tile another House sees from its seat, open and empty, but not
    /// within a tile of anything that House sees from.
    private func seenFromAfar(by other: Int, in state: GameState) throws -> Hex {
        let seen = state.visibility(for: other), close = state.closeSight(for: other)
        return try XCTUnwrap(state.map.hexes.first { hex in
            guard let index = state.map.index(of: hex) else { return false }
            return seen[index] && !close[index] && state.map[hex]?.terrain.isPassable == true && state.map[hex]?.terrain.isWater == false
                && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        }, "A tile seen from afar")
    }

    func testAnotherHouseSeesACompanyMarchingDarkOnlyCloseBy() throws {
        var (state, me, unit) = try marching()
        let other = try XCTUnwrap(state.livingHouses.first { $0.id != me && state.watchers(for: me).contains($0.id) == false }).id
        let afar = try seenFromAfar(by: other, in: state)
        let index = try XCTUnwrap(state.unitIndex(unit))
        state.units[index].position = afar
        // Lit, it is seen wherever the other House's sight reaches.
        XCTAssertNotNil(state.view(for: other).unit(unit))
        _ = try state.perform(.torches(unit: unit, lit: false), as: me)
        // Dark, the other House sees it no longer; its own House does, and
        // knows it marches dark.
        XCTAssertNil(state.view(for: other).unit(unit), "Dark, unseen from afar")
        XCTAssertNil(state.view(for: other).unlit, "Another House isn't told who marches dark")
        XCTAssertNotNil(state.view(for: me).unit(unit))
        XCTAssertEqual(state.view(for: me).unlit, [unit])
        XCTAssertTrue(state.view(for: me).isUnlit(unit))
        // Come within a tile of the other House's seat or companies, it is
        // seen close by.
        let near = try XCTUnwrap(state.map.hexes.first { hex in
            guard let index = state.map.index(of: hex) else { return false }
            return state.closeSight(for: other)[index] && state.map[hex]?.terrain.isPassable == true && state.map[hex]?.terrain.isWater == false
                && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        })
        state.units[index].position = near
        XCTAssertNotNil(state.view(for: other).unit(unit), "Close by, the dark hides it no longer")
        XCTAssertEqual(state.view(for: other).unlit, [unit], "Seen close by, it is seen to carry no torches")
        // A House in a pact shares its sight, and sees it from afar as its
        // own House does.
        state.units[index].position = afar
        XCTAssertNil(state.view(for: other).unit(unit))
        state.setStance(.pact, between: me, and: other, by: me)
        XCTAssertNotNil(state.view(for: other).unit(unit), "An ally sees it from afar")
        XCTAssertEqual(state.view(for: other).unlit, [unit], "And knows it marches dark")
    }

    func testAMarchDarkIsToldOnlyWhereItIsSeenCloseBy() throws {
        var (state, me, unit) = try marching()
        let other = try XCTUnwrap(state.livingHouses.first { $0.id != me && state.watchers(for: me).contains($0.id) == false }).id
        let afar = try seenFromAfar(by: other, in: state)
        let close = state.closeSight(for: other), seen = state.visibility(for: other)
        let near = try XCTUnwrap(state.map.hexes.first { hex in
            state.map.index(of: hex).map { close[$0] && seen[$0] } == true && state.map[hex]?.terrain.isWater == false
        })
        let moved = GameEvent.moved(unit: unit, path: [afar, near])
        XCTAssertEqual(state.events([moved], heardBy: other), [moved], "Lit, told wherever seen")
        _ = try state.perform(.torches(unit: unit, lit: false), as: me)
        XCTAssertEqual(state.events([moved], heardBy: other), [.moved(unit: unit, path: [near])], "Dark, only where seen close by")
        XCTAssertTrue(state.events([.moved(unit: unit, path: [afar])], heardBy: other).isEmpty)
        XCTAssertEqual(state.events([moved], heardBy: me), [moved], "Its own House is told all its march")
    }

    /// A steward's company at war strikes a foe's company it sees close
    /// enough; one marching dark two tiles off it doesn't make out.
    func testAStewardStrikesNoCompanyMarchingDarkThatItCantMakeOut() throws {
        func turned(dark: Bool) throws -> Bool {
            var (state, me, unit) = try marching("torches against a steward")
            let steward = try XCTUnwrap(state.livingHouses.first { $0.id != me && !$0.isPlayer }).id
            state.setStance(.war, between: steward, and: me, by: steward)
            let seat = try XCTUnwrap(state.seat(of: steward)).position
            // The steward's spears two tiles out from their seat, the keeper's
            // two tiles on from them, on open ground none of the steward's
            // other companies or holds stands within a tile of.
            func open(_ hex: Hex) -> Bool {
                state.map[hex]?.terrain.isPassable == true && state.map[hex]?.terrain.isWater == false
                    && state.unit(at: hex) == nil && state.hold(at: hex) == nil
            }
            let others = state.units(of: steward).map(\.position) + state.holds(of: steward).map(\.position)
            var pair: (Hex, Hex)?
            for theirs in seat.spiral(4) where theirs.distance(to: seat) == 2 && open(theirs) {
                for mine in theirs.spiral(2) where mine.distance(to: theirs) == 2 && open(mine)
                    && others.allSatisfy({ $0.distance(to: mine) > GameState.darkSight }) {
                    pair = (theirs, mine)
                    break
                }
                if pair != nil { break }
            }
            let (theirs, mine) = try XCTUnwrap(pair, "Ground for the two")
            let spear = try XCTUnwrap(state.placeUnit(.spear, tier: 1, for: steward, near: theirs))
            state.units[try XCTUnwrap(state.unitIndex(spear.id))].position = theirs
            state.units[try XCTUnwrap(state.unitIndex(unit))].position = mine
            if dark { _ = try state.perform(.torches(unit: unit, lit: false), as: me) }
            let index = try XCTUnwrap(state.map.index(of: mine))
            XCTAssertTrue(state.visibility(for: steward)[index], "In the steward's sight")
            XCTAssertEqual(state.closeSight(for: steward)[index], false, "But not close by")
            _ = state.stewardTurn(for: steward)
            return state.field(of: unit) != nil || state.unit(spear.id).map { $0.position.distance(to: mine) <= 1 } == true
        }
        XCTAssertTrue(try turned(dark: false), "Lit, struck at")
        XCTAssertFalse(try turned(dark: true), "Dark, not made out")
    }

    func testTheDarkIsForgottenWithTheCompanyAndKeptWithTheRealm() throws {
        var realm = RealmState(name: "The Nullmere", seed: "torches kept", seats: 6, radius: 18, watchLength: 600, now: 0)
        _ = try realm.arrive("id-ama", name: "Ama", now: 1)
        let me = try XCTUnwrap(realm.world.houses.first { $0.isPlayer }).id
        let companies = realm.world.units(of: me).map(\.id).sorted()
        XCTAssertGreaterThanOrEqual(companies.count, 2)
        for id in companies.prefix(2).reversed() { _ = try realm.world.perform(.torches(unit: id, lit: false), as: me) }
        XCTAssertEqual(realm.world.unlit, Array(companies.prefix(2)), "Kept in order")
        let parts = try realm.parts(using: Scene.encoder)
        XCTAssertEqual(try RealmState(parts: parts), realm, "The realm keeps which march dark")
        // A company gone is forgotten as the watch turns.
        realm.world.units.removeAll { $0.id == companies[0] }
        _ = realm.world.endWatch()
        XCTAssertEqual(realm.world.unlit, [companies[1]])
        realm.world.units.removeAll { $0.id == companies[1] }
        _ = realm.world.endWatch()
        XCTAssertNil(realm.world.unlit)
    }
}
