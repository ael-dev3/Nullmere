import AppKit
import FoundationModels
@testable import LauncherKit
import NullmereCounsel
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
        let counsel = try XCTUnwrap(session.counsel)
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
        XCTAssertNil(session.counsel)
        // None but the keeper's own commanders counsel them.
        session.openCounsel(with: 9_999)
        XCTAssertNil(session.counsel)
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
        let counsel = try XCTUnwrap(session.counsel)
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

    /// The check heard on a real Mac: where the model can't speak it says
    /// so and is unverified, never passed; its rules catch what they should.
    func testTheCounselCheckIsUnverifiedWhereTheModelCantSpeak() async {
        let report = await CounselCheck.run(availability: { .unavailable(.deviceNotEligible) })
        XCTAssertTrue(report.unavailable)
        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertTrue(report.text.hasPrefix("Apple's on-device model on this Mac, not ready ("), report.text)
        XCTAssertEqual(CounselCheck.problems(of: "We hold the ford, my keeper.", facts: ""), [])
        XCTAssertEqual(CounselCheck.problems(of: "Charge!", facts: ""), ["an exclamation"])
        XCTAssertEqual(CounselCheck.problems(of: "Some 4000 troops wait.", facts: "4,000"), ["invents the number 4000"])
        XCTAssertEqual(CounselCheck.problems(of: "Some 4,000 troops wait.", facts: "4,000 troops"), [])
        XCTAssertEqual(CounselCheck.problems(of: "This game is long.", facts: ""), ["speaks of \"game\""])
        XCTAssertEqual(CounselCheck.problems(of: String(repeating: "word ", count: 95), facts: ""), ["95 words"])
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
