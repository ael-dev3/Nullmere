import Foundation
import XCTest
@testable import NullmereCore

/// The Sundering, kingdom against kingdom: the lake's Houses stand for a
/// season as two kingdoms by the shore their seats stand on; deeds done
/// across the shores score for the striker's kingdom, and the kingdom that
/// prevails shares its spoils, its foremost House hailed.
final class SunderingTests: XCTestCase {
    private func world() -> GameState {
        Scene.world("the sundering", houses: 6, radius: 20)
    }

    /// A House of each shore.
    private func across(_ state: GameState) throws -> (east: Int, west: Int) {
        let shores = state.houses.map { state.seat(of: $0.id).map { Shore.of($0.position) } }
        let east = try XCTUnwrap(shores.firstIndex(of: .eastern))
        let west = try XCTUnwrap(shores.firstIndex(of: .western))
        return (east, west)
    }

    func testTheShoresAndTheSeasonsCourse() {
        XCTAssertEqual(Shore.of(Hex(5, 0)), .eastern)
        XCTAssertEqual(Shore.of(Hex(-5, 0)), .western)
        XCTAssertEqual(Shore.eastern.other, .western)
        XCTAssertEqual(Shore.western.other, .eastern)
        XCTAssertEqual(Shore.allCases.map(\.title), ["the Eastern Shore", "the Western Shore"])
        XCTAssertTrue(Sundering.begins(at: 55))
        XCTAssertTrue(Sundering.begins(at: 145))
        XCTAssertFalse(Sundering.begins(at: 54))
        XCTAssertFalse(Sundering.begins(at: 100))
        XCTAssertEqual(Sundering.next(from: 0), 55)
        XCTAssertEqual(Sundering.next(from: 55), 55)
        XCTAssertEqual(Sundering.next(from: 56), 145)
        XCTAssertEqual(Sundering.next(from: 145), 145)
    }

    func testItBeginsWithEveryHouseToTheShoreItsSeatStandsOn() throws {
        var state = world()
        state.watch = Sundering.first - 1
        XCTAssertEqual(state.turnSundering(), [], "Not yet")
        state.watch = Sundering.first
        let events = state.turnSundering()
        XCTAssertEqual(events, [.sunderingBegun(ends: Sundering.first + Sundering.lasts)])
        let sundering = try XCTUnwrap(state.sundering)
        for house in state.houses {
            XCTAssertEqual(sundering.shore(of: house.id), state.seat(of: house.id).map { Shore.of($0.position) })
        }
        XCTAssertNil(sundering.shore(of: 99))
        XCTAssertTrue(sundering.points.allSatisfy { $0 == 0 })
        XCTAssertFalse(sundering.settled)
        XCTAssertTrue(state.chronicle.contains { $0.text.hasPrefix("The Sundering begins: the Eastern and the Western Shore war as kingdoms") })
        let (east, _) = try across(state)
        XCTAssertEqual(state.tidings(of: events[0], for: east)?.text,
                       "The Sundering begins: the Eastern and the Western Shore war as kingdoms until the \(ordinal(67)) watch. "
                       + "You stand with the Eastern Shore: troops of the Western Shore slain, its holds taken and its alliances' works "
                       + "torn down count for your kingdom.")
        XCTAssertEqual(state.events(events, heardBy: east), events, "Heard by all")
        XCTAssertEqual(state.view(for: east).sundering, state.sundering, "Its tally is known to all")
        XCTAssertEqual(state.problems(), [])
        // A House fallen before it begins stands with neither shore.
        var fallen = world()
        fallen.houses[1].isEliminated = true
        fallen.watch = Sundering.first
        _ = fallen.turnSundering()
        XCTAssertNil(fallen.sundering?.shore(of: 1))
        XCTAssertEqual(fallen.tidings(of: .sunderingBegun(ends: 67), for: 1)?.text,
                       "The Sundering begins: the Eastern and the Western Shore war as kingdoms until the \(ordinal(67)) watch.")
    }

