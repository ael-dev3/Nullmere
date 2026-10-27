import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The facts an envoy's voice is given: who comes and to whom, how the two
/// Houses stand, what lies between them, which is the stronger, and what
/// a trade would give for what.
final class VoiceFactsTests: XCTestCase {
    func testAnEnvoyIsGivenTheFactsBetweenTheTwoHouses() throws {
        var state = GameState(settings: GameSettings(seedText: "voice facts", houseCount: 4, radius: 18))
        let me = state.player
        let them = (me + 1) % state.houses.count
        let index = try XCTUnwrap(state.relations.firstIndex { [$0.first, $0.second].sorted() == [me, them].sorted() })
        state.relations[index].stance = .war
        state.relations[index].aggressor = them
        state.relations[index].betrayals = 1
        // Their companies gone: ours is the stronger House.
        state.units.removeAll { $0.owner == them }

        let trade = Trade(give: .timber, 20, for: .grain, 15)
        let envoy = Envoy(id: 1, from: them, to: me, proposal: .trade, arrived: state.watch, trade: trade)
        let moment = VoiceFacts.envoy(envoy, in: state)
        let theirs = state.houses[them].title, ours = state.houses[me].title
        XCTAssertEqual(moment.kind, .envoy(proposal: .trade))
        XCTAssertTrue(moment.facts[0].hasPrefix("The envoy comes from \(theirs)"))
        XCTAssertEqual(moment.facts[1], "They speak to \(ours).")
        XCTAssertTrue(moment.facts.contains("Pacts between them have been broken before."))
        XCTAssertTrue(moment.facts.contains("It was \(theirs) that declared the war."))
        XCTAssertTrue(moment.facts.contains("\(ours) is the stronger House."))
        XCTAssertTrue(moment.facts.contains("\(theirs) would give \(trade.given) for \(trade.taken)."))

        // The other way about: we declared it, and they are the stronger.
        state.relations[index].aggressor = me
        state.relations[index].betrayals = 0
        var stronger = state
        stronger.units.removeAll { $0.owner == me }
        stronger.holds.indices.filter { stronger.holds[$0].owner == them }.forEach { stronger.holds[$0].ward += 400 }
        let peace = Envoy(id: 2, from: them, to: me, proposal: .peace, arrived: state.watch, trade: nil)
        let facts = VoiceFacts.envoy(peace, in: stronger).facts
        XCTAssertTrue(facts.contains("It was \(ours) that declared the war."))
        XCTAssertTrue(facts.contains("\(theirs) is the stronger House."))
        XCTAssertFalse(facts.contains("Pacts between them have been broken before."))
        XCTAssertFalse(facts.contains { $0.contains("would give") })
    }
}

/// The sound engine itself, started on this Mac's output as the app starts
/// it: cues played, the score turned to war, the volumes set, and stopped.
/// With no output to play on, it stays silent rather than failing.
@MainActor
final class AmbienceEngineTests: XCTestCase {
    func testTheSoundStartsPlaysAndStops() async throws {
        let ambience = Ambience(enabled: false)
        ambience.start()
        ambience.play(.clash)
        ambience.isEnabled = true
        ambience.start()
        for cue in Ambience.Cue.all { ambience.play(cue) }
        ambience.isAtWar = true
        ambience.isMusicOn = false
        ambience.isMusicOn = true
        ambience.effectsVolume = 0.5
        ambience.ambienceVolume = 0.25
        ambience.musicVolume = 0
        try await Task.sleep(nanoseconds: 300_000_000)
        ambience.isAtWar = false
        ambience.isEnabled = false
        ambience.stop()
        ambience.isEnabled = true
        ambience.isEnabled = false
    }
}

/// The on-device voice's own work, with a stand-in for Apple's model: it
/// asks with the voices' rules and the moment's facts, keeps only the
/// spoken line, stays silent when the model isn't ready, and stays silent,
/// not failing, when the model can't answer.
final class OnDeviceVoiceTests: XCTestCase {
    private let moment = VoiceMoment(kind: .envoy(proposal: .pact), facts: ["The envoy comes from House Venn."])

    func testTheModelIsAskedWithTheRulesAndTheFactsAndItsLineCleaned() async {
        let asked = Asked()
        let voice = OnDeviceVoice(isReady: { true }) { instructions, prompt in
            asked.record(instructions, prompt)
            return "Envoy: \"Let the water lie still between us!\"\nAnd more."
        }
        let line = await voice.speak(moment)
        XCTAssertEqual(line, "Let the water lie still between us.")
        XCTAssertEqual(asked.instructions, OnDeviceVoice.instructions)
        XCTAssertTrue(asked.prompt?.contains("- The envoy comes from House Venn.") == true)
        XCTAssertTrue(asked.prompt?.contains("offering a pact") == true)
    }

    func testANotReadyModelIsNotAsked() async {
        let asked = Asked()
        let voice = OnDeviceVoice(isReady: { false }) { instructions, prompt in
            asked.record(instructions, prompt)
            return "Words."
        }
        let line = await voice.speak(moment)
        XCTAssertNil(line)
        XCTAssertNil(asked.prompt, "Not asked")
    }

    func testAModelThatFailsLeavesTheVoiceSilent() async {
        let voice = OnDeviceVoice(isReady: { true }) { _, _ in throw CancellationError() }
        let line = await voice.speak(moment)
        XCTAssertNil(line)
        let short = OnDeviceVoice(isReady: { true }) { _, _ in "Yes." }
        let tooShort = await short.speak(moment)
        XCTAssertNil(tooShort, "Too short to be a line")
    }

    func testTheLiveVoiceAnswersWhetherTheModelIsReady() {
        // On CI's Mac there is no Apple Intelligence: the live voice says so.
        _ = OnDeviceVoice().isReady()
    }
}

private final class Asked: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var instructions: String?
    private(set) var prompt: String?
    func record(_ instructions: String, _ prompt: String) {
        lock.lock(); self.instructions = instructions; self.prompt = prompt; lock.unlock()
    }
}
