import Foundation
import FoundationModels
import XCTest
@testable import NullmereCore
@testable import NullmereCounsel

/// Counsel's session apart from the model's words: why it can't be taken,
/// told plainly and never answered for; the looks and proposals its tools
/// make, as the realm would weigh them; offers given once or set aside; and
/// what the commander recalls brought within the model's context. The words
/// themselves are heard on a real Mac (scripts/check-counsel.sh).
@MainActor
final class CounselSessionTests: XCTestCase {
    /// A keeper's House, its first commander at the head of a company of
    /// war, as the keeper's own view holds it.
    private func counsel() throws -> CommanderCounsel {
        var world = GameState(settings: GameSettings(seedText: "counsel session", houseCount: 4, radius: 18, keepers: 1))
        let me = world.player
        let commander = try XCTUnwrap(world.commanders(of: me).first)
        let seat = try XCTUnwrap(world.seat(of: me))
        let spear = try XCTUnwrap(world.units(of: me).first { $0.kind == .spear })
        if let there = world.unit(at: seat.position), let other = world.unitIndex(there.id) {
            world.units[other].position = spear.position
        }
        world.units[try XCTUnwrap(world.unitIndex(spear.id))].position = seat.position
        try world.perform(.assign(commander: commander.id, unit: spear.id), as: me)
        return try XCTUnwrap(CommanderCounsel(state: world.view(for: me), player: me, commander: commander.id))
    }

    private func session(_ counsel: CommanderCounsel, memory: CounselMemory? = nil,
                         availability: SystemLanguageModel.Availability = .unavailable(.deviceNotEligible)) -> CommanderCounselSession {
        CommanderCounselSession(counsel: counsel, memory: memory ?? CounselMemory(commander: counsel.commander.id, age: 1),
                                availability: { availability })
    }

    /// Each reason the model can't be asked is told as itself.
    func testWhyCounselCantBeTakenIsToldPlainly() {
        XCTAssertNil(CommanderCounselSession.trouble(for: .available))
        XCTAssertEqual(CommanderCounselSession.trouble(for: .unavailable(.deviceNotEligible)), .unavailable(.deviceNotEligible))
        XCTAssertEqual(CommanderCounselSession.trouble(for: .unavailable(.appleIntelligenceNotEnabled)), .unavailable(.appleIntelligenceOff))
        XCTAssertEqual(CommanderCounselSession.trouble(for: .unavailable(.modelNotReady)), .unavailable(.modelNotReady))
        XCTAssertEqual(CommanderCounselSession.trouble(from: CounselTrouble.busy), .busy)
        let other = NSError(domain: "stars", code: 7, userInfo: [NSLocalizedDescriptionKey: "The stars are wrong."])
        XCTAssertEqual(CommanderCounselSession.trouble(from: other), .failed("The stars are wrong."))
    }

    /// Asked where the model can't answer, the commander says nothing: the
    /// keeper is told why, and no words are made up in the model's place.
    func testCounselThatCantBeTakenIsNeverAnsweredFor() throws {
        let counsel = try counsel()
        for availability: SystemLanguageModel.Availability in [.unavailable(.deviceNotEligible), .unavailable(.appleIntelligenceNotEnabled),
                                                               .unavailable(.modelNotReady)] {
            let session = session(counsel, availability: availability)
            let trouble = try XCTUnwrap(session.unavailable)
            session.prewarm()
            session.ask("What do you see?")
            XCTAssertFalse(session.answering)
            XCTAssertEqual(session.lines.map(\.kind), [.trouble])
            XCTAssertEqual(session.lines.first?.text, trouble.said)
            XCTAssertEqual(session.trouble, trouble)
            XCTAssertTrue(session.memory.exchanges.isEmpty, "Nothing said, nothing remembered")
            session.ask("   ")
            XCTAssertEqual(session.lines.count, 1, "Nothing asked, nothing told")
        }
    }

