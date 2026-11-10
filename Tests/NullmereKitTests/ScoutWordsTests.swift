import AppKit
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The Lanterns' word on a hold of another House they scouted: once their
/// report is in and the keeper looks to the hold, this Mac's model is asked
/// for it, keyed by the scouting, from their report alone; the hold's card
/// shows it beneath the report's lines; scouted again, a fresh word; a hold
/// not scouted has none, nor the keeper's own.
@MainActor
final class ScoutWordsTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func wait(for key: GameSession.Spoken, in session: GameSession) async throws {
        let deadline = Date().addingTimeInterval(5)
        while session.spoken[key] == nil, session.unvoiced[key] == nil, Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
    }

    func testTheLanternsGiveTheirWordOnAHoldTheyScouted() async throws {
        var state = GameState(settings: GameSettings(seedText: "the lanterns' word", houseCount: 4, radius: 16, keepers: 1))
        let me = state.player
        let foe = try XCTUnwrap(state.holds.first { $0.isSeat && $0.owner != me })
        // The hold on ground the House has seen, as its Lanterns reached it.
        state.reveal(around: foe.position, range: 2, for: me)
        let session = GameSession(link: LanternsLink(), house: me, world: state.view(for: me),
                                  store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)), voice: Lanterns())
        session.dismissSeatBriefing()
        session.selection = .hold(foe.id)
        XCTAssertNil(session.scoutWord, "not scouted, no word")

        // Their report comes in as the keeper looks to the hold.
        let scouting = state.scouting(of: foe, by: me)
        session.fileReports([.holdScouted(scouting)])
        let report = try XCTUnwrap(session.state.report(of: scouting, id: 0, for: me))
        let key = try XCTUnwrap(session.scoutWord)
        XCTAssertEqual(key, .scout(try XCTUnwrap(report.scoutWordKey)))
        XCTAssertEqual(GameSession.Spoken(key: key.key), key)
        try await wait(for: key, in: session)
        XCTAssertEqual(session.spoken[key], Lanterns.words, "kept under the Lanterns' word")
        let moment = try XCTUnwrap(VoiceFacts.scout(report))
        XCTAssertEqual(moment.kind, .scout)
        XCTAssertEqual(moment.facts, try XCTUnwrap(report.scoutWord).facts)
        XCTAssertTrue(moment.prompt.hasPrefix(Voicing.scoutTask), moment.prompt)
        XCTAssertTrue(session.stillVoiced(key))
        // The hold's card shows it beneath the report, kept with CI's screenshots.
        try CardShot.keep(ForeignHoldPanel(session: session, hold: try XCTUnwrap(session.state.hold(foe.id)))
            .padding(16).frame(width: PanelWidth.record).panelBackground().padding(20),
                          as: "game-lanterns-word.png")

        // Scouted again at another watch: a fresh word, the last kept too,
        // for each scouting is heard once.
        let again = ScoutReport(hold: scouting.hold, owner: scouting.owner, by: me, watch: scouting.watch + 1, garrison: [],
                                ward: scouting.ward, maximumWard: scouting.maximumWard, project: scouting.project,
                                training: scouting.training, spoils: scouting.spoils, wounded: scouting.wounded)
        session.fileReports([.holdScouted(again)])
        let fresh = try XCTUnwrap(session.scoutWord)
        XCTAssertNotEqual(fresh, key, "scouted again, a fresh word")
        XCTAssertFalse(session.stillVoiced(key), "the hold's last report is the newer")
        try await wait(for: fresh, in: session)
        XCTAssertEqual(session.spoken[fresh], Lanterns.words)

        // The keeper's own hold: no Lanterns' word of it.
        let seat = try XCTUnwrap(session.state.seat(of: me))
        session.selection = .hold(seat.id)
        XCTAssertNil(session.scoutWord)
        XCTAssertFalse(session.stillVoiced(fresh), "turned from, asked no longer")
    }
}

/// Gives the Lanterns' word at once.
private struct Lanterns: Voice {
    static let words = "Keeper, few spears keep its gates, and its ward stands whole; taken, it would fill our carts."
    func speak(_ moment: VoiceMoment) async -> String? { Lanterns.words }
}

/// A realm that hears nothing it is sent.
private final class LanternsLink: RealmLink {
    var onEvent: ((RealmEvent) -> Void)?
    func connect() {}
    func arrive(name: String?) {}
    func send(_ command: Command) {}
    func setReady(_ ready: Bool) {}
    func leave() {}
}