    func testDeedsAcrossTheShoresScoreForTheStrikersKingdom() throws {
        var state = world()
        state.watch = Sundering.first
        _ = state.turnSundering()
        let (east, west) = try across(state)
        let ally = try XCTUnwrap(state.houses.indices.first { $0 != east && state.sundering?.shore(of: $0) == .eastern })
        func blow(_ attacker: Int, _ defender: Int, slain: Int?, fell: Bool, ward: Bool = false) -> GameEvent {
            .battle(Battle(attacker: 1, attackerOwner: attacker, attackerKind: .spear, defender: ward ? nil : 2, defenderOwner: defender,
                           defenderKind: ward ? nil : .bow, hold: ward ? 3 : nil, at: .origin, damageDealt: 30, damageTaken: 5,
                           attackerFell: false, defenderFell: fell, slain: slain, lost: 40))
        }
        state.tallySundering([blow(east, west, slain: 450, fell: false)])
        XCTAssertEqual(state.sundering?.points[east], 4, "A point a hundred slain")
        state.tallySundering([blow(west, east, slain: 1_000, fell: true)])
        XCTAssertEqual(state.sundering?.points[west], 15, "And five for a company felled")
        state.tallySundering([blow(east, ally, slain: 900, fell: true), blow(east, west, slain: nil, fell: true, ward: true)])
        XCTAssertEqual(state.sundering?.points[east], 4, "Nothing for a blow on its own shore, or on a ward")
        state.tallySundering([.holdCaptured(hold: 1, from: west, by: east)])
        XCTAssertEqual(state.sundering?.points[east], 29, "Twenty-five for a hold taken")
        // An alliance's works torn down across the shores.
        _ = try state.perform(.foundAlliance(name: "The West Pact"), as: west)
        let alliance = try XCTUnwrap(state.alliance(of: west)).id
        state.tallySundering([.standardTorn(standard: 1, alliance: alliance, by: east, at: .origin),
                              .hallTorn(hall: 2, alliance: alliance, by: east, at: .origin),
                              .storehouseTorn(storehouse: 3, alliance: alliance, by: east, at: .origin, carried: .zero),
                              .standardTorn(standard: 4, alliance: alliance, by: nil, at: .origin)])
        XCTAssertEqual(state.sundering?.points[east], 29 + 5 + 30 + 20)
        XCTAssertEqual(state.sundering?.score(of: .eastern), 84)
        XCTAssertEqual(state.sundering?.score(of: .western), 15)
        XCTAssertEqual(state.sundering?.leading, .eastern)
        XCTAssertEqual(state.sundering?.foremost(of: .eastern), east)
        XCTAssertEqual(state.sundering?.foremost(of: .western), west)
        // Past its end, nothing more counts.
        var late = state
        late.watch = late.sundering!.ends
        late.tallySundering([.holdCaptured(hold: 1, from: west, by: east)])
        XCTAssertEqual(late.sundering?.points[east], 84)
        // Through the rules: a real blow across the shores counts.
        var fought = world()
        fought.watch = Sundering.first
        _ = fought.turnSundering()
        let seat = try XCTUnwrap(fought.seat(of: east))
        let at = try XCTUnwrap(fought.freeHex(near: seat.position, within: 2...3))
        let spear = fought.put(.spear, tier: 5, of: east, at: at)
        let foe = fought.put(.bow, tier: 1, of: west, at: try XCTUnwrap(fought.freeHex(near: at, within: 1...1)))
        _ = try fought.declareWar(by: east, on: west)
        let struck = try fought.perform(.attack(unit: spear, target: try XCTUnwrap(fought.unit(foe)).position), as: east)
        let slain = try XCTUnwrap(struck.compactMap { event -> Int? in
            if case .battle(let battle) = event { return battle.slain }
            return nil
        }.first)
        let fell = fought.unit(foe) == nil
        XCTAssertEqual(fought.sundering?.points[east], slain / 100 + (fell ? 5 : 0))
    }