    /// The tools' looks tell what the keeper's view tells and are shown as
    /// looks; an order put forward is weighed as the realm weighs it, and
    /// only one it would take waits on the keeper.
    func testTheToolsLookAndProposeAsTheRealmWeighs() async throws {
        let counsel = try counsel()
        let bench = CounselBench(counsel)
        let unit = try XCTUnwrap(counsel.company)
        let handle = try XCTUnwrap(counsel.handle(of: unit))
        let report = await bench.report(on: handle)
        XCTAssertEqual(report, counsel.report(on: handle))
        let look = await bench.lookAround(within: 30)
        XCTAssertEqual(look, counsel.lookAround(within: 8))
        let affairs = await bench.affairs()
        XCTAssertEqual(affairs, counsel.affairs)
        let other = counsel.state.houses[(counsel.player + 1) % counsel.state.houses.count].title
        let house = await bench.house(named: other)
        XCTAssertEqual(house, counsel.report(onHouse: other))
        let given = await bench.propose("fortify", company: handle, place: "")
        XCTAssertTrue(given.hasPrefix("Put forward to your keeper:"))
        let refused = await bench.propose("march", company: "C99", place: "Anywhere")
        XCTAssertTrue(refused.hasPrefix("That cannot be ordered:"))
        let taken = await bench.taken()
        XCTAssertEqual(taken.looks.count, 5, "Four looks and an order weighed and refused: \(taken.looks)")
        XCTAssertTrue(taken.looks.contains("Looked at \(other)"), "\(taken.looks)")
        XCTAssertTrue(taken.looks.last?.contains("cannot be ordered") == true)
        XCTAssertEqual(taken.proposals.map(\.command), [.fortify(unit: unit.id)])
        let again = await bench.taken()
        XCTAssertTrue(again.looks.isEmpty && again.proposals.isEmpty, "Each taken once")
        let told = await bench.told
        XCTAssertEqual(told, [report, look, affairs, house, given, refused])
        // Renewed, the looks tell the world as it now stands.
        var moved = counsel.state
        let index = try XCTUnwrap(moved.unitIndex(unit.id))
        moved.units[index].fortified = true
        await bench.renew(try XCTUnwrap(CommanderCounsel(state: moved, player: counsel.player, commander: counsel.commander.id)))
        let after = await bench.report(on: handle)
        XCTAssertTrue(after.contains("dug in"), after)
    }

    /// An offer is given once, or set aside, and never both.
    func testAnOfferIsGivenOnceOrSetAside() async throws {
        let counsel = try counsel()
        let session = session(counsel)
        let handle = try XCTUnwrap(counsel.company.flatMap(counsel.handle(of:)))
        _ = await session.bench.propose("fortify", company: handle, place: "")
        _ = await session.bench.propose("halt", company: handle, place: "")
        await session.takeFromBench()
        XCTAssertEqual(session.offers.count, 2)
        XCTAssertEqual(session.offers.map(\.state), [.waiting, .waiting])
        let first = session.offers[0], second = session.offers[1]
        XCTAssertEqual(session.give(first), first.proposal.command)
        XCTAssertNil(session.give(first), "Given once")
        session.setAside(second)
        XCTAssertNil(session.give(second), "Set aside, never given")
        XCTAssertEqual(session.offers.map(\.state), [.given, .setAside])
        XCTAssertNil(session.give(CommanderCounselSession.Offer(id: 999, proposal: first.proposal)), "None such")
        XCTAssertEqual(session.lines.filter { $0.kind == .look }.count, 0)
    }

    /// What the commander recalls goes with what they are told, within the
    /// share of the model's context counsel may bring; answers lose the
    /// quotes a model sets about them.
    func testWhatIsRecalledIsBroughtWithinTheContext() throws {
        let counsel = try counsel()
        var memory = CounselMemory(commander: counsel.commander.id, age: 1)
        memory.remember("Where is the enemy?", "Two tiles east, my keeper.", at: 3)
        let session = session(counsel, memory: memory)
        XCTAssertTrue(session.instructions.hasPrefix(counsel.instructions))
        XCTAssertTrue(session.instructions.contains(counsel.briefing))
        XCTAssertTrue(session.instructions.contains("What you recall of earlier counsel with your keeper:"))
        XCTAssertTrue(session.instructions.contains("Two tiles east, my keeper."))
        XCTAssertFalse(self.session(counsel).instructions.contains("What you recall"))
        XCTAssertEqual(CommanderCounselSession.cleaned("  \u{201C}Hold the ford.\u{201D}\n"), "Hold the ford.")
        // New facts, as the watch turns.
        var turned = counsel.state
        turned.watch += 1
        session.renew(try XCTUnwrap(CommanderCounsel(state: turned, player: counsel.player, commander: counsel.commander.id)))
        XCTAssertEqual(session.counsel.state.watch, counsel.state.watch + 1)
        session.stop()
    }

