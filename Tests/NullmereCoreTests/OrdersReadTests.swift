import Foundation
import XCTest
@testable import NullmereCore

/// What came of reading a keeper's own words: by the device's model, its
/// answer read against the keeper's view; without it, the words read as the
/// order book's lines as written and the reason told as itself; a reading
/// the keeper stopped, nothing read.
final class OrdersReadTests: XCTestCase {
    private func world() -> GameState {
        GameState(settings: GameSettings(seedText: "orders read", houseCount: 4, radius: 18, keepers: 1))
    }

    /// The model's answer is read as the order book's lines against the
    /// keeper's view: the orders the realm would take, and why not where it
    /// wouldn't; how long the model took said with them.
    func testTheModelsAnswerIsReadAgainstTheKeepersView() throws {
        let state = world()
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        let answer = "FORTIFY C1\nBUILD Granary AT \(seat.name)\nTRAIN Dragons AT \(seat.name)"
        let reading = SpokenOrders.reading("dig in my first company and raise a granary at home", answer: answer, trouble: nil,
                                           seconds: 2.4, in: state, player: me)
        XCTAssertTrue(reading.byModel)
        XCTAssertNil(reading.trouble)
        XCTAssertEqual(reading.seconds, 2.4)
        XCTAssertFalse(reading.stopped)
        XCTAssertEqual(reading.lines, SpokenOrders.read(answer, in: state, player: me))
        XCTAssertEqual(reading.lines.count, 3)
        XCTAssertEqual(reading.takeable, reading.lines.filter { $0.command != nil && $0.why == nil })
        XCTAssertFalse(reading.takeable.isEmpty, "\(reading.lines.map { $0.why ?? $0.told })")
        for line in reading.takeable {
            XCTAssertNil(state.refusal(of: try XCTUnwrap(line.command), as: me), line.told)
        }
        XCTAssertTrue(reading.lines.contains { $0.why != nil }, "No Dragons are mustered")
        XCTAssertEqual(reading.summary, "Read by Apple's on-device model in 2.4 s: \(reading.takeable.count) of 3 orders the realm would take.")
    }

    /// Where the model couldn't read them, the words are read as the order
    /// book's lines as the keeper wrote them, and why is told as itself:
    /// every reason its own words, before the keeper writes and after.
    func testWithoutTheModelTheWordsAreReadAsWrittenAndWhyIsTold() throws {
        let state = world()
        let me = state.player
        let written = SpokenOrders.reading("FORTIFY C1", answer: nil, trouble: .unavailable(.deviceNotEligible), seconds: nil, in: state, player: me)
        XCTAssertFalse(written.byModel)
        XCTAssertNil(written.seconds)
        XCTAssertEqual(written.lines, SpokenOrders.read("FORTIFY C1", in: state, player: me))
        XCTAssertEqual(written.lines.count, 1)
        XCTAssertEqual(written.trouble, "This device can't run Apple's on-device model, so your words were read as the order book's lines, as written.")
        XCTAssertEqual(written.summary, "Read as the order book's lines, as written: \(written.takeable.count) of 1 order the realm would take.")

        let plain = SpokenOrders.reading("dig in my spears by the ford", answer: nil, trouble: .busy, seconds: nil, in: state, player: me)
        XCTAssertTrue(plain.lines.isEmpty, "Plain words make no line of the order book")
        XCTAssertEqual(plain.summary, "Read as the order book's lines, as written: no order in them.")
        XCTAssertEqual(SpokenOrders.reading("FORTIFY C1", answer: nil, trouble: nil, seconds: nil, in: state, player: me).trouble,
                       CounselTrouble.unavailable(.modelNotReady).unreadOrders, "No answer and no reason: the model not ready")

        let troubles: [CounselTrouble] = [.unavailable(.deviceNotEligible), .unavailable(.appleIntelligenceOff), .unavailable(.modelNotReady),
                                          .unavailable(.systemTooOld), .refused, .language, .busy, .tooLong, .garbled, .assetsMissing,
                                          .slow, .failed("the system's own words")]
        XCTAssertEqual(Set(troubles.map(\.unreadOrders)).count, troubles.count, "Each told as itself")
        for trouble in troubles {
            XCTAssertTrue(trouble.unreadOrders.hasSuffix(", so your words were read as the order book's lines, as written."), trouble.unreadOrders)
            XCTAssertTrue(trouble.ordersReadAsWritten.hasSuffix(", so your words are read as the order book's lines, as written."))
            XCTAssertEqual(trouble.unreadOrders.prefix(20), trouble.ordersReadAsWritten.prefix(20))
            XCTAssertFalse(trouble.unreadOrders.contains("!"))
        }
        XCTAssertTrue(CounselTrouble.failed("the system's own words").unreadOrders.contains("(the system's own words)"))
    }

    /// A reading the keeper stopped reads nothing and gives nothing.
    func testAReadingStoppedReadsNothing() {
        let stopped = SpokenOrders.Reading.stopped
        XCTAssertTrue(stopped.stopped)
        XCTAssertTrue(stopped.lines.isEmpty)
        XCTAssertTrue(stopped.takeable.isEmpty)
        XCTAssertFalse(stopped.byModel)
        XCTAssertEqual(stopped.summary, "Stopped: nothing was read.")
    }

    /// The model is asked the briefing of what the House has and knows,
    /// then the keeper's words as they wrote them.
    func testTheModelIsAskedTheBriefingThenTheKeepersWords() {
        let state = world()
        let me = state.player
        XCTAssertEqual(SpokenOrders.asking("  march my spears home \n", in: state, player: me),
                       SpokenOrders.briefing(for: state, player: me) + "\n\nThe keeper says:\nmarch my spears home")
    }
}
