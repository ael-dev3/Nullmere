import NullmereCore
import XCTest
@testable import NullmereKit

final class VoiceTests: XCTestCase {
    func testCleaningKeepsOnlyTheSpokenLine() {
        XCTAssertEqual(OnDeviceVoice.clean("  \"We come in peace, as the water is still.\"\nExtra"), "We come in peace, as the water is still.")
        XCTAssertEqual(OnDeviceVoice.clean("Envoy: The lake remembers!"), "The lake remembers.")
        XCTAssertEqual(OnDeviceVoice.clean("The Chronicler: So it was written."), "So it was written.")
        XCTAssertNil(OnDeviceVoice.clean("  ok "))
        let long = String(repeating: "The water lies black. ", count: 30)
        XCTAssertLessThanOrEqual(OnDeviceVoice.clean(long)!.count, 281)
    }

    func testPromptsCarryTheFactsAndTheTask() {
        let moment = VoiceMoment(kind: .envoy(proposal: .pact), facts: ["The envoy comes from House Venn."])
        XCTAssertTrue(moment.prompt.contains("- The envoy comes from House Venn."))
        XCTAssertTrue(moment.prompt.contains("pact"))
        let line = VoiceMoment(kind: .chronicle(.war), facts: ["War."])
        XCTAssertTrue(line.prompt.contains("chronicler"))
    }

    func testOnlyMomentsTouchingThePlayerAreVoiced() {
        XCTAssertTrue(VoiceFacts.isVoiced(.betrayal))
        XCTAssertFalse(VoiceFacts.isVoiced(.founding))
    }
}

/// Answers every moment at once with its first fact, and remembers them.
private final class EchoVoice: Voice, @unchecked Sendable {
    private let lock = NSLock()
    private var heard: [VoiceMoment] = []

    var moments: [VoiceMoment] {
        lock.lock(); defer { lock.unlock() }
        return heard
    }

    func speak(_ moment: VoiceMoment) async -> String? {
        lock.lock(); heard.append(moment); lock.unlock()
        return "Spoken: " + (moment.facts.first ?? "")
    }
}

@MainActor
final class SessionVoiceTests: XCTestCase {
    func testTheSessionVoicesItsOwnHistoryAndEnvoys() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let voice = EchoVoice()
        let state = GameState(settings: GameSettings(seedText: "voices over the water", houseCount: 4, radius: 16))
        let session = GameSession(state: state, store: SaveStore(directory: directory), voice: voice)
        session.autoplay(watches: 120)
        for _ in 0..<200 {
            try await Task.sleep(for: .milliseconds(10))
            if session.spoken.count == voice.moments.count { break }
        }
        XCTAssertFalse(voice.moments.isEmpty, "a hundred and twenty watches leave something worth telling")
        XCTAssertEqual(session.spoken.count, voice.moments.count)

        // Picked up again, the game keeps its words and asks for nothing new.
        session.save(quietly: true)
        let again = EchoVoice()
        let resumed = GameSession(state: session.state, store: SaveStore(directory: directory), voice: again)
        XCTAssertEqual(resumed.spoken, session.spoken)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(again.moments.allSatisfy { if case .envoy = $0.kind { return true } else { return false } })
        for (key, words) in session.spoken {
            XCTAssertTrue(words.hasPrefix("Spoken: "))
            if case .chronicle(let index) = key {
                let entry = session.state.chronicle[index]
                XCTAssertTrue(entry.houses.contains(session.player) || entry.kind == .ending)
                XCTAssertTrue(VoiceFacts.isVoiced(entry.kind))
            }
        }
    }
}