    // MARK: An answer, as counsel handles it

    // What follows holds how counsel handles an answer, each answer spoken
    // by the test in place of the model: shown as it streams, timed, kept,
    // stopped, given up, its trouble told. None of it is the model's words,
    // which are heard on a Mac with Apple Intelligence (CounselCheck).

    /// Streams kept open until the test is done.
    private var open: [AsyncThrowingStream<String, Error>.Continuation] = []

    override func tearDown() async throws {
        for continuation in open { continuation.finish() }
        open.removeAll()
    }

    private func spoken(_ counsel: CommanderCounsel, _ answers: @escaping (String) -> AsyncThrowingStream<String, Error>) -> CommanderCounselSession {
        let session = session(counsel, availability: .available)
        session.speaker = answers
        return session
    }

    private func until(_ what: String, timeout: Double = 10, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return XCTFail("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    /// An answer shown as it is spoken, then whole, trimmed of its quotes;
    /// timed; remembered, and kept where the commander's memory is kept;
    /// what the keeper did since told with what they say next; nothing
    /// asked of nothing, nor while an answer is coming.
    func testAnAnswerIsShownAsItIsSpokenAndRemembered() async throws {
        let counsel = try counsel()
        var asked: [String] = []
        var said: [String] = []
        let session = spoken(counsel) { prompt in
            asked.append(prompt)
            return AsyncThrowingStream { continuation in
                continuation.yield("The water")
                continuation.yield("\u{201C}The water lies still to the east, my keeper.\u{201D}")
                continuation.finish()
            }
        }
        var kept: CounselMemory?
        session.onRemember = { kept = $0 }
        session.ask("   ")
        XCTAssertTrue(session.lines.isEmpty, "Nothing asked")
        session.ask("What do you see?")
        XCTAssertTrue(session.answering)
        XCTAssertEqual(session.partial, "", "Its words to come")
        session.ask("And more?")
        XCTAssertEqual(session.lines.count, 1, "Nothing asked while an answer comes")
        try await until("the answer") { !session.answering }
        XCTAssertEqual(session.lines.map(\.kind), [.keeper, .commander])
        XCTAssertEqual(session.lines.last?.text, "The water lies still to the east, my keeper.")
        XCTAssertNil(session.partial)
        XCTAssertNil(session.trouble)
        let timing = try XCTUnwrap(session.timing)
        XCTAssertLessThanOrEqual(timing.firstWords, timing.whole)
        XCTAssertEqual(session.memory.exchanges.map(\.asked), ["What do you see?"])
        XCTAssertEqual(kept, session.memory, "Kept where the commander's memory is kept")
        XCTAssertEqual(asked, ["What do you see?"])
        said = session.lines.map(\.text)

        // The keeper gives an order the commander put forward: told of it
        // with what they say next.
        let handle = try XCTUnwrap(counsel.company.flatMap(counsel.handle(of:)))
        _ = await session.bench.propose("fortify", company: handle, place: "")
        await session.takeFromBench()
        XCTAssertNotNil(session.give(try XCTUnwrap(session.offers.first)))
        session.ask("Is it done?")
        try await until("the second answer") { !session.answering }
        XCTAssertEqual(asked.count, 2)
        XCTAssertTrue(asked[1].hasPrefix("Since you last spoke: Your keeper gave the order: "), asked[1])
        XCTAssertTrue(asked[1].hasSuffix("\n\nIs it done?"), asked[1])
        XCTAssertEqual(session.memory.exchanges.count, 2)
        XCTAssertEqual(Array(session.lines.map(\.text).prefix(said.count)), said, "What was said stays as it was")
    }

    /// Stopped as it is spoken, an answer stops, says so, and is neither
    /// taken for the answer nor remembered; stopping is no trouble.
    func testAStoppedAnswerStopsAndIsNotRemembered() async throws {
        let counsel = try counsel()
        let session = spoken(counsel) { [unowned self] _ in
            AsyncThrowingStream { continuation in
                continuation.yield("We hold")
                self.open.append(continuation)
            }
        }
        session.ask("Tell me of every company you know, at length.")
        try await until("its first words") { session.partial == "We hold" }
        XCTAssertTrue(session.answering)
        session.stop()
        try await until("the answer stopped") { !session.answering }
        XCTAssertEqual(session.lines.last?.kind, .trouble)
        XCTAssertEqual(session.lines.last?.text, "Stopped.")
        XCTAssertFalse(session.lines.contains { $0.kind == .commander }, "No answer taken from words stopped")
        XCTAssertNil(session.trouble, "Stopping is no trouble")
        XCTAssertTrue(session.memory.exchanges.isEmpty, "Nothing remembered of an answer stopped")
        XCTAssertNil(session.partial)
    }

    /// An answer that never begins is given up, and the keeper told so.
    func testAnAnswerThatNeverBeginsIsGivenUp() async throws {
        let counsel = try counsel()
        let session = spoken(counsel) { [unowned self] _ in
            AsyncThrowingStream { continuation in self.open.append(continuation) }
        }
        session.firstWordsLimit = 0.2
        session.ask("Speak?")
        try await until("the answer given up") { !session.answering }
        XCTAssertEqual(session.trouble, .slow)
        XCTAssertEqual(session.lines.last?.text, CounselTrouble.slow.said)
        XCTAssertTrue(session.memory.exchanges.isEmpty)
    }

    /// No answer, and the system said nothing of why: where the model, asked
    /// again after the failure, says why it can't be asked now (Apple
    /// Intelligence turned off meanwhile), that is told; where it can still
    /// be asked, the silence is, as it was.
    func testASilentFailureTellsWhyTheModelCantBeAskedWhereItSays() async throws {
        let counsel = try counsel()
        let stock = NSError(domain: "FoundationModels.LanguageModelSession.GenerationError", code: -1)
        var asked = 0
        let session = CommanderCounselSession(counsel: counsel, memory: CounselMemory(commander: counsel.commander.id, age: 1),
                                              availability: {
                                                  asked += 1
                                                  return asked == 1 ? .available : .unavailable(.appleIntelligenceNotEnabled)
                                              })
        session.speaker = { _ in AsyncThrowingStream { $0.finish(throwing: stock) } }
        session.ask("Speak?")
        try await until("the silence told") { !session.answering }
        XCTAssertEqual(session.trouble, .unavailable(.appleIntelligenceOff))
        XCTAssertEqual(session.lines.last?.text, CounselTrouble.unavailable(.appleIntelligenceOff).said)
        let still = spoken(counsel) { _ in AsyncThrowingStream { $0.finish(throwing: stock) } }
        still.ask("Speak?")
        try await until("the silence") { !still.answering }
        XCTAssertEqual(still.trouble, .silent)
        XCTAssertEqual(CommanderCounselSession.trouble(from: stock, availability: { .unavailable(.modelNotReady) }), .unavailable(.modelNotReady))
        XCTAssertEqual(CommanderCounselSession.trouble(from: CounselTrouble.busy, availability: { .unavailable(.modelNotReady) }), .busy,
                       "Only silence is asked about again")
    }

    /// Trouble told as itself: counsel outgrown is begun afresh from what
    /// the commander remembers and answered; the model busy is said to be;
    /// an answer of nothing is garbled, never shown as an answer.
    func testTroubleIsToldAndCounselOutgrownIsBegunAfresh() async throws {
        let counsel = try counsel()
        var calls = 0
        let session = spoken(counsel) { _ in
            calls += 1
            let call = calls
            return AsyncThrowingStream { continuation in
                switch call {
                case 1: continuation.finish(throwing: CounselTrouble.tooLong)
                case 2:
                    continuation.yield("Begun afresh, my keeper.")
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
        XCTAssertEqual(session.lines.last?.text, "Begun afresh, my keeper.")
        XCTAssertNil(session.trouble)
        session.ask("Again?")
        try await until("the busy model") { !session.answering }
        XCTAssertEqual(session.trouble, .busy)
        XCTAssertEqual(session.lines.last?.text, CounselTrouble.busy.said)
        session.ask("Once more?")
        try await until("nothing said") { !session.answering }
        XCTAssertEqual(session.trouble, .garbled)
        XCTAssertEqual(session.lines.last?.kind, .trouble)
        XCTAssertEqual(session.memory.exchanges.count, 1, "Only the answer given is remembered")
        // Trouble from elsewhere, told as the system told it.
        let other = NSError(domain: "lake", code: 3, userInfo: [NSLocalizedDescriptionKey: "the line went still"])
        XCTAssertEqual(CommanderCounselSession.trouble(from: other), .failed("the line went still"))
    }
}
