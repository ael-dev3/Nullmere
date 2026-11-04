import XCTest
@testable import NullmereCore

/// The Lyceum: the same five questions to every House twice in ten
/// watches, answered once and kept secret, judged and paid as it rises.
final class LyceumTests: XCTestCase {
    private func sitting() -> (GameState, Int, Int) {
        var state = GameState(settings: GameSettings(seedText: "lyceum", houseCount: 4, radius: 14, keepers: 2))
        let me = state.player
        let other = (me + 1) % state.houses.count
        state.houses[other].isPlayer = true
        state.watch = Lyceum.every * 3
        state.openLyceum()
        return (state, me, other)
    }

    func testTheSameQuestionsForAllDrawnFromTheLore() throws {
        let (state, me, other) = sitting()
        let questions = try XCTUnwrap(state.lyceumNow)
        XCTAssertEqual(questions.count, Lyceum.questions)
        XCTAssertEqual(state.view(for: me).lyceumNow, questions)
        XCTAssertEqual(state.view(for: other).lyceumNow, questions, "the same for every House")
        XCTAssertEqual(Set(questions.map(\.text)).count, Lyceum.questions, "five different questions")
        for question in questions {
            XCTAssertEqual(question.choices.count, 4)
            XCTAssertEqual(Set(question.choices).count, 4)
            XCTAssertTrue((0..<4).contains(question.answer))
            let right = question.choices[question.answer]
            let lore = Study.allCases.map { ($0.title, $0.effect) } + ItemKind.allCases.map { ($0.title, $0.effect) }
                + OmenKind.allCases.map { ($0.title, $0.effect) }
            XCTAssertTrue(lore.contains { $0.0 == right && question.text.contains($0.1) }, "\(right) is what \(question.text) asks")
        }
        XCTAssertNotEqual(state.lyceumQuestions(sitting: 3), state.lyceumQuestions(sitting: 4), "a new sitting, new questions")
        // Opened by the watch's turn itself.
        var turning = state
        turning.lyceumSet = nil
        turning.watch = Lyceum.every * 4 - 1
        _ = turning.turnLyceumAfterWatch()
        XCTAssertEqual(turning.lyceumNow, turning.lyceumQuestions(sitting: 4))
        var quiet = state
        quiet.watch += Lyceum.sits
        XCTAssertNil(quiet.lyceumNow, "it sits two watches in ten")
    }

    func testAnswersAreKeptSecretThenJudgedAndPaid() throws {
        var (state, me, other) = sitting()
        let questions = try XCTUnwrap(state.lyceumNow)
        // I answer all right; the other two right and the rest wrong.
        for (index, question) in questions.enumerated() {
            _ = try state.perform(.answerLyceum(question: index, choice: question.answer), as: me)
            _ = try state.perform(.answerLyceum(question: index, choice: index < 2 ? question.answer : (question.answer + 1) % 4), as: other)
        }
        XCTAssertThrowsError(try state.perform(.answerLyceum(question: 0, choice: 1), as: me)) {
            XCTAssertEqual($0 as? RuleError, .lyceumAnswered)
        }
        XCTAssertEqual(state.view(for: me).lyceumAnswers(of: me).compactMap { $0 }.count, Lyceum.questions)
        XCTAssertTrue(state.view(for: me).lyceumAnswers(of: other).allSatisfy { $0 == nil }, "another's answers are theirs")
        let before = (state.houses[me].stock.moonsalt, state.houses[other].stock.moonsalt)
        state.watch += Lyceum.sits - 1
        let events = state.turnLyceumAfterWatch()
        guard case .lyceumJudged(let standings)? = events.first else { return XCTFail("\(events)") }
        XCTAssertEqual(standings.map(\.house), [me, other])
        XCTAssertEqual(standings.map(\.right), [5, 2])
        XCTAssertEqual(standings[0].moonsalt, 5 * Lyceum.perAnswer + Lyceum.prizes[0])
        XCTAssertEqual(state.houses[me].stock.moonsalt - before.0, standings[0].moonsalt)
        XCTAssertEqual(state.houses[other].stock.moonsalt - before.1, 2 * Lyceum.perAnswer + Lyceum.prizes[1])
        XCTAssertNil(state.lyceumBook)
        XCTAssertNotNil(state.tidings(of: events[0], for: other))
        XCTAssertFalse(state.events(events, heardBy: other).isEmpty, "told to all")
        XCTAssertThrowsError(try state.perform(.answerLyceum(question: 0, choice: 0), as: me)) {
            XCTAssertEqual($0 as? RuleError, .lyceumNotSitting)
        }
    }
}

extension GameState {
    /// The watch turned on, as the realm turns it, for the Lyceum alone.
    mutating func turnLyceumAfterWatch() -> [GameEvent] {
        watch += 1
        return turnLyceum()
    }
}
