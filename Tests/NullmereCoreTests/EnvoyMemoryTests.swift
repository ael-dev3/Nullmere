import XCTest
@testable import NullmereCore

/// Envoys remember: how the last envoy one House sent another was answered
/// (taken, turned away, or left waiting until it went home), and how many
/// were turned away, kept by the realm wherever a keeper is one of the two,
/// told only to those two, given to the next envoy's words and said on its
/// card.
final class EnvoyMemoryTests: XCTestCase {
    private func realm() throws -> (RealmState, ama: Int, bel: Int) {
        var realm = RealmState(name: "The Nullmere", seed: "envoys remember", seats: 12, radius: 36, watchLength: 180, now: 0)
        let ama = try XCTUnwrap(realm.arrive("id-ama", name: "Ama", now: 0).house)
        let bel = try XCTUnwrap(realm.arrive("id-bel", name: "Bel", now: 0).house)
        return (realm, ama, bel)
    }

    /// An envoy come to `to` from `from`, `waited` watches ago.
    private func send(_ proposal: Proposal, from: Int, to: Int, waited: Int = 0, trade: Trade? = nil, in realm: inout RealmState) -> Envoy {
        let envoy = Envoy(id: realm.world.nextID, from: from, to: to, proposal: proposal, arrived: realm.world.watch - waited, trade: trade)
        realm.world.nextID += 1
        realm.world.envoys.append(envoy)
        return envoy
    }

    private func steward(at peace: Int, in realm: RealmState) throws -> Int {
        try XCTUnwrap(realm.world.houses.first { !$0.isPlayer && realm.world.stance($0.id, peace) == .peace }).id
    }

    func testAKeepersAnswerIsRememberedAndTheNextEnvoyComesKnowingIt() throws {
        var (realm, ama, _) = try realm()
        let friend = try steward(at: ama, in: realm)
        let house = realm.world.houses[friend].title, hers = realm.world.houses[ama].title
        // Nothing to remember before the first.
        let first = send(.pact, from: friend, to: ama, in: &realm)
        XCTAssertNil(realm.world.remembered(first, for: ama))
        XCTAssertTrue(realm.world.rememberedFacts(first).isEmpty)
        // Turned away, and the realm keeps it.
        _ = try realm.perform(.answer(envoy: first.id, accept: false), by: "id-ama")
        let refused = realm.world.watch
        XCTAssertEqual(realm.world.lastAnswer(from: friend, to: ama),
                       EnvoyAnswer(from: friend, to: ama, proposal: .pact, watch: refused, answer: .refused, turnedAway: 1))
        XCTAssertNil(realm.world.lastAnswer(from: ama, to: friend), "Her own envoys went nowhere")
        // The next comes knowing it: its words are given it, and her card says it.
        let second = send(.pact, from: friend, to: ama, waited: Envoy.patience - 1, in: &realm)
        XCTAssertEqual(realm.world.remembered(second, for: ama),
                       "\(house)'s last envoy, in watch \(refused), came offering a pact, and you turned it away.")
        let facts = realm.world.voiced(second).facts
        XCTAssertTrue(facts.contains("\(house)'s last envoy to \(hers), in watch \(refused), came offering a pact, and \(hers) turned it away."),
                      "\(facts)")
        XCTAssertFalse(facts.contains { $0.contains("has turned away") }, "Once is not yet a habit: \(facts)")
        // Left waiting until it goes home: turned away as surely.
        realm.world.endWatch()
        XCTAssertFalse(realm.world.envoys.contains { $0.id == second.id }, "Gone home unanswered")
        let lapsed = realm.world.watch
        XCTAssertEqual(realm.world.lastAnswer(from: friend, to: ama),
                       EnvoyAnswer(from: friend, to: ama, proposal: .pact, watch: lapsed, answer: .unanswered, turnedAway: 2))
        let third = send(.pact, from: friend, to: ama, in: &realm)
        XCTAssertEqual(realm.world.remembered(third, for: ama),
                       "\(house)'s last envoy, in watch \(lapsed), came offering a pact, and you sent no answer. "
                       + "You have turned away 2 of their envoys this age.")
        XCTAssertTrue(realm.world.voiced(third).facts.contains("\(hers) has turned away 2 of \(house)'s envoys this age."))
        // Taken at last: remembered so, and what was turned away before still counted.
        realm.world.setStance(.peace, between: ama, and: friend, by: ama)
        _ = try realm.perform(.answer(envoy: third.id, accept: true), by: "id-ama")
        XCTAssertEqual(realm.world.stance(ama, friend), .pact)
        XCTAssertEqual(realm.world.lastAnswer(from: friend, to: ama)?.answer, .accepted)
        XCTAssertEqual(realm.world.lastAnswer(from: friend, to: ama)?.turnedAway, 2)
        let fourth = send(.tribute, from: friend, to: ama, in: &realm)
        XCTAssertEqual(realm.world.remembered(fourth, for: ama),
                       "\(house)'s last envoy, in watch \(realm.world.watch), came offering a pact, and you swore it. "
                       + "You have turned away 2 of their envoys this age.")
        XCTAssertTrue(realm.world.voiced(fourth).facts.contains(
            "\(house)'s last envoy to \(hers), in watch \(realm.world.watch), came offering a pact, and \(hers) swore it."))
    }

