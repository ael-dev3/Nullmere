import AppKit
import NullmereModels
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The reeve's word as the keeper turns to a hold of theirs: this Mac's
/// model is asked for it once the hold is chosen, first of all, under a key
/// of the hold, the watch and how it stands; the hold's card shows it; work
/// begun calls afresh and lets the last word go; another House's hold has
/// no reeve to speak to the keeper.
@MainActor
final class ReeveWordsTests: XCTestCase {
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

    func testTheReeveGivesTheirWordAsTheKeeperTurnsToTheHold() async throws {
        var state = GameState(settings: GameSettings(seedText: "the reeve's word", houseCount: 4, radius: 16, keepers: 1))
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        if let index = state.holdIndex(seat.id) { state.holds[index].project = nil }
        let link = ReeveLink()
        let session = GameSession(link: link, house: me, world: state.view(for: me),
                                  store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)), voice: Reeve())
        session.dismissSeatBriefing()
        XCTAssertNil(session.reeveWord, "no hold chosen, no word")
        session.selection = .hold(seat.id)
        let key = try XCTUnwrap(session.reeveWord)
        XCTAssertEqual(key, .reeve(try XCTUnwrap(session.state.reeveWordKey(of: seat.id, for: me))))
        XCTAssertEqual(GameSession.Spoken(key: key.key), key)
        try await wait(for: key, in: session)
        XCTAssertEqual(session.spoken[key], Reeve.words, "kept under the reeve's word")
        let moment = try XCTUnwrap(VoiceFacts.reeve(of: seat.id, for: me, in: session.state))
        XCTAssertEqual(moment.kind, .reeve)
        XCTAssertEqual(moment.facts, try XCTUnwrap(session.state.reeveWord(of: seat.id, for: me)).facts)
        XCTAssertTrue(moment.prompt.hasPrefix(Voicing.reeveTask), moment.prompt)
        // The hold's card shows it, kept with CI's screenshots.
        let shown = try XCTUnwrap(session.selectedHold)
        try CardShot.keep(OwnHoldDetails(session: session, hold: shown)
            .padding(16).frame(width: PanelWidth.record).panelBackground().padding(20),
                          as: "game-reeve-word.png")

        // Work begun: the realm's word comes, and the reeve gives a fresh
        // word, letting the last go.
        var raising = state
        raising.houses[me].stock = Stock(grain: 900, timber: 900, stone: 900, moonsalt: 90)
        try raising.perform(.build(hold: seat.id, kind: .granary), as: me)
        link.onEvent?(.settled(raising.view(for: me), []))
        let fresh = try XCTUnwrap(session.reeveWord)
        XCTAssertNotEqual(fresh, key, "work begun, a fresh word")
        XCTAssertFalse(session.stillVoiced(key), "the last word is the reeve's no longer")
        XCTAssertTrue(session.stillVoiced(fresh))
        try await wait(for: fresh, in: session)
        XCTAssertEqual(session.spoken[fresh], Reeve.words)
        XCTAssertNil(session.spoken[key], "one word of each hold's reeve kept, not one of every change")

        // Another House's hold: no reeve of theirs speaks to the keeper.
        if let other = session.state.holds.first(where: { $0.owner != me }) {
            session.selection = .hold(other.id)
            XCTAssertNil(session.reeveWord)
            XCTAssertFalse(session.stillVoiced(fresh), "turned from, asked no longer")
        }
    }
}

/// Gives the reeve's word at once.
private struct Reeve: Voice {
    static let words = "The granary rises, keeper, and our walls stand whole. Nothing stirs within two tiles of the gate."
    func speak(_ moment: VoiceMoment) async -> String? { Reeve.words }
}

/// A realm that hears nothing it is sent.
private final class ReeveLink: RealmLink {
    var onEvent: ((RealmEvent) -> Void)?
    func connect() {}
    func arrive(name: String?) {}
    func send(_ command: Command) {}
    func setReady(_ ready: Bool) {}
    func leave() {}
}
