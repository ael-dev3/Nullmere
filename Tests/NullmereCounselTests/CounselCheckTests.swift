import Foundation
import FoundationModels
import XCTest
@testable import NullmereCounsel

/// The check of counsel heard on a real Mac, through scripts/check-counsel.sh:
/// where the model can't speak it says so and is unverified, never passed;
/// and its rules catch what they should of an answer.
@MainActor
final class CounselCheckTests: XCTestCase {
    /// The check heard on a real Mac: where the model can't speak it says
    /// so and is unverified, never passed; its rules catch what they should.
    func testTheCounselCheckIsUnverifiedWhereTheModelCantSpeak() async {
        let report = await CounselCheck.run(availability: { .unavailable(.deviceNotEligible) })
        XCTAssertTrue(report.unavailable)
        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertTrue(report.text.hasPrefix("Apple's on-device model on this Mac, not ready ("), report.text)
        XCTAssertEqual(CounselCheck.problems(of: "We hold the ford, my keeper.", facts: ""), [])
        XCTAssertEqual(CounselCheck.problems(of: "Charge!", facts: ""), ["an exclamation"])
        XCTAssertEqual(CounselCheck.problems(of: "Some 4000 troops wait.", facts: "4,000"), ["invents the number 4000"])
        XCTAssertEqual(CounselCheck.problems(of: "Some 4,000 troops wait.", facts: "4,000 troops"), [])
        XCTAssertEqual(CounselCheck.problems(of: "This game is long.", facts: ""), ["speaks of \"game\""])
        XCTAssertEqual(CounselCheck.problems(of: String(repeating: "word ", count: 95), facts: ""), ["95 words"])
    }

    /// A simulator's model is its Mac's. Where it says it is ready yet gives
    /// no answer at all, as on a Mac that can't run it (CI's, run 658), the
    /// check says it went unheard, with the model's own words: unverified,
    /// neither passed nor broken. On a real device, no answer at all is
    /// counsel broken, as ever.
    func testASimulatorsModelThatGivesNoAnswerIsUnheardNotBroken() async {
        struct Silence: Error {}
        let silent: (String) -> AsyncThrowingStream<String, Error> = { _ in
            AsyncThrowingStream { $0.finish(throwing: Silence()) }
        }
        let unheard = await CounselCheck.run(on: "this iPhone Simulator", simulated: true, availability: { .available }, speaker: silent)
        XCTAssertTrue(unheard.unavailable, unheard.text)
        XCTAssertTrue(unheard.failures.isEmpty)
        XCTAssertTrue(unheard.text.hasPrefix("Apple's on-device model on this iPhone Simulator, unheard (it says it is ready, yet gave no answer: "),
                      unheard.text)
        XCTAssertTrue(unheard.text.contains("NO ANSWER: "), "What it said instead, kept")
        XCTAssertFalse(unheard.text.hasSuffix(CounselCheck.passed))
        let broken = await CounselCheck.run(on: "this iPhone", availability: { .available }, speaker: silent)
        XCTAssertFalse(broken.unavailable, "A real device's silence is no unavailability")
        XCTAssertFalse(broken.failures.isEmpty)
        XCTAssertTrue(broken.text.hasSuffix("Broken: \(broken.failures.count)"), broken.text)
    }
}
