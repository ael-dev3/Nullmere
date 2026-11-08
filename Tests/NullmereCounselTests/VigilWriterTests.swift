import Foundation
import XCTest
@testable import NullmereCore
@testable import NullmereCounsel

/// Words for a House's dead written by the device's model, on the phone as
/// on the Mac, apart from the model's own words: where it can't write, why,
/// the model never asked; asked the realm's own facts of the House's
/// fallen, its answer held to the words the realm carries and timed; its
/// failures and slowness told as themselves; stopped, nothing written.
/// The model's own words are heard on a device that can run it.
final class VigilWriterTests: XCTestCase {
    private func world() -> (GameState, Int) {
        var state = GameState(settings: GameSettings(seedText: "vigil writer", houseCount: 4, radius: 18, keepers: 1))
        state.houses[state.player].unmourned = 3
        return (state.view(for: state.player), state.player)
    }

    private actor Asked {
        var prompts: [String] = []
        func add(_ prompt: String) { prompts.append(prompt) }
    }

    private let report = BattleReport(id: 1, watch: 4, title: "Your Spears fell", place: "at Wenholme", outcome: .lost, lines: [])

    func testWhereTheModelCantWriteItIsNeverAsked() async {
        let (world, me) = world()
        let asked = Asked()
        let writer = VigilWriter(trouble: { .unavailable(.deviceNotEligible) }) { prompt in
            await asked.add(prompt)
            return "For them"
        }
        XCTAssertEqual(writer.unavailable, "This device can't run Apple's on-device model, so the words for your dead are yours to write.")
        let written = await writer.write(for: me, in: world, reports: [report])
        XCTAssertEqual(written, VigilWriter.Written(words: nil, trouble: .unavailable(.deviceNotEligible), seconds: nil))
        let prompts = await asked.prompts
        XCTAssertTrue(prompts.isEmpty, "The model is never asked where it can't answer")
    }

    func testTheModelIsAskedTheRealmsOwnFactsAndItsWordsAreHeld() async throws {
        let (world, me) = world()
        let asked = Asked()
        let writer = VigilWriter(trouble: { nil }) { prompt in
            await asked.add(prompt)
            return "  “For the three companies who fell at Wenholme, the water keeps them.”  "
        }
        XCTAssertNil(writer.unavailable)
        let written = await writer.write(for: me, in: world, reports: [report])
        XCTAssertEqual(written.words, "For the three companies who fell at Wenholme, the water keeps them.", "Quotes and spaces trimmed")
        XCTAssertNil(written.trouble)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(written.seconds), 0)
        let prompts = await asked.prompts
        XCTAssertEqual(prompts, [Voicing.asking(GameState.vigilWordsAsked, facts: world.vigilFacts(of: me, reports: [report]))])
        XCTAssertTrue(prompts[0].contains("Companies of war of theirs fallen in battle: 3."))
        XCTAssertTrue(prompts[0].contains("Some fell at Wenholme in watch 4."))
    }

    func testTheModelsTroubleAndSlownessAreToldAsThemselves() async {
        let (world, me) = world()
        let busy = await VigilWriter(trouble: { nil }) { _ in throw CounselTrouble.busy }.write(for: me, in: world, reports: [])
        XCTAssertEqual(busy, VigilWriter.Written(words: nil, trouble: .busy, seconds: nil))
        let slow = await VigilWriter(trouble: { nil }, patience: 0.1) { _ in
            try await Task.sleep(nanoseconds: 5_000_000_000)
            return "Too late"
        }.write(for: me, in: world, reports: [])
        XCTAssertEqual(slow.trouble, .slow)
        let unsayable = await VigilWriter(trouble: { nil }) { _ in "http://nowhere" }.write(for: me, in: world, reports: [])
        XCTAssertEqual(unsayable.trouble, .garbled, "Words the realm wouldn't carry are none")
        XCTAssertNil(unsayable.words)
    }

    func testStoppedNothingIsWritten() async {
        let (world, me) = world()
        let writer = VigilWriter(trouble: { nil }) { _ in
            try await Task.sleep(nanoseconds: 30_000_000_000)
            return "Too late"
        }
        let writing = Task { await writer.write(for: me, in: world, reports: []) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        writing.cancel()
        let written = await writing.value
        XCTAssertEqual(written, .stopped)
    }
}
