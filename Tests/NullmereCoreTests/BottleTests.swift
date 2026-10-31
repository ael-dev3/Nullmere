import Foundation
import XCTest
@testable import NullmereCore

/// Bottles on the lake: words set on the water from a hold on the shore,
/// carried by the current, washed up, and read by whoever finds them; the
/// words hidden from everyone else; a bottle too long afloat sinks.
final class BottleTests: XCTestCase {
    /// A lake with two keepers, the first's seat beside the water.
    private func world() throws -> (GameState, me: Int, other: Int, hold: Int) {
        var state = Scene.world("bottles", houses: 4, radius: 16)
        let me = state.player
        let other = (me + 1) % 4
        state.houses[other].isPlayer = true
        state.houses[me].stock = Stock(grain: 500, timber: 100, stone: 100, moonsalt: 10)
        // A hold of the keeper's on the shore.
        let shore = try XCTUnwrap(state.map.hexes.first { hex in
            state.map[hex]?.terrain.isSettleable == true && state.hold(at: hex) == nil && state.unit(at: hex) == nil
                && state.map.neighbors(of: hex).contains { [.still, .shallows].contains(state.map[$0]?.terrain) }
        })
        let hold = Hold(id: state.takeID(), name: "Saltwatch", owner: me, position: shore, isSeat: false, foundedWatch: 1)
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

    func testABottleIsSetOnTheWaterAndCarriedToAShore() throws {
        var (state, me, other, hold) = try world()
        let grain = state.houses[me].stock.grain
        let events = try state.perform(.castBottle(words: "  The ford is false.  ", from: hold, signed: true), as: me)
        let bottle = try XCTUnwrap(state.bottlesOnTheLake.last)
        XCTAssertEqual(events, [.bottleCast(bottle: bottle.id, from: me, at: bottle.position)])
        XCTAssertEqual(bottle.words, "The ford is false.")
        XCTAssertEqual(state.map[bottle.position]?.terrain.isWater, true, "On the water beside the hold")
        XCTAssertEqual(state.houses[me].stock.grain, grain - GameState.bottleCost.grain)
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.text, "Your bottle is on the water; the current will carry it where it will.")

        // Another keeper sees it afloat where they see the water, but not its words.
        XCTAssertTrue(state.view(for: other).bottlesOnTheLake.allSatisfy { $0.words.isEmpty })
        XCTAssertEqual(state.view(for: me).bottlesOnTheLake.first?.words, "The ford is false.")

        // Watch by watch it drifts, until it washes up and someone finds it.
        var found: (Bottle, Int)?
        for _ in 0..<GameState.bottleAfloat where found == nil {
            for event in state.endWatch() {
                if case .bottleFound(let bottle, let by) = event { found = (bottle, by) }
            }
            XCTAssertEqual(state.problems(), [])
        }
        let (washed, finder) = try XCTUnwrap(found, "Found within its while afloat, or sunk: \(state.bottlesOnTheLake)")
        XCTAssertTrue(washed.ashore)
        XCTAssertFalse(state.map[washed.position]?.terrain.isWater ?? true, "On the shore")
        XCTAssertEqual(state.bottlesOnTheLake.first { $0.id == washed.id }?.foundBy, finder)
        if finder != me {
            XCTAssertEqual(state.tidings(of: .bottleFound(bottle: washed, by: finder), for: me)?.text,
                           "A bottle of yours washed up and was found by \(state.houses[finder].title).")
        }
        XCTAssertEqual(state.tidings(of: .bottleFound(bottle: washed, by: finder), for: finder)?.text,
                       "A bottle washed up by your hold or company, sealed by \(state.houses[me].title): “The ford is false.”")
        XCTAssertTrue(state.events([.bottleFound(bottle: washed, by: finder)], heardBy: finder).count == 1)
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: data), state)
    }

    func testOnlyAKeepersHoldOnTheWaterSetsOneAWatch() throws {
        var (state, me, other, hold) = try world()
        XCTAssertEqual(refusal(.castBottle(words: "Hail", from: hold, signed: false), in: state, as: other), .notYours)
        XCTAssertEqual(refusal(.castBottle(words: "Hail", from: 987_654, signed: false), in: state, as: me), .unknownHold)
        XCTAssertEqual(refusal(.castBottle(words: "   ", from: hold, signed: false), in: state, as: me), .nothingToSay)
        let inland = try XCTUnwrap(state.holds.first { $0.owner == me && $0.id != hold && state.castingWater(beside: $0) == nil })
        XCTAssertEqual(refusal(.castBottle(words: "Hail", from: inland.id, signed: false), in: state, as: me), .noWaterBeside)
        let steward = try XCTUnwrap(state.houses.indices.first { !state.houses[$0].isPlayer })
        XCTAssertEqual(refusal(.castBottle(words: "Hail", from: hold, signed: false), in: state, as: steward), .notAKeeper)
        _ = try state.perform(.castBottle(words: "Hail", from: hold, signed: false), as: me)
        XCTAssertEqual(refusal(.castBottle(words: "Again", from: hold, signed: false), in: state, as: me), .castThisWatch)
        state.houses[me].stock = .zero
        state.watch += 1
        XCTAssertEqual(refusal(.castBottle(words: "Again", from: hold, signed: false), in: state, as: me),
                       .shortOf(Stock.zero.shortfall(for: GameState.bottleCost)))
        XCTAssertEqual(RuleError.noWaterBeside.description, "No water lies beside this hold to set a bottle on.")
        XCTAssertEqual(RuleError.castThisWatch.description, "Your House has set a bottle on the water this watch; another at the next.")
    }

    func testABottleTooLongAfloatSinksAndAnUnsignedOneIsAnonymous() throws {
        var (state, me, other, hold) = try world()
        _ = try state.perform(.castBottle(words: "Who reads this", from: hold, signed: false), as: me)
        let id = try XCTUnwrap(state.bottlesOnTheLake.last?.id)
        // Out on the deep water, far from any shore, it never washes up.
        let index = try XCTUnwrap(state.bottles?.firstIndex { $0.id == id })
        state.bottles![index].position = try XCTUnwrap(state.moonWater?.hex)
        state.watch = state.bottles![index].cast + GameState.bottleAfloat
        _ = state.driftBottles()
        XCTAssertFalse(state.bottlesOnTheLake.contains { $0.id == id && !$0.ashore }, "Sunk, or washed up at last")

        // Unsigned, its finder is not told whose it was.
        let unsigned = Bottle(id: 1, from: me, signed: false, words: "Who reads this", cast: 1, position: .origin, ashore: true, foundBy: other)
        XCTAssertEqual(state.tidings(of: .bottleFound(bottle: unsigned, by: other), for: other)?.text,
                       "A bottle washed up by your hold or company, unsigned: “Who reads this”")
        XCTAssertNil(state.tidings(of: .bottleFound(bottle: unsigned, by: other), for: (me + 2) % 4), "Told to none else")
        XCTAssertNil(state.tidings(of: .bottleCast(bottle: 1, from: me, at: .origin), for: other))
        var unsound = state
        unsound.bottles = [Bottle(id: 2, from: me, signed: true, words: "x", cast: 1, position: Hex(400, 400))]
        XCTAssertEqual(unsound.problems().filter { $0.hasPrefix("Bottle 2") }.count, 1)
    }
}
