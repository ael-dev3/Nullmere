import Foundation
import XCTest
@testable import NullmereCore

/// The Remembering: at each half moon the lake sets every keeper's House a
/// riddle of the realm's own past, one name taken out of a line of its
/// Chronicle or of the age drowned beneath it, four to choose from; the
/// right one, answered once, brings moonsalt. Stewards are set none.
final class RememberingTests: XCTestCase {
    func testTheLakeSetsAKeeperARiddleOfItsPast() throws {
        var state = GameState(settings: GameSettings(seedText: "a riddle of the lake", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let other = (me + 1) % state.houses.count
        state.record(.capture, [other, me], "\(state.houses[other].title) takes Fennick from \(state.houses[me].title).")
        while GameState.moonAge(at: state.watch + 1) != 7 { _ = state.endWatch() }
        XCTAssertNil(state.riddles, "None before the half moon")
        let events = state.endWatch()
        XCTAssertTrue(events.contains(.riddleSet(house: me)))
        XCTAssertEqual(state.riddles?.count, 1, "Stewards are set none")
        let riddle = try XCTUnwrap(state.riddle(of: me))
        let answer = try XCTUnwrap(riddle.answer)
        XCTAssertEqual(riddle.set, state.watch)
        XCTAssertEqual(riddle.choices.count, 4)
        XCTAssertEqual(Set(riddle.choices).count, 4)
        XCTAssertTrue(riddle.choices.contains(answer))
        XCTAssertTrue(riddle.line.contains("———"))
        XCTAssertFalse(riddle.line.contains(answer), "The name taken out")
        XCTAssertFalse(riddle.isRight)

        // Its own, and its answer kept in the keeper's view until answered.
        XCTAssertNil(state.view(for: me).riddle(of: me)?.answer)
        XCTAssertNotNil(state.view(for: me).riddle(of: me))
        XCTAssertNil(state.view(for: other).riddle(of: me), "Another House's riddle is its own")
        XCTAssertTrue(state.tidings(of: .riddleSet(house: me), for: me)?.text.contains(riddle.line) == true)
        XCTAssertNil(state.tidings(of: .riddleSet(house: me), for: other))
        XCTAssertFalse(state.events(events, heardBy: other).contains(.riddleSet(house: me)))

        // Answered wrongly: told the name, nothing given, and answered once.
        var wrong = state
        let miss = try XCTUnwrap(riddle.choices.first { $0 != answer })
        let moonsalt = state.houses[me].stock.moonsalt
        XCTAssertEqual(try wrong.perform(.answerRiddle(miss), as: me), [.riddleAnswered(house: me, right: false, answer: answer)])
        XCTAssertEqual(wrong.houses[me].stock.moonsalt, moonsalt)
        XCTAssertEqual(wrong.riddleRefusal(answer, as: me), .answeredAlready)
        XCTAssertEqual(wrong.view(for: me).riddle(of: me)?.answer, answer, "Answered, the name is known")
        XCTAssertEqual(wrong.tidings(of: .riddleAnswered(house: me, right: false, answer: answer), for: me)?.text, "Not so: it was \(answer).")
        XCTAssertTrue(RuleError.answeredAlready.description.contains("next half moon"))

        // Answered rightly: moonsalt.
        XCTAssertEqual(state.riddleRefusal("No such House", as: me), .notApplicable)
        XCTAssertEqual(state.riddleRefusal(answer, as: other), .notApplicable, "Set no riddle")
        XCTAssertEqual(try state.perform(.answerRiddle(answer), as: me), [.riddleAnswered(house: me, right: true, answer: answer)])
        XCTAssertEqual(state.houses[me].stock.moonsalt, moonsalt + GameState.riddleReward.moonsalt)
        XCTAssertTrue(state.riddle(of: me)?.isRight == true)
        XCTAssertEqual(state.tidings(of: .riddleAnswered(house: me, right: true, answer: answer), for: me)?.tone, .good)
        XCTAssertNil(state.tidings(of: .riddleAnswered(house: me, right: true, answer: answer), for: other))
        let kept = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(kept.riddles, state.riddles)

        // The next half moon sets another in its place.
        while GameState.moonAge(at: state.watch + 1) != 22 { _ = state.endWatch() }
        _ = state.endWatch()
        XCTAssertEqual(state.riddle(of: me)?.set, state.watch)
        XCTAssertNil(state.riddle(of: me)?.answered)
    }

    /// The age drowned beneath this one is asked of too, once it holds the
    /// holds of four Houses or more; with no past to ask of, no riddle.
    func testTheDrownedAgeIsRemembered() throws {
        var state = GameState(settings: GameSettings(seedText: "a drowned riddle", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        state.chronicle = []
        state.watch = GameState.lunarMonth + 7
        XCTAssertNil(state.riddle(for: me), "No past to ask of")
        XCTAssertEqual(state.setRiddles(), [])
        XCTAssertNil(state.riddles)
        state.drowned = ["House Aske", "House Brine", "House Corrow"].enumerated().map { index, house in
            DrownedHold(position: Hex(index, 0), name: "Hold \(index)", house: house, age: 1, works: 3, spire: 0)
        }
        XCTAssertNil(state.riddle(for: me), "Three Houses are too few to choose among")
        state.drowned! += [DrownedHold(position: Hex(5, 0), name: "Dunmere", house: "House Dovet", age: 1, works: 9, spire: 1)]
        let riddle = try XCTUnwrap(state.riddle(for: me))
        XCTAssertTrue(riddle.line.hasPrefix("In the first age, ——— held "))
        XCTAssertEqual(Set(riddle.choices), ["House Aske", "House Brine", "House Corrow", "House Dovet"])
        XCTAssertEqual(state.setRiddles(), [.riddleSet(house: me)])
        // Not between the half moons.
        state.watch += 1
        XCTAssertEqual(state.setRiddles(), [])
    }

    /// Stewards are set no riddles, so a world of stewards goes as it always did.
    func testStewardsAreSetNone() {
        var state = GameState(settings: GameSettings(seedText: "no riddles", houseCount: 5, radius: 18))
        for _ in 0..<30 { _ = state.endWatch() }
        XCTAssertNil(state.riddles)
    }
}
