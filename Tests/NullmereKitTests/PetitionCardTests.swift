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
    private func session(stock: Stock = Stock(grain: 500, timber: 500, stone: 500, moonsalt: 50)) throws -> (GameSession, PleaLink, Petition) {
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
                                  store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)))
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
        XCTAssertEqual(Petition.Plea.allCases.map { PetitionCard.variant(of: $0) }, [Folk.porter, Folk.elder, Folk.farmhand, Folk.waterCarrier])
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
        let state = GameState(settings: GameSettings(seedText: "no plea", houseCount: 4, radius: 18, keepers: 1))
        let quiet = GameSession(link: PleaLink(), house: state.player, world: state.view(for: state.player),
                                store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)))
        PressableButtons.forget("Turn away")
        draw(PetitionCard(session: quiet))
        XCTAssertFalse(PressableButtons.press("Turn away"))
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
