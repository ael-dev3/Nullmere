import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The voices' rules, held against stand-ins as scripts/check-voices.sh
/// holds Apple's on-device model to them: a voice that keeps them passes,
/// and each way of breaking them is caught and named.
final class VoiceCheckTests: XCTestCase {
    /// Speaks every moment in the same grave line, which keeps every rule,
    /// and makes every ballad the same two.
    private struct Steady: Voice {
        func speak(_ moment: VoiceMoment) async -> String? {
            "The water keeps its silence, and the Houses watch the shore."
        }

        func compose(_ moment: VoiceMoment) async -> String? {
            "The moon lay still upon the water,\nand the shore remembered."
        }
    }

    /// Never answers, as a model that isn't ready.
    private struct Silent: Voice {
        func speak(_ moment: VoiceMoment) async -> String? { nil }
    }

    func testAVoiceWithinTheRulesPasses() async {
        let report = await VoiceCheck.run(Steady(), source: "a stand-in")
        XCTAssertEqual(report.failures, [])
        XCTAssertGreaterThanOrEqual(report.moments, Proposal.allCases.count + 2, "Envoys and chronicle entries enough to hear")
        XCTAssertTrue(report.text.hasPrefix("Nullmere Online's voices, spoken by a stand-in."), report.text)
        XCTAssertTrue(report.text.hasSuffix(VoiceCheck.passed), report.text)
        let told = report.text.components(separatedBy: "\n")
        let heard = told.filter { $0.hasSuffix("s): The water keeps its silence, and the Houses watch the shore.") }
        let sung = told.filter { $0.hasPrefix("ballad of ") && $0.hasSuffix("s): The moon lay still upon the water, / and the shore remembered.") }
        XCTAssertEqual(sung.count, 1, "A ballad made of the latest deed of arms, its lines on one")
        XCTAssertEqual(heard.count + sung.count, report.moments, "A line told for every moment")
        for proposal in Proposal.allCases {
            XCTAssertTrue(report.text.contains("envoy offering \(proposal.title.lowercased())"), "An envoy offering \(proposal.title)")
        }
    }

    func testEachWayOfBreakingTheRulesIsNamed() {
        let moment = VoiceMoment(kind: .chronicle(.war), facts: ["House Aurel and House Brann are at war since watch 12."])
        XCTAssertEqual(VoiceCheck.problems(of: "Since watch 12 they war.", for: moment), [])
        XCTAssertEqual(VoiceCheck.problems(of: nil, for: moment), ["silent"])
        XCTAssertEqual(VoiceCheck.problems(of: "War, at last!", for: moment), ["an exclamation"])
        XCTAssertEqual(VoiceCheck.problems(of: Array(repeating: "still", count: 61).joined(separator: " "), for: moment), ["61 words"])
        XCTAssertEqual(VoiceCheck.problems(of: "The game of Houses goes on.", for: moment), ["speaks of \"game\""])
        XCTAssertEqual(VoiceCheck.problems(of: "Their turns are long.", for: moment), ["speaks of \"turn\""])
        XCTAssertEqual(VoiceCheck.problems(of: "The tide turned at the return of the moon.", for: moment), [],
                       "Words that only hold a forbidden one are the voices' own")
        XCTAssertEqual(VoiceCheck.problems(of: "Since watch 13 they war.", for: moment), ["invents the number 13"])
        let ballad = VoiceMoment(kind: .ballad, facts: ["A battle at the Grey Ford."])
        XCTAssertEqual(VoiceCheck.problems(of: "The ford ran red,\nand the moon looked on.", for: ballad), [])
        XCTAssertEqual(VoiceCheck.problems(of: "The ford ran red.", for: ballad), ["no ballad the realm would keep"], "One line is no ballad")
    }

    func testAVoiceThatBreaksTheRulesFailsWithEachBreachNamed() async {
        let report = await VoiceCheck.run(Silent(), source: "silence")
        XCTAssertEqual(report.failures.count, report.moments, "Every moment silent")
        XCTAssertTrue(report.failures.allSatisfy { $0.hasSuffix(": silent") }, "\(report.failures)")
        XCTAssertTrue(report.text.contains("\nOut of bounds:\n"), report.text)
        XCTAssertFalse(report.text.hasSuffix(VoiceCheck.passed))
    }

    /// The model's state as the report's head tells it: ready exactly when
    /// the voices can be asked.
    func testTheModelsStateIsToldAsItIs() {
        XCTAssertEqual(OnDeviceVoice.availability == "ready", OnDeviceVoice.isAvailable, OnDeviceVoice.availability)
        XCTAssertFalse(OnDeviceVoice.availability.isEmpty)
    }
}