    /// Only the two Houses are told how their envoys were answered, and it
    /// goes with the keeper's own parts of their view.
    func testOnlyTheTwoHousesAreToldHowTheirEnvoysWereAnswered() throws {
        var (realm, ama, bel) = try realm()
        let friend = try steward(at: ama, in: realm)
        let envoy = send(.pact, from: friend, to: ama, in: &realm)
        _ = try realm.perform(.answer(envoy: envoy.id, accept: false), by: "id-ama")
        let hers = try XCTUnwrap(realm.view(for: "id-ama"))
        XCTAssertEqual(hers.world.lastAnswer(from: friend, to: ama)?.answer, .refused)
        XCTAssertNil(try XCTUnwrap(realm.view(for: "id-bel")).world.answers, "Bel's House had no part in it")
        XCTAssertEqual(realm.world.view(for: bel).answers, nil)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        XCTAssertEqual(try RealmView(parts: hers.parts(using: encoder)), hers, "Read back from her view's parts")
        XCTAssertEqual(try RealmState(parts: realm.parts(using: encoder)), realm, "and the realm's")
        // A world kept before envoys were remembered opens with nothing remembered.
        var before = realm.world
        before.answers = nil
        let opened = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(before))
        XCTAssertNil(opened.answers)
        XCTAssertNil(opened.lastAnswer(from: friend, to: ama))
    }

    /// A keeper's own envoy to a steward is remembered as the steward
    /// answered it, and told on the steward's next envoy to them; a trade
    /// turned away is remembered, one the keeper took but couldn't pay is
    /// not; and stewards' dealings among themselves are their own.
    func testAKeepersOwnEnvoysAndTradesAreRememberedAndStewardsDealingsAreTheirOwn() throws {
        var (realm, ama, _) = try realm()
        let friend = try steward(at: ama, in: realm)
        let events = try realm.perform(.propose(.pact, to: friend), by: "id-ama")
        let took = events.contains { event in
            if case .proposalAnswered(.pact, ama, friend, true) = event { return true }
            return false
        }
        XCTAssertEqual(realm.world.lastAnswer(from: ama, to: friend)?.answer, took ? .accepted : .refused)
        XCTAssertEqual(realm.world.lastAnswer(from: ama, to: friend)?.turnedAway, took ? 0 : 1)
        let theirs = send(.peace, from: friend, to: ama, in: &realm)
        XCTAssertEqual(realm.world.remembered(theirs, for: ama),
                       "Your last envoy to them, in watch \(realm.world.watch), came offering a pact, and they \(took ? "swore it" : "turned it away").")
        realm.world.envoys.removeAll { $0.id == theirs.id }

        // A trade turned away is remembered; one taken but not paid is not.
        let other = try XCTUnwrap(realm.world.houses.first { !$0.isPlayer && $0.id != friend }).id
        let trade = Trade(give: .timber, 30, for: .moonsalt, 10)
        let offered = send(.trade, from: other, to: ama, trade: trade, in: &realm)
        realm.world.houses[ama].stock[.moonsalt] = 0
        _ = try realm.perform(.answer(envoy: offered.id, accept: true), by: "id-ama")
        XCTAssertNil(realm.world.lastAnswer(from: other, to: ama), "Taken but not paid: neither taken nor turned away")
        let again = send(.trade, from: other, to: ama, trade: trade, in: &realm)
        _ = try realm.perform(.answer(envoy: again.id, accept: false), by: "id-ama")
        XCTAssertEqual(realm.world.lastAnswer(from: other, to: ama)?.proposal, .trade)
        XCTAssertEqual(realm.world.lastAnswer(from: other, to: ama)?.answer, .refused)
        XCTAssertEqual(realm.world.remembered(send(.pact, from: other, to: ama, in: &realm), for: ama),
                       "\(realm.world.houses[other].title)'s last envoy, in watch \(realm.world.watch), came offering a trade, and you turned it away.")

        // Two stewards' dealings are no keeper's to know.
        var world = realm.world
        world.remember(.pact, from: friend, to: other, answer: .refused)
        XCTAssertNil(world.lastAnswer(from: friend, to: other))
        XCTAssertEqual(world.answers, realm.world.answers)
    }

    func testWhatEachEnvoyCameForAndHowItWasAnsweredIsSaid() {
        XCTAssertEqual(Proposal.allCases.map(\.cameFor),
                       ["asking for peace", "offering a pact", "offering fealty", "demanding tribute", "offering a trade"])
        func said(_ proposal: Proposal, _ answer: EnvoyAnswer.Answer) -> String {
            EnvoyAnswer(from: 1, to: 0, proposal: proposal, watch: 3, answer: answer, turnedAway: 0).said(by: "you")
        }
        XCTAssertEqual(Proposal.allCases.map { said($0, .accepted) },
                       ["you made peace", "you swore it", "you accepted it", "you paid it", "you took it"])
        XCTAssertEqual(Proposal.allCases.map { said($0, .refused) },
                       ["you turned it away", "you turned it away", "you turned it away", "you refused it", "you turned it away"])
        XCTAssertEqual(said(.tribute, .unanswered), "you sent no answer")
    }
}
