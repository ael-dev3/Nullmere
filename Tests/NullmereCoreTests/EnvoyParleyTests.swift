import Foundation
import XCTest
@testable import NullmereCore

/// A parley with a steward's envoy waiting on the keeper: who the envoy is
/// told it is, what it knows of the realm (the keeper's own view of it),
/// the answers it may put to the keeper, each weighed as the order book
/// weighs its line for this envoy, and what it is told as the realm moves
/// on. A keeper's envoy, carrying a person's own words, is never parleyed
/// with.
final class EnvoyParleyTests: XCTestCase {
    /// A realm whose steward of House 1 demands tribute of the keeper, each
    /// House's companies alike and so many of them.
    private func demanded(steward companies: Int, keeper own: Int) throws -> (state: GameState, me: Int, rival: Int, envoy: Envoy) {
        var state = GameState(settings: GameSettings(seedText: "a parley", houseCount: 3, radius: 16, keepers: 1))
        let me = state.player, rival = 1
        state.houses[rival].temperament = .ambitious
        state.units.removeAll { $0.owner == rival || $0.owner == me }
        let mine = try XCTUnwrap(state.seat(of: me)), theirs = try XCTUnwrap(state.seat(of: rival))
        for _ in 0..<own { XCTAssertNotNil(state.placeUnit(.spear, for: me, near: mine.position)) }
        for _ in 0..<companies { XCTAssertNotNil(state.placeUnit(.spear, for: rival, near: theirs.position)) }
        _ = try state.propose(.tribute, from: rival, to: me)
        let envoy = try XCTUnwrap(state.envoys.first { $0.from == rival && $0.to == me })
        return (state, me, rival, envoy)
    }

    func testAStewardsEnvoyIsParleyedWith() throws {
        var (state, me, rival, envoy) = try demanded(steward: 5, keeper: 3)
        let title = state.houses[rival].title
        let parley = try XCTUnwrap(EnvoyParley(state: state, player: me, envoy: envoy.id))
        XCTAssertTrue(state.parleyable(envoy, for: me))
        XCTAssertEqual(parley.speaker, "The envoy of \(title)")
        XCTAssertEqual(parley.opening, "The envoy of \(title) waits on your answer. Speak with them as you would: they keep to what their "
                       + "House sent them with, and put your answer to you to give.")

        // Who it is, what it carries, and how it puts an answer forward.
        let told = parley.instructions
        XCTAssertTrue(told.hasPrefix("You are the envoy of \(title), a House whose temper is ambitious, sent across the still black lake "
                                     + "to the keeper of \(state.houses[me].title)"), told)
        XCTAssertTrue(told.contains("You carry your House's demand of tribute: a fifth of the keeper's stores, or your House's companies march."), told)
        XCTAssertTrue(told.contains("to accept your House's offer, to refuse it, or to offer half your demand in its place, put it to them with "
                                    + "putAnswerToKeeper"), told)
        XCTAssertTrue(told.contains("Never invent numbers, places, names, promises or events"))

        // What it knows: the realm's facts as the keeper's view tells them.
        let facts = parley.facts
        XCTAssertEqual(Array(facts.prefix(state.voiced(envoy).facts.count)), state.voiced(envoy).facts)
        XCTAssertTrue(facts.contains("The envoy comes from \(title), whose temper is ambitious."))
        XCTAssertTrue(facts.contains("What the keeper is told of your terms: \(state.terms(of: envoy, for: me))"))
        let left = state.watchesWaiting(of: envoy)
        XCTAssertTrue(facts.contains(left == 1 ? "You leave after this watch." : "You wait \(GameState.counted(left)) watches more for the keeper's answer."))
        XCTAssertTrue(facts.contains("If the keeper refuses, or sends no answer, your House marches on theirs."))
        XCTAssertFalse(facts.contains("The keeper hasn't what your terms ask of them."), "A fifth of what they keep is always theirs to pay")
        let half = state.halfTribute(from: me)
        XCTAssertTrue(facts.contains("The keeper may offer half your demand in its place: \(half), a tenth of their stores. "
                                     + "Your House would weigh it at once, and take it or hold to the whole."))
        XCTAssertEqual(parley.briefing, "What you know:\n" + facts.map { "- \($0)" }.joined(separator: "\n"))

        // The answers it may put to the keeper, each as the order book reads it.
        let accept = parley.putAnswer("accept")
        XCTAssertEqual(accept.line, "ACCEPT THE ENVOY OF \(title)")
        XCTAssertEqual(accept.command, .answer(envoy: envoy.id, accept: true))
        XCTAssertEqual(accept.told, "Your House pays \(title) its tribute: \(state.tribute(from: me)).")
        XCTAssertTrue(accept.isGiven)
        let refuse = parley.putAnswer(" Refuse ")
        XCTAssertEqual(refuse.command, .answer(envoy: envoy.id, accept: false))
        XCTAssertEqual(refuse.told, "Your House refuses \(title) its tribute, and it marches on you.")
        XCTAssertNil(refuse.why)
        let offered = parley.putAnswer("half")
        XCTAssertEqual(offered.line, "OFFER HALF THE TRIBUTE TO \(title)")
        XCTAssertEqual(offered.command, .bargain(envoy: envoy.id))
        XCTAssertEqual(offered.told, "Your House offers \(title) half its demand: \(half), for \(GameState.halfTributeRespite) watches' peace.")
        XCTAssertEqual(SpokenOrders.read(line: offered.line, in: state, player: me)?.told, offered.told, "As the order book tells it")
        XCTAssertNil(offered.why)
        let danced = parley.putAnswer("dance")
        XCTAssertNil(danced.command)
        XCTAssertEqual(danced.why, EnvoyParley.onlyTheseAnswers)

        // Offered half and held to: it knows, says so when next the keeper
        // speaks, and puts no half forward again.
        _ = try state.perform(.bargain(envoy: envoy.id), as: me)
        let after = try XCTUnwrap(EnvoyParley(state: state, player: me, envoy: envoy.id), "It waits on, its demand whole")
        XCTAssertTrue(after.facts.contains("The keeper offered half your demand once, and your House held to the whole."))
        XCTAssertFalse(after.facts.contains { $0.hasPrefix("The keeper may offer half") })
        XCTAssertEqual(after.news(since: parley), "The keeper offered half your demand, and your House held to the whole.")
        XCTAssertNil(after.news(since: after))
        XCTAssertNil(parley.news(since: parley))
        XCTAssertEqual(after.putAnswer("half").why, RuleError.bargainedAlready.description)
        XCTAssertTrue(after.putAnswer("accept").isGiven)

        // Answered, it goes home, and there is no parley with it.
        _ = try state.perform(.answer(envoy: envoy.id, accept: true), as: me)
        XCTAssertNil(EnvoyParley(state: state, player: me, envoy: envoy.id))
    }

