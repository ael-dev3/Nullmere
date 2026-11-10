import Foundation
import XCTest
@testable import NullmereCore

/// The steward who kept a House welcoming its keeper the first time they
/// take it up, for a device's own model to give: only what the House knows
/// (how long the stewards kept it, its seat and holds, its heritage, how it
/// stands in strength, its wars and pacts, an omen on the realm); a
/// greeting, never an order, and no word the voices keep from.
final class StewardWelcomeTests: XCTestCase {
    private func taken(after watches: Int, seed: String = "the steward's welcome") -> GameState {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 5, radius: 16, keepers: 1))
        for _ in 0..<watches {
            _ = state.stewardTurn(for: state.player)
            _ = state.endWatch()
        }
        return state
    }

    func testTheStewardTellsWhatTheHouseHoldsAndHowItStands() throws {
        let state = taken(after: 12)
        let me = state.player
        let view = state.view(for: me)
        let welcome = try XCTUnwrap(view.stewardWelcome(for: me))
        let title = view.houses[me].title
        XCTAssertEqual(welcome.task, Voicing.stewardTask)
        XCTAssertEqual(welcome.facts.first, "The stewards kept \(title) until watch \(view.watch), and give it to its keeper now.")
        let seat = try XCTUnwrap(view.seat(of: me))
        XCTAssertTrue(welcome.facts.contains { $0.hasPrefix("Its seat is \(seat.name), by the Still") }, welcome.facts.joined(separator: "\n"))
        let heritage = view.heritage(of: me)
        XCTAssertTrue(welcome.facts.contains("It comes of \(heritage.title): \(heritage.strengths[0]), and \(heritage.strengths[1])."))
        XCTAssertTrue(welcome.facts.contains { $0.hasPrefix("Of \(GameState.counted(view.livingHouses.count)) Houses around the lake, ") })
        let wars = view.livingHouses.filter { $0.id != me && view.stance(me, $0.id) == .war }
        XCTAssertTrue(welcome.facts.contains(wars.isEmpty ? "It is at war with no House." : "It is at war with " + listed(wars.map(\.title).prefix(6).map { $0 }) + "."))
        if let omen = view.currentOmen {
            XCTAssertTrue(welcome.facts.contains("An omen lies on the realm, \(omen.kind.title): \(omen.kind.effect)"))
        }
        XCTAssertTrue(welcome.prompt.hasPrefix(Voicing.stewardTask))
        XCTAssertTrue(Voicing.stewardTask.contains("Propose nothing and promise nothing"), "a greeting, never an order")
        // Never a word the voices keep from.
        for fact in welcome.facts + [Voicing.stewardTask] {
            let words = Set(fact.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
            XCTAssertTrue(words.isDisjoint(with: ["level", "levels", "turn", "turns", "game", "player", "rule"]), fact)
        }
    }

    func testAHouseTakenAsTheAgeOpensIsSaidSo() throws {
        let state = taken(after: 0)
        let welcome = try XCTUnwrap(state.stewardWelcome(for: state.player))
        XCTAssertEqual(welcome.facts.first, "\(state.houses[state.player].title) passes to its keeper as the age opens.")
        XCTAssertNil(state.stewardWelcome(for: 9_999), "no welcome for a House that is not")
    }

    func testStrengthIsToldAsItStands() throws {
        let state = taken(after: 6)
        let me = state.player
        let welcome = try XCTUnwrap(state.stewardWelcome(for: me))
        let stronger = state.livingHouses.filter { state.strength(of: $0.id) > state.strength(of: me) }.count
        let line = try XCTUnwrap(welcome.facts.first { $0.hasPrefix("Of ") })
        switch stronger {
        case 0: XCTAssertTrue(line.hasSuffix("none is stronger than \(state.houses[me].title)."), line)
        case 1: XCTAssertTrue(line.contains("one is stronger"), line)
        default: XCTAssertTrue(line.contains("\(stronger) are stronger"), line)
        }
    }
}
