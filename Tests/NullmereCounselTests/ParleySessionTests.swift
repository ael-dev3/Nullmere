import Foundation
import FoundationModels
import XCTest
@testable import NullmereCore
@testable import NullmereCounsel

/// A parley's session apart from the model's words: why it can't be had,
/// told plainly and never answered for; the answers its tool puts to the
/// keeper, as the realm would weigh them; offers given once or set aside;
/// an answer that never begins given up, and trouble told as itself. The
/// words themselves are heard on a Mac with Apple Intelligence.
@MainActor
final class ParleySessionTests: XCTestCase {
    /// A keeper's view with a steward's demand of tribute waiting on them,
    /// the steward's House far the stronger.
    private func parley() throws -> EnvoyParley {
        var world = GameState(settings: GameSettings(seedText: "parley session", houseCount: 3, radius: 16, keepers: 1))
        let me = world.player, rival = 1
        world.houses[rival].temperament = .ambitious
        world.units.removeAll { $0.owner == rival || $0.owner == me }
        let mine = try XCTUnwrap(world.seat(of: me)), theirs = try XCTUnwrap(world.seat(of: rival))
        for _ in 0..<3 { XCTAssertNotNil(world.placeUnit(.spear, for: me, near: mine.position)) }
        for _ in 0..<5 { XCTAssertNotNil(world.placeUnit(.spear, for: rival, near: theirs.position)) }
        _ = try world.propose(.tribute, from: rival, to: me)
        let envoy = try XCTUnwrap(world.envoys.first { $0.from == rival && $0.to == me })
        return try XCTUnwrap(EnvoyParley(state: world.view(for: me), player: me, envoy: envoy.id))
    }

    private func session(_ parley: EnvoyParley,
                         availability: SystemLanguageModel.Availability = .unavailable(.deviceNotEligible)) -> EnvoyParleySession {
        EnvoyParleySession(parley: parley, availability: { availability })
    }

    /// Streams kept open until the test is done.
    private var open: [AsyncThrowingStream<String, Error>.Continuation] = []

    override func tearDown() async throws {
        for continuation in open { continuation.finish() }
        open.removeAll()
    }

