import AppKit
@testable import LauncherKit
import NullmereModels
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// A plea at the gate on the Mac: the card beside the world while one
/// waits, the petitioner painted from the townsfolk, the plea and what
/// turning it away costs in the realm's words, Grant (with its price, off
/// while the House hasn't it) and Turn away sent to the realm as the
/// keeper's answer; the petitioner's own words asked of this Mac's model
/// under their own key; nothing while no plea waits.
@MainActor
final class PetitionCardTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        PressableButtons.isListening = true
    }

    override func tearDown() async throws {
        PressableButtons.isListening = false
        try? FileManager.default.removeItem(at: dir)
    }

    private func draw(_ view: some View) {
        PressableButtons.isListening = true
        let renderer = ImageRenderer(content: view.frame(width: 420, height: 520).background(Color.black))
        renderer.scale = 1
        XCTAssertNotNil(renderer.cgImage)
    }

    private var shown: [String] { PressableButtons.actions.keys.sorted() }

    /// A keeper's House whose seat's ward is broken, its masons at the gate.
    private func session(stock: Stock = Stock(grain: 500, timber: 500, stone: 500, moonsalt: 50),
                         voice: (any Voice)? = nil) throws -> (GameSession, PleaLink, Petition) {
        var state = GameState(settings: GameSettings(seedText: "a plea at the gate", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        state.watch = Petition.from
        let seat = try XCTUnwrap(state.holdIndex(try XCTUnwrap(state.holds(of: me).first { $0.isSeat }).id))
        state.holds[seat].ward = 1
        state.houses[me].stock = stock
        _ = state.bringPetitions()
        let petition = try XCTUnwrap(state.petition(of: me))
        let link = PleaLink()
        let session = GameSession(link: link, house: me, world: state.view(for: me),
                                  store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)), voice: voice)
        session.dismissSeatBriefing()
        return (session, link, petition)
    }

    func testThePleaIsGrantedOrTurnedAwayFromItsCard() throws {
        let (session, link, petition) = try session()
        XCTAssertEqual(petition.plea, .mend)
        // As a window draws it, the petitioner painted, kept with CI's screenshots.
        Portraits.shared.prepareNow()
        try CardShot.keep(PetitionCard(session: session).padding(30), as: "game-petition.png")
        draw(PetitionCard(session: session))
        let grant = PetitionCard.grant(petition)
        XCTAssertEqual(grant, "Grant, for \(petition.price)")
        XCTAssertTrue(PressableButtons.press(grant), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .answerPetition(petition.id, grant: true))
        let (other, otherLink, _) = try self.session()
        draw(PetitionCard(session: other))
        XCTAssertTrue(PressableButtons.press("Turn away"), "Among \(shown)")
        XCTAssertEqual(otherLink.sent.last, .answerPetition(petition.id, grant: false))
    }

    /// Parley on the card opens a parley with the petitioner, through this
    /// Mac's model; the answer they put to the keeper is given from it as
    /// any answer is, and once the plea is answered the parley ends.
    func testThePetitionerIsParleyedWithFromTheCard() throws {
        let (session, link, petition) = try session()
        // Opened where no model is warmed.
        session.counselAvailability = { .unavailable(.deviceNotEligible) }
        draw(PetitionCard(session: session))
        XCTAssertTrue(PressableButtons.press("Parley"), "Among \(shown)")
        let parley = try XCTUnwrap(session.parley)
        XCTAssertEqual(parley.subject, .petition(petition.id))
        XCTAssertEqual(parley.parley.named, session.state.petitioner(of: petition))
        XCTAssertEqual(parley.parley.summary, session.state.asked(by: petition))
        XCTAssertTrue(link.sent.isEmpty, "A parley answers nothing of itself")
        let offered = parley.parley.putAnswer("grant")
        XCTAssertEqual(offered.command, .answerPetition(petition.id, grant: true))
        XCTAssertEqual(offered.told, session.state.grantSaid(petition))
        // Answered from the card itself, the plea is gone and so is the parley.
        draw(PetitionCard(session: session))
        XCTAssertTrue(PressableButtons.press(PetitionCard.grant(petition)), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .answerPetition(petition.id, grant: true))
        XCTAssertTrue(parley.gone)
        XCTAssertEqual(parley.lines.last?.text, "\(petition.name) has gone.")
        session.closeParley()
    }

    func testAPoorHouseCanOnlyTurnThePleaAway() throws {
        let (session, link, petition) = try session(stock: .zero)
        PressableButtons.forget(PetitionCard.grant(petition))
        draw(PetitionCard(session: session))
        XCTAssertFalse(PressableButtons.press(PetitionCard.grant(petition)), "Grant is off while the House hasn't what the folk ask")
        XCTAssertTrue(link.sent.isEmpty)
        XCTAssertEqual(PetitionCard.why(.shortOf(petition.price)), RuleError.shortOf(petition.price).description)
        XCTAssertEqual(PetitionCard.why(.notApplicable), "Their need has passed.")
        XCTAssertTrue(PressableButtons.press("Turn away"), "Among \(shown)")
        XCTAssertEqual(link.sent, [.answerPetition(petition.id, grant: false)])
    }

    func testThePetitionerIsPaintedAndVoicedUnderTheirOwnKey() throws {
        let (session, _, petition) = try session()
        XCTAssertEqual(Petition.Plea.allCases.map { PetitionCard.variant(of: $0) }, [Folk.porter, Folk.timberCarter, Folk.elder, Folk.farmhand, Folk.waterCarrier])
        XCTAssertEqual(PetitionCard.waits(petition, at: petition.arrived), "Waits \(Petition.patience) watches")
        XCTAssertEqual(PetitionCard.waits(petition, at: petition.arrived + Petition.patience - 1), "Waits this watch")
        XCTAssertEqual(GameSession.Spoken.petition(petition.id).key, "petition-\(petition.id)")
        XCTAssertEqual(GameSession.Spoken(key: "petition-\(petition.id)"), .petition(petition.id))
        let moment = VoiceFacts.petition(petition, in: session.state)
        XCTAssertEqual(moment.kind, .petition)
        XCTAssertEqual(moment.facts, session.state.voiced(petition).facts)
        XCTAssertTrue(moment.prompt.hasPrefix(Voicing.petitionTask), moment.prompt)
        // Heard as it comes and as it is answered, never by another House.
        let me = session.player, state = session.state
        XCTAssertEqual(GameSession.cue(forDepth: .petitionBrought(petition), in: state, player: me), .parley)
        XCTAssertEqual(GameSession.cue(forDepth: .petitionAnswered(petition, granted: true, silently: false), in: state, player: me), .coin)
        XCTAssertEqual(GameSession.cue(forDepth: .petitionAnswered(petition, granted: false, silently: true), in: state, player: me), .refusal)
        XCTAssertNil(GameSession.cue(forDepth: .petitionBrought(petition), in: state, player: (me + 1) % state.houses.count))
        // Its coming, its answer and its withdrawal are told as the realm words them.
        for event: GameEvent in [.petitionBrought(petition), .petitionAnswered(petition, granted: false, silently: true), .petitionWithdrawn(petition)] {
            XCTAssertEqual(Narration.line(for: event, in: session.state, viewer: session.player)?.text,
                           session.state.tidings(of: event, for: session.player)?.text)
        }
        // None waiting, nothing drawn.
        let plain = GameState(settings: GameSettings(seedText: "no plea", houseCount: 4, radius: 18, keepers: 1))
        let quiet = GameSession(link: PleaLink(), house: plain.player, world: plain.view(for: plain.player),
                                store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)))
        PressableButtons.forget("Turn away")
        draw(PetitionCard(session: quiet))
        XCTAssertFalse(PressableButtons.press("Turn away"))
    }

    /// The petitioner's words still being asked of the model when the plea
    /// is answered are stopped there, the model free at once for what still
    /// waits; and words a voice gives all the same once stopped are not kept.
    func testThePetitionersWordsAreStoppedWhenThePleaIsAnswered() async throws {
        let (session, link, petition) = try session(voice: Patient())
        let key = GameSession.Spoken.petition(petition.id)
        XCTAssertEqual(session.voicing?.key, key, "The model asked for the petitioner's words as the plea comes")
        XCTAssertTrue(session.stillVoiced(key))
        var answered = session.state
        let events = try answered.perform(.answerPetition(petition.id, grant: false), as: session.player)
        let turnedAway = Date()
        link.onEvent?(.settled(answered, events))
        XCTAssertFalse(session.stillVoiced(key), "Its plea gone from the gate")
        XCTAssertTrue(session.stillVoiced(.chronicle(0)), "What the chronicle tells stays")
        let deadline = Date().addingTimeInterval(5)
        while session.voicing?.key == key, Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertNotEqual(session.voicing?.key, key, "The asking stopped once the plea was answered")
        XCTAssertLessThan(Date().timeIntervalSince(turnedAway), 2, "At once, not when the model would have answered")
        XCTAssertNil(session.spoken[key])
        XCTAssertNil(session.unvoiced[key], "A plea answered gives no reason the model was silent")

        // A voice that answers all the same once stopped: nothing of it kept.
        let (other, otherLink, plea) = try self.session(voice: Stubborn())
        let asked = GameSession.Spoken.petition(plea.id)
        XCTAssertEqual(other.voicing?.key, asked)
        var gone = other.state
        let granted = try gone.perform(.answerPetition(plea.id, grant: true), as: other.player)
        otherLink.onEvent?(.settled(gone, granted))
        let later = Date().addingTimeInterval(5)
        while other.voicing?.key == asked, Date() < later { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertNotEqual(other.voicing?.key, asked)
        XCTAssertNil(other.spoken[asked], "Words for a plea no longer at the gate are not kept")
    }

    /// The petitioner's own words, once this Mac's model has given them,
    /// stand on the card in their own quotation marks above the plea in the
    /// realm's words, and the answers are still there beneath them.
    func testThePetitionersOwnWordsStandOnTheCardOnceGiven() async throws {
        let (session, link, petition) = try session(voice: Ready())
        let key = GameSession.Spoken.petition(petition.id)
        let deadline = Date().addingTimeInterval(5)
        while session.spoken[key] == nil, Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(session.spoken[key], Ready.words, "Kept under the petitioner's own key")
        XCTAssertNil(session.unvoiced[key], "Words given, so no reason the model was silent")
        Portraits.shared.prepareNow()
        try CardShot.keep(PetitionCard(session: session).padding(30), as: "game-petition-spoken.png")
        PressableButtons.forget("Turn away")
        draw(PetitionCard(session: session))
        XCTAssertTrue(PressableButtons.press("Turn away"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .answerPetition(petition.id, grant: false))
    }
}

/// Gives the petitioner words at once.
private struct Ready: Voice {
    static let words = "The ward is down to its last course, keeper. Let our masons mend it."
    func speak(_ moment: VoiceMoment) async -> String? { Ready.words }
}

/// Gives the petitioner words only after a long while, and none once stopped.
private struct Patient: Voice {
    func speak(_ moment: VoiceMoment) async -> String? {
        try? await Task.sleep(for: .seconds(8))
        return Task.isCancelled ? nil : "We would mend it, keeper, if you let us."
    }
}

/// Gives the petitioner words a moment on, stopped or not.
private struct Stubborn: Voice {
    func speak(_ moment: VoiceMoment) async -> String? {
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { done.resume() }
        }
        return "We would mend it, keeper."
    }
}