    func testTheKingdomThatPrevailsSharesItsSpoilsAndItsForemostIsHailed() throws {
        var state = world()
        state.watch = Sundering.first
        _ = state.turnSundering()
        let (east, west) = try across(state)
        state.sundering!.points[east] = 40
        state.sundering!.points[west] = 25
        let easterners = state.houses.indices.filter { state.sundering?.shore(of: $0) == .eastern }
        let before = state.houses.map(\.stock)
        state.watch = state.sundering!.ends - 1
        XCTAssertEqual(state.turnSundering(), [], "Not until its last watch is out")
        state.watch = state.sundering!.ends
        let events = state.turnSundering()
        XCTAssertEqual(events.first, .sunderingEnded(winner: .eastern, eastern: 40, western: 25, hailed: east))
        XCTAssertTrue(state.sundering?.settled == true, "Kept, settled, until the next")
        for house in easterners {
            let gained = Stock(grain: state.houses[house].stock.grain - before[house].grain)
            XCTAssertGreaterThanOrEqual(gained.grain, 0)
            XCTAssertTrue(events.contains(.itemsGiven(house: house, kind: .wardStone, count: 1)), "\(house) shares the spoils")
        }
        XCTAssertFalse(events.contains { if case .itemsGiven(west, _, _) = $0 { return true } else { return false } }, "None for the other")
        XCTAssertEqual(state.items(.wardStone, of: east), 1)
        XCTAssertTrue(state.chronicle.contains {
            $0.text == "The Sundering ends: the Eastern Shore prevails, 40 to 25; \(state.houses[east].title) is hailed its sword."
        })
        let ended = events[0]
        XCTAssertEqual(state.tidings(of: ended, for: east)?.text,
                       "The Sundering ends: your kingdom, the Eastern Shore, prevails, 40 to 25; its Houses share its spoils. "
                       + "Your House is hailed its sword.")
        let other = try XCTUnwrap(easterners.first { $0 != east })
        XCTAssertEqual(state.tidings(of: ended, for: other)?.text,
                       "The Sundering ends: your kingdom, the Eastern Shore, prevails, 40 to 25; its Houses share its spoils.")
        XCTAssertEqual(state.tidings(of: ended, for: west)?.text, "The Sundering ends: the Eastern Shore prevails, 40 to 25.")
        XCTAssertEqual(state.tidings(of: ended, for: west)?.tone, .bad)
        XCTAssertEqual(state.tidings(of: ended, for: 99)?.tone, .neutral)
        XCTAssertEqual(state.turnSundering(), [], "Settled once")
        // The next begins in its time, in its place.
        state.watch = Sundering.first + Sundering.every
        XCTAssertEqual(state.turnSundering(), [.sunderingBegun(ends: state.watch + Sundering.lasts)])
        XCTAssertEqual(state.sundering?.begins, state.watch)
        XCTAssertEqual(state.sundering?.settled, false)

        // Neither ahead: no spoils, and it says so.
        var even = world()
        even.watch = Sundering.first
        _ = even.turnSundering()
        even.watch = even.sundering!.ends
        let drawn = even.turnSundering()
        XCTAssertEqual(drawn, [.sunderingEnded(winner: nil, eastern: 0, western: 0, hailed: nil)])
        XCTAssertNil(even.sundering?.leading)
        XCTAssertNil(even.sundering?.foremost(of: .eastern))
        XCTAssertEqual(even.tidings(of: drawn[0], for: 0)?.text, "The Sundering ends with neither shore ahead, 0 to 0.")
        XCTAssertTrue(even.chronicle.contains { $0.text == "The Sundering ends with neither shore ahead, 0 to 0." })
        // Ahead with none of its Houses scoring: no House is hailed.
        var quiet = world()
        quiet.watch = Sundering.first
        _ = quiet.turnSundering()
        let (qEast, _) = try across(quiet)
        quiet.sundering!.points[qEast] = 3
        quiet.houses[qEast].isEliminated = true
        quiet.watch = quiet.sundering!.ends
        XCTAssertEqual(quiet.turnSundering().first, .sunderingEnded(winner: .eastern, eastern: 3, western: 0, hailed: nil))
        XCTAssertTrue(quiet.chronicle.contains { $0.text == "The Sundering ends: the Eastern Shore prevails, 3 to 0." })
    }

    func testASunderingOutOfTrueIsFoundAndKeptInSaves() throws {
        var state = world()
        state.watch = Sundering.first
        _ = state.turnSundering()
        let kept = try JSONDecoder().decode(GameState.self, from: try JSONEncoder().encode(state))
        XCTAssertEqual(kept.sundering, state.sundering)
        let older = try JSONDecoder().decode(GameState.self, from: try Scene.without(["sundering"], in: state))
        XCTAssertNil(older.sundering, "Saves from before it have none")
        state.sundering!.points[0] = -3
        state.sundering!.points.append(4)
        let problems = state.problems()
        XCTAssertTrue(problems.contains("The Sundering has points below none"), "\(problems)")
        XCTAssertTrue(problems.contains("The Sundering has points for 7 Houses of 6"), "\(problems)")
        state.sundering = Sundering(begins: 3, shores: [.eastern])
        XCTAssertTrue(state.problems().contains("The Sundering has shores for 1 Houses of 6"))
    }
}