    private func until(_ what: String, timeout: Double = 10, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return XCTFail("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    /// Spoken with where the model can't answer, the envoy says nothing:
    /// the keeper is told why, and no words are made up in the model's place.
    func testAParleyThatCantBeHadIsNeverAnsweredFor() throws {
        let parley = try parley()
        for availability: SystemLanguageModel.Availability in [.unavailable(.deviceNotEligible), .unavailable(.appleIntelligenceNotEnabled),
                                                               .unavailable(.modelNotReady)] {
            let session = session(parley, availability: availability)
            let trouble = try XCTUnwrap(session.unavailable)
            session.prewarm()
            session.ask("Will your House take less?")
            XCTAssertFalse(session.answering)
            XCTAssertEqual(session.lines.map(\.kind), [.trouble])
            XCTAssertEqual(session.lines.first?.text, trouble.said)
            XCTAssertEqual(session.trouble, trouble)
            XCTAssertTrue(session.exchanges.isEmpty, "Nothing said, nothing kept")
            session.ask("   ")
            XCTAssertEqual(session.lines.count, 1, "Nothing said, nothing told")
        }
    }

    /// An answer the envoy puts to the keeper is weighed as the realm weighs
    /// it, for this envoy: only one the realm would take waits on the
    /// keeper, and the envoy is told either way.
    func testTheEnvoyPutsOnlyWhatTheRealmWouldTake() async throws {
        let parley = try parley()
        let bench = ParleyBench(parley)
        let half = await bench.putAnswer("half")
        XCTAssertEqual(half, "Put to the keeper: \(parley.putAnswer("half").told) The keeper decides, and your House answers it.")
        let danced = await bench.putAnswer("dance")
        XCTAssertEqual(danced, "That cannot be put to the keeper: \(EnvoyParley.onlyTheseAnswers)")
        let taken = await bench.taken()
        XCTAssertEqual(taken.proposals.map(\.command), [.bargain(envoy: parley.envoy.id)])
        XCTAssertEqual(taken.looks, ["Weighed dance, which cannot be given: \(EnvoyParley.onlyTheseAnswers)"])
        let again = await bench.taken()
        XCTAssertTrue(again.looks.isEmpty && again.proposals.isEmpty, "Each taken once")
        // Renewed once its House held to the whole: no half put forward again.
        var held = parley.state
        let index = try XCTUnwrap(held.envoys.firstIndex { $0.id == parley.envoy.id })
        held.envoys[index].bargained = true
        await bench.renew(try XCTUnwrap(EnvoyParley(state: held, player: parley.player, envoy: parley.envoy.id)))
        let refused = await bench.putAnswer("half")
        XCTAssertEqual(refused, "That cannot be put to the keeper: \(RuleError.bargainedAlready.description)")
    }

    /// An answer put to the keeper is given once, or set aside, and never
    /// both; the envoy told of each when the keeper next speaks.
    func testAnAnswerIsGivenOnceOrSetAside() async throws {
        let parley = try parley()
        let session = session(parley, availability: .available)
        _ = await session.bench.putAnswer("accept")
        _ = await session.bench.putAnswer("refuse")
        await session.takeFromBench()
        XCTAssertEqual(session.offers.map(\.state), [.waiting, .waiting])
        let first = session.offers[0], second = session.offers[1]
        XCTAssertEqual(session.give(first), .answer(envoy: parley.envoy.id, accept: true))
        XCTAssertNil(session.give(first), "Given once")
        session.setAside(second)
        XCTAssertNil(session.give(second), "Set aside, never given")
        XCTAssertEqual(session.offers.map(\.state), [.given, .setAside])
        XCTAssertNil(session.give(EnvoyParleySession.Offer(id: 999, proposal: first.proposal)), "None such")
        var prompts: [String] = []
        session.speaker = { prompt in
            prompts.append(prompt)
            return AsyncThrowingStream { continuation in
                continuation.yield("So it shall be told.")
                continuation.finish()
            }
        }
        session.ask("It is done.")
        try await until("the answer") { !session.answering }
        XCTAssertEqual(prompts, ["Since you last spoke: The keeper gave the answer: \(first.proposal.told) "
                                 + "The keeper set aside the answer you put to them: \(second.proposal.told)\n\nIt is done."])
    }

    /// An answer that never begins is given up, and the keeper told so; a
    /// parley outgrown is begun afresh from what was said; the model busy is
    /// said to be; an answer of nothing is garbled, never shown as one.
    func testTroubleIsToldAndAnAnswerThatNeverBeginsIsGivenUp() async throws {
        let parley = try parley()
        let waiting = session(parley, availability: .available)
        waiting.speaker = { [unowned self] _ in
            AsyncThrowingStream { continuation in self.open.append(continuation) }
        }
        waiting.firstWordsLimit = 0.2
        waiting.ask("Speak?")
        try await until("the answer given up") { !waiting.answering }
        XCTAssertEqual(waiting.trouble, .slow)
        XCTAssertEqual(waiting.lines.last?.text, CounselTrouble.slow.said)
        XCTAssertTrue(waiting.exchanges.isEmpty)

        var calls = 0
        let session = session(parley, availability: .available)
        session.speaker = { _ in
            calls += 1
            let call = calls
            return AsyncThrowingStream { continuation in
                switch call {
                case 1: continuation.finish(throwing: CounselTrouble.tooLong)
                case 2:
                    continuation.yield("Begun afresh, keeper.")
                    continuation.finish()
                case 3: continuation.finish(throwing: CounselTrouble.busy)
                default:
                    continuation.yield("  \u{201C}\u{201D} ")
                    continuation.finish()
                }
            }
        }
        session.ask("How long have we spoken?")
        try await until("the answer begun afresh") { !session.answering }
        XCTAssertEqual(calls, 2, "Asked again, afresh")
        XCTAssertEqual(session.lines.last?.text, "Begun afresh, keeper.")
        XCTAssertNil(session.trouble)
        session.ask("Again?")
        try await until("the busy model") { !session.answering }
        XCTAssertEqual(session.trouble, .busy)
        session.ask("And now?")
        try await until("an answer of nothing") { !session.answering }
        XCTAssertEqual(session.trouble, .garbled)
        XCTAssertEqual(session.lines.filter { $0.kind == .commander }.count, 1, "Nothing shown as an answer")
        XCTAssertEqual(session.exchanges.count, 1)
    }
}
