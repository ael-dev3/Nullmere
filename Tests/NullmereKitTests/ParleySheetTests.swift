import AppKit
import FoundationModels
@testable import LauncherKit
@testable import NullmereCounsel
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// A parley with an envoy waiting on the keeper, in the game: opened from a
/// steward's envoy card (a keeper's envoy has none), its sheet drawn with the
/// envoy's words and the answers it puts to the keeper, each given as any
/// answer is, for the realm to weigh; the envoy told what changed as the
/// realm moves on, and the parley ended with the envoy gone; where the model
/// can't speak, the keeper told why and nothing answered for. The answers
/// here are the test's, to hold the sheet to them; the model's own words are
/// heard on a Mac with Apple Intelligence.
@MainActor
final class ParleySheetTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        PressableButtons.isListening = true
    }

    override func tearDown() async throws {
        PressableButtons.isListening = false
        try? FileManager.default.removeItem(at: dir)
    }

    private func draw(_ view: some View, width: CGFloat = 480, height: CGFloat = 900) {
        PressableButtons.isListening = true
        let renderer = ImageRenderer(content: view.frame(width: width, height: height).background(Color.black))
        renderer.scale = 1
        XCTAssertNotNil(renderer.cgImage)
    }

    private var shown: [String] { PressableButtons.actions.keys.sorted() }

    /// A keeper's session with a steward's demand of tribute waiting on
    /// them, envoy 805, where the model can't be asked.
    private func session() -> (session: GameSession, link: ParleyLink, steward: Int, keeper: Int) {
        var state = GameState(settings: GameSettings(seedText: "parley sheet", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let others = state.houses.map(\.id).filter { $0 != me }
        let steward = others[0], keeper = others[1]
        state.houses[keeper].isPlayer = true
        state.envoys.append(Envoy(id: 805, from: steward, to: me, proposal: .tribute, arrived: state.watch))
        let link = ParleyLink()
        let session = GameSession(link: link, house: me, world: state.view(for: me),
                                  store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)))
        session.dismissSeatBriefing()
        session.counselAvailability = { .unavailable(.deviceNotEligible) }
        return (session, link, steward, keeper)
    }

    private func until(_ what: String, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(10)
        while !condition() {
            if Date() > deadline { return XCTFail("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    /// Opened from a steward's envoy card, closed again; where the model
    /// can't speak, the keeper is told why and no words come in its place.
    /// A keeper's envoy carries a person's own words, and has no parley.
    func testAStewardsEnvoyIsParleyedWithFromItsCardAndToldWhyItCantBe() throws {
        let (session, link, steward, keeper) = session()
        draw(EnvoyCards(session: session))
        XCTAssertTrue(PressableButtons.press("Parley"), "Among \(shown)")
        let parley = try XCTUnwrap(session.envoyParley)
        XCTAssertEqual(parley.id, 805)
        XCTAssertEqual(parley.parley.house.id, steward)
        XCTAssertEqual(parley.unavailable, .unavailable(.deviceNotEligible))
        draw(ParleySheet(session: session, parley: parley))
        XCTAssertFalse(PressableButtons.press("Speak"), "Nothing to speak through while the model can't")
        // Nothing said and no model to say it: the sheet keeps to what it tells.
        let told = NSHostingView(rootView: ParleySheet(session: session, parley: parley)).fittingSize
        XCTAssertEqual(told.width, 480)
        XCTAssertLessThan(told.height, 400, "no empty conversation under why it can't be")
        parley.ask("Will your House take less?")
        XCTAssertEqual(parley.lines.map(\.kind), [.trouble])
        XCTAssertEqual(parley.lines.first?.text, CounselTrouble.unavailable(.deviceNotEligible).said)
        XCTAssertTrue(parley.exchanges.isEmpty, "Nothing said, nothing kept")
        draw(ParleySheet(session: session, parley: parley))
        XCTAssertEqual(NSHostingView(rootView: ParleySheet(session: session, parley: parley)).fittingSize.height, 540,
                       "something said: the conversation shown at its full height")
        XCTAssertTrue(link.sent.isEmpty, "A parley answers nothing of itself")
        session.closeParley()
        XCTAssertNil(session.envoyParley)

        // A keeper's envoy: no Parley on its card, and none opened.
        var demanded = session.state
        demanded.envoys = [Envoy(id: 806, from: keeper, to: session.player, proposal: .tribute, arrived: demanded.watch)]
        link.onEvent?(.changed(demanded))
        draw(EnvoyCards(session: session))
        XCTAssertNil(PressableButtons.actions["Parley"], "Among \(shown)")
        session.openParley(with: 806)
        XCTAssertNil(session.envoyParley)
    }

    /// Where the model can be asked: an answer shown as it streams, with
    /// Stop, which stops it; then a whole answer, timed, and what was said
    /// kept for the parley to be begun afresh from; the answer the envoy
    /// puts to the keeper, given from the sheet and sent to the realm as
    /// any answer is; the realm's word told to the envoy when next the
    /// keeper speaks; and the envoy gone, the parley ended, said once.
    func testWhereTheModelCanSpeakTheEnvoyAnswersAndPutsTheAnswerToTheKeeper() async throws {
        let (session, link, steward, _) = session()
        var ready = false
        session.counselAvailability = { ready ? .available : .unavailable(.deviceNotEligible) }
        session.openParley(with: 805)
        let parley = try XCTUnwrap(session.envoyParley)
        ready = true
        XCTAssertNil(parley.unavailable)
        draw(ParleySheet(session: session, parley: parley))

        // Spoken as it comes, and stopped.
        var speaking: AsyncThrowingStream<String, Error>.Continuation?
        parley.speaker = { _ in AsyncThrowingStream { speaking = $0 } }
        parley.ask("Will your House take less?")
        try await until("the answer begun") { speaking != nil }
        speaking?.yield("My House asks")
        try await until("its first words") { parley.partial == "My House asks" }
        draw(ParleySheet(session: session, parley: parley))
        XCTAssertTrue(PressableButtons.press("Stop"), "Among \(shown)")
        try await until("the answer stopped") { !parley.answering }
        XCTAssertEqual(parley.lines.last?.text, "Stopped.")
        XCTAssertTrue(parley.exchanges.isEmpty, "Nothing kept of an answer stopped")
        speaking?.finish()

        // A whole answer, timed, and kept for the parley.
        var prompts: [String] = []
        parley.speaker = { prompt in
            prompts.append(prompt)
            return AsyncThrowingStream { continuation in
                continuation.yield("\u{201C}Then offer half, and my House will weigh it.\u{201D}")
                continuation.finish()
            }
        }
        parley.ask("I would offer half.")
        try await until("the whole answer") { !parley.answering }
        XCTAssertEqual(parley.lines.last?.text, "Then offer half, and my House will weigh it.")
        XCTAssertNotNil(parley.timing)
        XCTAssertEqual(parley.exchanges.map(\.asked), ["I would offer half."])
        XCTAssertTrue(parley.instructions.hasPrefix(parley.parley.instructions))
        XCTAssertTrue(parley.instructions.contains(parley.parley.briefing))
        XCTAssertTrue(parley.instructions.contains("What was said so far in this parley:\nThe keeper: I would offer half.\n"
                                                   + "You: Then offer half, and my House will weigh it."), parley.instructions)
        XCTAssertEqual(prompts, ["I would offer half."])

        // The answer it puts to the keeper, given from the sheet, sent as any answer is.
        _ = await parley.bench.putAnswer("half")
        await parley.takeFromBench()
        XCTAssertEqual(parley.offers.map(\.proposal.command), [.bargain(envoy: 805)])
        draw(ParleySheet(session: session, parley: parley))
        XCTAssertTrue(PressableButtons.press("Give the answer"), "Among \(shown)")
        XCTAssertEqual(parley.offers.map(\.state), [.given])
        XCTAssertEqual(link.sent, [.bargain(envoy: 805)])

        // The realm's word: its steward held to the whole, told to the envoy
        // with what the keeper says next.
        var held = session.state
        held.envoys = [Envoy(id: 805, from: steward, to: session.player, proposal: .tribute, arrived: held.watch, bargained: true)]
        link.onEvent?(.changed(held))
        XCTAssertEqual(parley.parley.envoy.bargained, true)
        parley.ask("Will you not take it?")
        try await until("the third answer") { !parley.answering }
        let last = try XCTUnwrap(prompts.last)
        XCTAssertTrue(last.hasPrefix("Since you last spoke: The keeper gave the answer: "), last)
        XCTAssertTrue(last.contains("The keeper offered half your demand, and your House held to the whole."), last)
        XCTAssertTrue(last.hasSuffix("\n\nWill you not take it?"), last)

        // Answered, the envoy goes home, and the parley ends, said once.
        var answered = session.state
        answered.envoys = []
        link.onEvent?(.changed(answered))
        XCTAssertTrue(parley.gone)
        let title = session.state.houses[steward].title
        XCTAssertEqual(parley.lines.last?.text, "The envoy of \(title) has gone.")
        draw(ParleySheet(session: session, parley: parley))
        XCTAssertNil(PressableButtons.actions["Speak"], "Nothing more asked of an envoy gone, among \(shown)")
        let said = parley.lines.count
        parley.ask("Wait.")
        parley.renew(nil)
        XCTAssertEqual(parley.lines.count, said, "Said once, and nothing asked")
        session.closeParley()
    }
}

private final class ParleyLink: RealmLink {
    var onEvent: ((RealmEvent) -> Void)?
    private(set) var sent: [Command] = []
    func connect() {}
    func arrive(name: String?) {}
    func send(_ command: Command) { sent.append(command) }
    func setReady(_ ready: Bool) {}
    func leave() {}
}
