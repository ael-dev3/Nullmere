import AppKit
import FoundationModels
@testable import LauncherKit
@testable import NullmereCounsel
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// Counsel taken of a commander in the game: opened from the Commanders,
/// its sheet drawn with its words, looks and offers, what the commander
/// remembers kept for the age, the facts renewed as the world changes, and
/// where the model can't speak, the keeper told why and nothing answered
/// for. The model's own words are heard on a real Mac (CounselCheck).
@MainActor
final class CounselSheetTests: XCTestCase {
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

    private func session(store: LocalStore? = nil) -> (GameSession, CounselLink) {
        let state = GameState(settings: GameSettings(seedText: "counsel sheet", houseCount: 4, radius: 18, keepers: 1))
        let link = CounselLink()
        let session = GameSession(link: link, house: state.player, world: state.view(for: state.player),
                                  store: store ?? LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)))
        session.dismissSeatBriefing()
        session.counselAvailability = { .unavailable(.deviceNotEligible) }
        return (session, link)
    }

    /// Opened from the Commanders, closed again; where the model can't
    /// speak, the keeper is told why and no words come in its place.
    func testCounselIsTakenFromTheCommandersAndToldWhyItCantBe() throws {
        let (session, link) = session()
        let commander = try XCTUnwrap(session.state.commanders(of: session.player).first)
        draw(CommandersPanel(session: session))
        XCTAssertTrue(PressableButtons.press("Take counsel"), "Among \(shown)")
        let counsel = try XCTUnwrap(session.commanderCounsel)
        XCTAssertEqual(counsel.id, commander.id)
        XCTAssertEqual(counsel.unavailable, .unavailable(.deviceNotEligible))
        draw(CounselSheet(session: session, counsel: counsel))
        XCTAssertFalse(PressableButtons.press("Ask"), "Nothing to ask with while the model can't speak")
        counsel.ask("What do you see?")
        XCTAssertEqual(counsel.lines.map(\.kind), [.trouble])
        XCTAssertEqual(counsel.lines.first?.text, CounselTrouble.unavailable(.deviceNotEligible).said)
        draw(CounselSheet(session: session, counsel: counsel))
        XCTAssertTrue(link.sent.isEmpty, "Counsel orders nothing of itself")
        session.closeCounsel()
        XCTAssertNil(session.commanderCounsel)
        // None but the keeper's own commanders counsel them.
        session.openCounsel(with: 9_999)
        XCTAssertNil(session.commanderCounsel)
    }

    /// Counsel opened for CI's screenshot (NULLMERE_SHOW=counsel, a debug
    /// build's alone) is taken of the House's first commander free to
    /// speak, passing over one held prisoner, as the Commanders offer it;
    /// where the model can't be asked nothing is put to them, and the sheet
    /// says why. Where it can, the question is put as the sheet's Ask puts
    /// it, and the model's answer is heard on a real Mac.
    func testCounselOpenedToBeSeenPassesOverAPrisonerAndAsksNothingThatCantBeAnswered() throws {
        var state = GameState(settings: GameSettings(seedText: "counsel sheet", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        _ = state.commanderJoins(me, why: "answers the banner of")
        let roster = state.commanders(of: me)
        XCTAssertEqual(roster.count, 2)
        let captor = try XCTUnwrap(state.houses.indices.first { $0 != me })
        func hold(_ commander: Commander) throws {
            let index = try XCTUnwrap(state.commanders?.firstIndex { $0.id == commander.id })
            let held = Captivity(by: captor, since: state.watch, questioned: 0, lastQuestioned: nil)
            state.commanders?[index].captive = held
        }
        func keeping() -> GameSession {
            let keeping = GameSession(link: CounselLink(), house: me, world: state.view(for: me),
                                      store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)))
            keeping.dismissSeatBriefing()
            keeping.counselAvailability = { .unavailable(.deviceNotEligible) }
            return keeping
        }
        try hold(roster[0])
        let opened = keeping()
        opened.takeCounselToBeSeen()
        let counsel = try XCTUnwrap(opened.commanderCounsel)
        XCTAssertEqual(counsel.id, roster[1].id, "The prisoner is passed over")
        XCTAssertEqual(counsel.unavailable, .unavailable(.deviceNotEligible))
        XCTAssertTrue(counsel.lines.isEmpty, "Nothing is asked that can't be answered")
        draw(CounselSheet(session: opened, counsel: counsel))
        XCTAssertFalse(PressableButtons.press("Ask"), "Nothing to ask with while the model can't speak")
        opened.closeCounsel()
        // Every commander held: no counsel is opened at all.
        try hold(roster[1])
        let none = keeping()
        none.takeCounselToBeSeen()
        XCTAssertNil(none.commanderCounsel)
    }

    /// What the commander remembers is kept for the age and picked up when
    /// counsel is taken again; the facts follow the world as it changes.
    func testWhatIsRememberedIsKeptAndTheFactsFollowTheWorld() throws {
        let store = LocalStore(directory: dir.appendingPathComponent("kept"))
        let (session, _) = session(store: store)
        let commander = try XCTUnwrap(session.state.commanders(of: session.player).first)
        var memory = CounselMemory(commander: commander.id, age: 1)
        memory.remember("Hold the ford?", "We hold it, my keeper.", at: 2)
        store.saveCounsel(memory)
        XCTAssertEqual(store.loadCounsel(commander: commander.id), memory)
        XCTAssertNil(store.loadCounsel(commander: 4_321))
        session.openCounsel(with: commander.id)
        let counsel = try XCTUnwrap(session.commanderCounsel)
        XCTAssertEqual(counsel.memory, memory)
        // An order carried out: the commander's counsel sees the world after it.
        let company = try XCTUnwrap(session.state.units(of: session.player).first { $0.kind.isMilitary })
        XCTAssertTrue(session.perform(.fortify(unit: company.id)))
        XCTAssertEqual(counsel.counsel.state.unit(company.id)?.fortified, true)
        // An offer it never made is no order at all.
        let offer = CommanderCounselSession.Offer(id: 77, proposal: CounselProposal(line: "FORTIFY C1", told: "Dig in.",
                                                                                     command: .fortify(unit: company.id), why: nil))
        session.give(offer)
        XCTAssertEqual(counsel.offers.count, 0)
    }

    private func until(_ what: String, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(10)
        while !condition() {
            if Date() > deadline { return XCTFail("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    /// Where the model can be asked: the sheet asks for the keeper's words;
    /// shows an answer as it streams, with Stop, which stops it; then a whole
    /// answer and how long it took; and the order the commander puts
    /// forward, which the keeper gives from the sheet and the realm is sent
    /// as any order. The answers here are the test's, to hold the sheet to
    /// them; the model's own are heard on a Mac with Apple Intelligence.
    func testWhereTheModelCanBeAskedTheSheetShowsTheAnswerAsItComes() async throws {
        let (session, link) = session()
        var ready = false
        session.counselAvailability = { ready ? .available : .unavailable(.deviceNotEligible) }
        let commander = try XCTUnwrap(session.state.commanders(of: session.player).first)
        session.openCounsel(with: commander.id)
        let counsel = try XCTUnwrap(session.commanderCounsel)
        ready = true
        XCTAssertNil(counsel.unavailable)
        draw(CounselSheet(session: session, counsel: counsel))

        // Spoken as it comes, and stopped.
        var speaking: AsyncThrowingStream<String, Error>.Continuation?
        counsel.speaker = { _ in AsyncThrowingStream { speaking = $0 } }
        counsel.ask("What do you see?")
        try await until("the answer begun") { speaking != nil }
        speaking?.yield("The water lies still")
        try await until("its first words") { counsel.partial == "The water lies still" }
        draw(CounselSheet(session: session, counsel: counsel))
        XCTAssertTrue(PressableButtons.press("Stop"), "Among \(shown)")
        try await until("the answer stopped") { !counsel.answering }
        XCTAssertEqual(counsel.lines.last?.text, "Stopped.")
        speaking?.finish()

        // A whole answer, timed.
        counsel.speaker = { _ in
            AsyncThrowingStream { continuation in
                continuation.yield("We hold the ford, my keeper.")
                continuation.finish()
            }
        }
        counsel.ask("Do we hold the ford?")
        try await until("the whole answer") { !counsel.answering }
        XCTAssertEqual(counsel.lines.last?.text, "We hold the ford, my keeper.")
        XCTAssertNotNil(counsel.timing)
        draw(CounselSheet(session: session, counsel: counsel))

        // An order put forward, given from the sheet, sent to the realm.
        let company = try XCTUnwrap(session.state.units(of: session.player).first { $0.kind.isMilitary && !$0.fortified })
        let handle = try XCTUnwrap(counsel.counsel.handle(of: company))
        _ = await counsel.bench.propose("fortify", company: handle, place: "")
        await counsel.takeFromBench()
        XCTAssertEqual(counsel.offers.map(\.state), [.waiting])
        draw(CounselSheet(session: session, counsel: counsel))
        XCTAssertTrue(PressableButtons.press("Give the order"), "Among \(shown)")
        XCTAssertEqual(counsel.offers.map(\.state), [.given])
        XCTAssertEqual(link.sent, [.fortify(unit: company.id)])
        draw(CounselSheet(session: session, counsel: counsel))
        session.closeCounsel()
    }

    /// A field of battle the House's commander led its company in, as its
    /// report is filed on the Mac.
    private func battleLed(by commander: Commander, in session: GameSession) throws -> BattleReport {
        let me = session.player
        let company = try XCTUnwrap(session.state.units(of: me).first { $0.kind.isMilitary })
        let foe = try XCTUnwrap(session.state.houses.indices.first { $0 != me })
        var field = Field(id: 70, at: company.position, joined: session.state.watch, first: me, second: foe)
        var ours = Fighter(unit: company.id, owner: me, side: 0, kind: company.kind, tier: 1, leader: commander.name, troops: 1_200)
        ours.slain = 700
        ours.lost = 200
        var theirs = Fighter(unit: 9_000, owner: foe, side: 1, kind: .spear, tier: 1, leader: nil, troops: 1_000)
        theirs.lost = 700
        theirs.fell = true
        theirs.standing = false
        field.fighters = [ours, theirs]
        field.held = 0
        session.showBlows([.fieldEnded(field)])
        return try XCTUnwrap(session.reports.first)
    }

    /// A battle a commander led in, from its report: the report offers to
    /// ask them of it, and counsel opens with them, briefed with the battle
    /// as its report reads; where the model can't be asked, nothing is put
    /// to them and the sheet says why (where it can, the question is put as
    /// `CommanderCounsel.askedOf` words it, and answered on a real Mac). A
    /// report naming none of the House's commanders offers no one, and
    /// CI's photograph after the House has been played a while asks of the
    /// latest battle, or takes counsel as it does at the first watch.
    func testACommanderIsAskedOfABattleTheyLedFromItsReport() throws {
        let (session, link) = session()
        let commander = try XCTUnwrap(session.state.commanders(of: session.player).first)
        // No report names one yet: CI's photograph shows the House's reports instead.
        session.askOfABattleToBeSeen()
        XCTAssertNil(session.commanderCounsel)
        XCTAssertEqual(session.panel, .chronicle)
        XCTAssertEqual(session.chronicleOpensOn, .reports)
        draw(ChroniclePanel(session: session, shown: session.chronicleOpensOn))
        session.panel = nil

        let report = try battleLed(by: commander, in: session)
        XCTAssertEqual(report.led, [commander.name])
        XCTAssertEqual(session.askable(of: report)?.id, commander.id)
        PressableButtons.forget(ReportList.ask(commander))
        draw(ReportList(session: session))
        XCTAssertTrue(PressableButtons.press("Ask \(commander.name) of it"), "Among \(shown)")
        let counsel = try XCTUnwrap(session.commanderCounsel)
        XCTAssertEqual(counsel.id, commander.id)
        XCTAssertEqual(counsel.counsel.battles.map(\.id), [report.id], "Briefed with the battle they led")
        XCTAssertTrue(counsel.counsel.briefing.contains("In watch \(report.watch), \(report.place): \(report.title)."), counsel.counsel.briefing)
        XCTAssertTrue(counsel.counsel.briefing.contains("led by \(commander.name)"), counsel.counsel.briefing)
        XCTAssertEqual(counsel.counsel.remembersSaid, "Remembers the fight \(report.place) in watch \(report.watch), won.", "Said on the sheet")
        XCTAssertTrue(counsel.lines.isEmpty, "Nothing is asked that can't be answered")
        XCTAssertEqual(counsel.unavailable, .unavailable(.deviceNotEligible))
        draw(CounselSheet(session: session, counsel: counsel))
        session.closeCounsel()

        // The photograph after a while asks of that battle, as from its
        // report, the House's reports open beside it.
        session.askOfABattleToBeSeen()
        XCTAssertEqual(session.commanderCounsel?.counsel.battles.map(\.id), [report.id])
        XCTAssertEqual(session.panel, .chronicle)
        XCTAssertEqual(session.chronicleOpensOn, .reports)
        session.closeCounsel()
        session.panel = nil

        // A report naming none of the House's commanders offers no one.
        var plain = report
        plain.led = ["Nobody of Ours"]
        XCTAssertNil(session.askable(of: plain))
        session.ask(of: plain)
        XCTAssertNil(session.commanderCounsel)
        XCTAssertTrue(link.sent.isEmpty, "Counsel orders nothing of itself")
    }

    /// Every kind of line and every state of an offer is drawn.
    func testEveryLineAndOfferIsDrawn() {
        for kind: CommanderCounselSession.Line.Kind in [.keeper, .commander, .look, .trouble] {
            draw(CounselLineView(line: .init(id: 1, kind: kind, text: "Two tiles east."), commander: "Aldric"))
        }
        let proposal = CounselProposal(line: "FORTIFY C1", told: "Your Spears dig in.", command: .fortify(unit: 1), why: nil)
        var given = 0, setAside = 0
        draw(OfferCard(offer: .init(id: 1, proposal: proposal), give: { given += 1 }, setAside: { setAside += 1 }))
        XCTAssertTrue(PressableButtons.press("Give the order"), "Among \(shown)")
        draw(OfferCard(offer: .init(id: 1, proposal: proposal), give: { given += 1 }, setAside: { setAside += 1 }))
        XCTAssertTrue(PressableButtons.press("Set aside"))
        XCTAssertEqual(given, 1)
        XCTAssertEqual(setAside, 1)
        draw(OfferCard(offer: .init(id: 1, proposal: proposal, state: .given), give: {}, setAside: {}))
        draw(OfferCard(offer: .init(id: 1, proposal: proposal, state: .setAside), give: {}, setAside: {}))
    }
}

private final class CounselLink: RealmLink {
    var onEvent: ((RealmEvent) -> Void)?
    private(set) var sent: [Command] = []
    func connect() {}
    func arrive(name: String?) {}
    func send(_ command: Command) { sent.append(command) }
    func setReady(_ ready: Bool) {}
    func leave() {}
}
