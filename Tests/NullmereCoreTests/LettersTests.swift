import Foundation
import XCTest
@testable import NullmereCore

/// Letters to the age to come: sealed by a keeper in a hold of theirs, once
/// an age, for moonsalt; gone down with the hold as the age ends; found in
/// the next by the first company to search that drowned ruin, the Chronicle
/// telling every House its words.
final class LettersTests: XCTestCase {
    private func keeperWorld(_ seed: String) throws -> (GameState, me: Int, seat: Hold) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        state.houses[me].stock.moonsalt = 100
        return (state, me, try XCTUnwrap(state.seat(of: me)))
    }

    func testAKeeperSealsALetterOnceAnAge() throws {
        var (state, me, seat) = try keeperWorld("a letter sealed")
        let other = try XCTUnwrap(state.holds.first { $0.owner != me })
        let steward = other.owner
        XCTAssertEqual(state.sealRefusal("Remember us.", in: other.id, as: steward), .notAKeeper, "Stewards seal none")
        XCTAssertEqual(state.sealRefusal("Remember us.", in: other.id, as: me), .notYours)
        XCTAssertEqual(state.sealRefusal("Remember us.", in: 9_999, as: me), .unknownHold)
        XCTAssertEqual(state.sealRefusal("   ", in: seat.id, as: me), .nothingToSay)
        var barred = state
        _ = barred.bar(me, watches: 3)
        XCTAssertEqual(barred.sealRefusal("Remember us.", in: seat.id, as: me), .barredFromWords(until: state.watch + 3),
                       "Barred from the Words, no letter for every House to read")
        let moonsalt = state.houses[me].stock.moonsalt
        let events = try state.perform(.sealLetter(words: "We held the ford at the dark of the moon.", hold: seat.id), as: me)
        XCTAssertEqual(events, [.letterSealed(hold: seat.id, by: me)])
        XCTAssertEqual(state.houses[me].stock.moonsalt, moonsalt - GameState.letterCost.moonsalt)
        let letter = try XCTUnwrap(state.letter(sealedBy: me))
        XCTAssertEqual(letter.words, "We held the ford at the dark of the moon.")
        XCTAssertEqual(letter.hold, seat.name)
        XCTAssertEqual(letter.from, state.houses[me].title)
        XCTAssertNil(letter.age, "Its age is the water's to give")
        XCTAssertEqual(state.sealRefusal("And again.", in: seat.id, as: me), .letterSealed)
        XCTAssertEqual(RuleError.letterSealed.description, "Your House has sealed its letter to the age to come; one an age.")
        XCTAssertTrue(state.tidings(of: events[0], for: me)?.text.hasPrefix("Your letter is sealed under the stones of \(seat.name)") == true)
        XCTAssertNil(state.tidings(of: events[0], for: steward))
        // No other House knows of it, nor hears it sealed.
        XCTAssertEqual(state.view(for: me).lettersSealed, [letter])
        XCTAssertEqual(state.view(for: steward).lettersSealed, [])
        XCTAssertEqual(state.events(events, heardBy: steward), [])
        var poor = state
        poor.letters = nil
        poor.houses[me].stock.moonsalt = 5
        XCTAssertEqual(poor.sealRefusal("Remember us.", in: seat.id, as: me), .shortOf(Stock(moonsalt: 15)))
        // Kept with the world.
        let kept = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(kept.lettersSealed, state.lettersSealed)
    }

    /// As the age ends the letter goes down with its hold, laid among the
    /// first of the drowned however small; the first company to search the
    /// ruin in the next age finds it, and every House hears its words.
    func testTheNextAgeFindsTheLetterInItsDrownedHold() throws {
        var (before, me, _) = try keeperWorld("an age that wrote")
        // The keeper's hold.
        let small = try XCTUnwrap(before.holds.filter { $0.owner == me }.first)
        _ = try before.perform(.sealLetter(words: "The ford is shallow at the third stone.", hold: small.id), as: me)
        var next = RealmState.world(seed: "an age that wrote", age: 2, seats: 4, radius: 18)
        next.drown(before, age: 2)
        let letter = try XCTUnwrap(next.lettersOfOld.first)
        XCTAssertEqual(next.lettersOfOld.count, 1)
        XCTAssertEqual(letter.age, 1)
        let lies = try XCTUnwrap(letter.at)
        XCTAssertNotNil(next.drowned(at: lies), "With a drowned hold")
        XCTAssertEqual(next.drownedHolds.map(\.position).min { ($0.distance(to: small.position), $0) < ($1.distance(to: small.position), $1) }, lies,
                       "With its own hold, or the nearest the water laid")
        XCTAssertTrue(next.chronicle.contains { $0.text.hasPrefix("A letter sealed in the age before lies with its drowned hold") })
        XCTAssertEqual(next.lettersUnfound(at: lies).count, 1)
        XCTAssertTrue(next.lettersSealed.isEmpty, "The new age has sealed none yet")
        XCTAssertEqual(letter.told(in: next),
                       "A letter of the first age, sealed by \(before.houses[me].title), lies within, unread, for whoever searches the ruin.")

        // Unfound, a House sees it lie there only on ground it knows, and never its words.
        let finder = try XCTUnwrap(next.houses.indices.first)
        var view = next.view(for: finder)
        XCTAssertTrue(view.lettersOfOld.allSatisfy { $0.words.isEmpty })
        next.houses[finder].explored[try XCTUnwrap(next.map.index(of: lies))] = true
        view = next.view(for: finder)
        XCTAssertEqual(view.lettersOfOld.map(\.id), [letter.id])
        XCTAssertEqual(view.lettersOfOld.first?.words, "")

        // A company of the finder's searches the ruin.
        let beside = try XCTUnwrap(lies.neighbors.first { next.map[$0]?.terrain.isPassable == true && next.isClear($0) })
        let company = next.put(.spear, of: finder, at: beside)
        next.houses[finder].isPlayer = true
        let events = try next.perform(.move(unit: company, to: lies), as: finder)
        let found = try XCTUnwrap(events.lazy.compactMap { event -> Letter? in
            if case .letterFound(let letter, _) = event { return letter } else { return nil }
        }.first)
        XCTAssertEqual(found.words, "The ford is shallow at the third stone.")
        XCTAssertEqual(found.foundBy, finder)
        XCTAssertTrue(next.lettersUnfound(at: lies).isEmpty, "Found once")
        XCTAssertEqual(found.told(in: next), "A letter of the first age, sealed by \(before.houses[me].title), "
                       + "found by \(next.houses[finder].title): “The ford is shallow at the third stone.”")
        let event = GameEvent.letterFound(letter: found, by: finder)
        XCTAssertEqual(next.tidings(of: event, for: finder)?.text,
                       "Among the drowned stones of \(small.name) your company finds a letter of the first age, sealed by \(before.houses[me].title): "
                       + "“The ford is shallow at the third stone.”")
        let other = (finder + 1) % next.houses.count
        XCTAssertEqual(next.tidings(of: event, for: other)?.text,
                       "\(next.houses[finder].title) finds a letter of the first age among the drowned stones of \(small.name): "
                       + "“The ford is shallow at the third stone.”")
        XCTAssertEqual(next.events([event], heardBy: other), [event], "The whole realm hears it")
        XCTAssertTrue(next.chronicle.last { $0.kind == .discovery }?.text.contains("finds a letter of the first age") == true)
        next.houses[other].explored[try XCTUnwrap(next.map.index(of: lies))] = true
        XCTAssertEqual(next.view(for: other).lettersOfOld.first { $0.id == letter.id }?.words, found.words, "Found, its words are every House's")
        XCTAssertEqual(next.problems(), [])
    }

    /// With nothing sealed, an age drowns as it always did, and a world of
    /// stewards seals nothing.
    func testWithoutLettersTheAgesGoAsTheyDid() throws {
        let before = GameState(settings: GameSettings(seedText: "no letters", houseCount: 4, radius: 18))
        var next = RealmState.world(seed: "no letters", age: 2, seats: 4, radius: 18)
        var plain = next
        next.drown(before, age: 2)
        plain.drown(before, age: 2)
        XCTAssertEqual(next, plain)
        XCTAssertNil(next.oldLetters)
        var stewards = GameState(settings: GameSettings(seedText: "stewards write nothing", houseCount: 4, radius: 18))
        for _ in 0..<30 { _ = stewards.endWatch() }
        XCTAssertNil(stewards.letters)
    }
}