/// A realm that keeps what it is sent.
private final class PleaLink: RealmLink {
    var onEvent: ((RealmEvent) -> Void)?
    private(set) var sent: [Command] = []
    func connect() {}
    func arrive(name: String?) {}
    func send(_ command: Command) { sent.append(command) }
    func setReady(_ ready: Bool) {}
    func leave() {}
}

extension PetitionCardTests {
    /// What came of the hold's last plea stands on the card, as its folk
    /// remember it and the realm keeps it in the keeper's own view.
    func testWhatCameOfTheHoldsLastPleaStandsOnTheCard() throws {
        var state = GameState(settings: GameSettings(seedText: "a plea at the gate", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        state.watch = Petition.from
        let seat = try XCTUnwrap(state.holdIndex(try XCTUnwrap(state.holds(of: me).first { $0.isSeat }).id))
        state.holds[seat].ward = 1
        state.houses[me].stock = Stock(grain: 500, timber: 500, stone: 500, moonsalt: 50)
        _ = state.bringPetitions()
        let first = try XCTUnwrap(state.petition(of: me))
        _ = try state.perform(.answerPetition(first.id, grant: false), as: me)
        state.watch += Petition.every
        _ = state.bringPetitions()
        let next = try XCTUnwrap(state.petition(of: me))
        let remembered = try XCTUnwrap(state.rememberedPlea(next))
        XCTAssertTrue(remembered.hasSuffix("asked to have its ward mended, and you turned them away."), remembered)
        let session = GameSession(link: PleaLink(), house: me, world: state.view(for: me),
                                  store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)))
        session.dismissSeatBriefing()
        XCTAssertEqual(session.state.rememberedPlea(next), remembered, "Told in the keeper's own view")
        draw(PetitionCard(session: session))
    }
}