    func testAnOfferHasNoHalfToPut() throws {
        var state = GameState(settings: GameSettings(seedText: "a parley of a pact", houseCount: 3, radius: 16, keepers: 1))
        let me = state.player, rival = 2
        state.houses[rival].temperament = .steadfast
        XCTAssertEqual(state.stance(me, rival), .peace, "At peace as the age begins")
        _ = try state.propose(.pact, from: rival, to: me)
        let envoy = try XCTUnwrap(state.envoys.first { $0.from == rival && $0.to == me })
        let parley = try XCTUnwrap(EnvoyParley(state: state, player: me, envoy: envoy.id))
        let title = state.houses[rival].title
        XCTAssertTrue(parley.instructions.contains("You carry your House's offer of a pact: shared sight across the water, and no war between the Houses."))
        XCTAssertTrue(parley.instructions.contains("to accept your House's offer, to refuse it, put it to them with putAnswerToKeeper"))
        XCTAssertFalse(parley.facts.contains("If the keeper refuses, or sends no answer, your House marches on theirs."))
        XCTAssertFalse(parley.facts.contains { $0.contains("half") })
        XCTAssertEqual(parley.putAnswer("accept").told, "Your House takes \(title)'s offer of \(Proposal.pact.offered).")
        XCTAssertEqual(parley.putAnswer("half").why, RuleError.notBargained.description)
    }

    func testNoParleyWithAKeepersEnvoyOrAnothers() throws {
        var (state, me, rival, envoy) = try demanded(steward: 5, keeper: 3)
        XCTAssertNil(EnvoyParley(state: state, player: 2, envoy: envoy.id), "It waits on another House")
        XCTAssertNil(EnvoyParley(state: state, player: me, envoy: envoy.id + 1_000), "No such envoy")
        XCTAssertNil(EnvoyParley(state: state, player: 99, envoy: envoy.id))
        state.houses[rival].isPlayer = true
        XCTAssertNil(EnvoyParley(state: state, player: me, envoy: envoy.id), "A keeper's envoy carries a person's own words")
        XCTAssertFalse(state.parleyable(envoy, for: me))
    }

    func testWhatWasSaidIsRecalledWhenTheParleyIsBegunAfresh() {
        XCTAssertNil(EnvoyParley.recalled([]))
        let said = (1...6).map { CounselMemory.Exchange(watch: $0, asked: "Question \($0)", answered: "Answer \($0)") }
        XCTAssertEqual(EnvoyParley.recalled(Array(said.prefix(1))), "The keeper: Question 1\nYou: Answer 1")
        let recalled = EnvoyParley.recalled(said)
        XCTAssertEqual(recalled?.components(separatedBy: "\n").count, EnvoyParley.recalledExchanges * 2)
        XCTAssertEqual(recalled?.hasPrefix("The keeper: Question 3\n"), true, "The last four")
        XCTAssertEqual(recalled?.hasSuffix("You: Answer 6"), true)
    }

    func testTheFootSaysWhoSpeaksForTheEnvoy() {
        XCTAssertEqual(EnvoyParley.foot(on: "Mac", canAsk: false), "Only Apple's on-device model speaks for an envoy, and nothing speaks in its place")
        XCTAssertEqual(EnvoyParley.foot(on: "iPhone", canAsk: true), "Spoken by Apple's on-device model on this iPhone")
        XCTAssertEqual(EnvoyParley.foot(on: "Mac", canAsk: true, firstWords: 0.42, whole: 2.5),
                       "Spoken by Apple's on-device model on this Mac · first words 0.4 s, all of it 2.5 s")
    }
}
