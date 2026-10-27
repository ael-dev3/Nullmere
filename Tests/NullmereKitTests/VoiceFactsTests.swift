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
