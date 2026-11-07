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
}
