import Foundation
@testable import NullmereCompanionCore
@testable import NullmereCore
import XCTest

/// The realm's characters as a keeper's devices give them words, the phone
/// as the Mac: the moments keyed as a device keeps their words (a steward's
/// envoy, never a keeper's, who sent their own; what the Still showed the
/// House; its riddle while unanswered; what each prisoner it holds last
/// told), each asked in one wording for both; and the phone's ledger
/// naming each by its key, with the Still's dreams it never showed before.
final class PhoneVoicesTests: XCTestCase {
    /// A keeper's House played to the dark of the moon and on until the lake
    /// sets it its riddle, a steward's envoy and another keeper's waiting on
    /// it, and a prisoner of its own who has told one true thing.
    private func world() throws -> (GameState, me: Int, envoy: Envoy, keepers: Envoy, prisoner: Commander) {
        var state = GameState(settings: GameSettings(seedText: "voiced moments", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        while (state.dreams(of: me).isEmpty || state.riddle(of: me) == nil) && state.watch < 60 && state.outcome == nil {
            _ = state.endWatch()
        }
        XCTAssertFalse(state.dreams(of: me).isEmpty)
        XCTAssertNotNil(state.riddle(of: me))
        let others = state.houses.indices.filter { $0 != me }
        state.houses[others[1]].isPlayer = true
        let envoy = Envoy(id: state.takeID(), from: others[0], to: me, proposal: .pact, arrived: state.watch)
        let keepers = Envoy(id: state.takeID(), from: others[1], to: me, proposal: .peace, arrived: state.watch, words: "Let us be done with it.")
        state.envoys += [envoy, keepers]
        let theirs = try XCTUnwrap(state.commanders(of: others[0]).first)
        let index = try XCTUnwrap(state.commanderIndex(theirs.id))
        state.commanders![index].captive = Captivity(by: me, since: 3, questioned: 1, lastQuestioned: 3, told: ["Their seat keeps 400 grain."])
        return (state, me, envoy, keepers, try XCTUnwrap(state.commander(theirs.id)))
    }

    func testTheMomentsAKeepersDevicesVoiceAreKeyedAndAskedAlike() throws {
        let (state, me, envoy, _, prisoner) = try world()
        let dream = try XCTUnwrap(state.dreams(of: me).last)
        let riddle = try XCTUnwrap(state.riddle(of: me))
        let moments = state.voicedMoments(for: me)
        XCTAssertEqual(moments.map(\.key), ["envoy-\(envoy.id)"] + state.dreams(of: me).map { "dream-\($0.watch)" }
            + ["riddle-\(riddle.set)", "prisoner-\(prisoner.id)-3-1"], "A steward's envoy, never a keeper's who sent their own words")
        let asked = Dictionary(uniqueKeysWithValues: moments.map { ($0.key, $0.moment) })
        let spoken = try XCTUnwrap(asked["envoy-\(envoy.id)"])
        XCTAssertEqual(spoken.task, Voicing.envoyTask(.pact))
        XCTAssertTrue(spoken.facts[0].hasPrefix("The envoy comes from \(state.houses[envoy.from].title)"), "\(spoken.facts)")
        XCTAssertTrue(spoken.prompt.hasPrefix(Voicing.envoyTask(.pact) + "\n\nWhat is known:\n- The envoy comes from"))
        XCTAssertEqual(asked["dream-\(dream.watch)"], Voicing.Moment(task: Voicing.dreamTask, facts: [state.told(dream), "It is the dark of the moon."]))
        XCTAssertEqual(asked["riddle-\(riddle.set)"], Voicing.Moment(task: Voicing.riddleTask, facts: [riddle.line, "It is the half moon."]))
        XCTAssertEqual(asked["prisoner-\(prisoner.id)-3-1"]?.facts.last, "Their seat keeps 400 grain.")
        XCTAssertEqual(asked["prisoner-\(prisoner.id)-3-1"]?.task, Voicing.prisonerTask)
        XCTAssertTrue(Voicing.envoyTask(.tribute).contains("demanding"))
        // Answered, the riddle is set no more; another House has none of these.
        var answered = state
        answered.riddles![try XCTUnwrap(answered.riddles?.firstIndex { $0.house == me })].answered = riddle.choices[0]
        XCTAssertFalse(answered.voicedMoments(for: me).contains { $0.key.hasPrefix("riddle-") })
        XCTAssertTrue(state.voicedMoments(for: envoy.from).isEmpty)
    }

    func testThePhonesLedgerNamesEachByItsKeyAndShowsTheStillsDreams() throws {
        let (state, me, envoy, keepers, prisoner) = try world()
        let ledger = CompanionLedger(world: state.view(for: me), player: me)
        XCTAssertEqual(ledger.voices, state.view(for: me).voicedMoments(for: me))
        XCTAssertEqual(ledger.envoys.first { $0.id == envoy.id }?.voice, "envoy-\(envoy.id)")
        XCTAssertNil(ledger.envoys.first { $0.id == keepers.id }?.voice, "A keeper's envoy carries their own words")
        XCTAssertEqual(ledger.prisoners.first { $0.id == prisoner.id }?.voice, "prisoner-\(prisoner.id)-3-1")
        XCTAssertEqual(ledger.remembering?.voice, ledger.voices.first { $0.key.hasPrefix("riddle-") }?.key)
        let dreams = state.dreams(of: me)
        XCTAssertEqual(ledger.dreams.map(\.watch), dreams.reversed().map(\.watch), "The latest first")
        XCTAssertEqual(ledger.dreams.first?.told, state.told(try XCTUnwrap(dreams.last)))
        XCTAssertEqual(ledger.dreams.first?.voice, "dream-\(try XCTUnwrap(dreams.last).watch)")
    }
}
