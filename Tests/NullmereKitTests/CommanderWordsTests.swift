import AppKit
import NullmereModels
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// A commander's word as the keeper turns to the company they lead: this
/// Mac's model is asked for it once the company is chosen, first of all,
/// under a key of the commander, the watch and what the company is about;
/// the company's card shows it; turned from, it is asked no longer; a new
/// order calls afresh and lets the last word go; a model that gives none is
/// said so.
@MainActor
final class CommanderWordsTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    /// A keeper's House with its first commander leading a spear at its seat.
    private func leading() throws -> (GameState, commander: Int, spear: Int) {
        var state = GameState(settings: GameSettings(seedText: "the commander's word", houseCount: 4, radius: 16, keepers: 1))
        let me = state.player
        let commander = try XCTUnwrap(state.commanders(of: me).first).id
        let seat = try XCTUnwrap(state.seat(of: me))
        let spear = try XCTUnwrap(state.units(of: me).first { $0.kind == .spear })
        if let there = state.unit(at: seat.position), let other = state.unitIndex(there.id) {
            state.units[other].position = spear.position
        }
        state.units[try XCTUnwrap(state.unitIndex(spear.id))].position = seat.position
        try state.perform(.assign(commander: commander, unit: spear.id), as: me)
        return (state, commander, spear.id)
    }

    private func session(_ state: GameState, link: WordLink, voice: any Voice) -> GameSession {
        let session = GameSession(link: link, house: state.player, world: state.view(for: state.player),
                                  store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)), voice: voice)
        session.dismissSeatBriefing()
        return session
    }

    private func wait(for key: GameSession.Spoken, in session: GameSession) async throws {
        let deadline = Date().addingTimeInterval(5)
        while session.spoken[key] == nil, session.unvoiced[key] == nil, Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
    }

    func testTheCommanderGivesTheirWordAsTheKeeperTurnsToTheirCompany() async throws {
        let (state, id, spear) = try leading()
        let me = state.player
        let link = WordLink()
        let session = session(state, link: link, voice: Marshal())
        XCTAssertNil(session.commanderWord, "no company chosen, no word")
        session.selection = .unit(spear)
        let counsel = try XCTUnwrap(CommanderCounsel(state: session.state, player: me, commander: id, reports: session.reports))
        let key = try XCTUnwrap(session.commanderWord)
        XCTAssertEqual(key, .commander(try XCTUnwrap(counsel.wordKey)))
        XCTAssertEqual(GameSession.Spoken(key: key.key), key)
        try await wait(for: key, in: session)
        XCTAssertEqual(session.spoken[key], Marshal.words, "kept under the commander's word")
        let moment = try XCTUnwrap(VoiceFacts.commander(counsel))
        XCTAssertEqual(moment.kind, .commander)
        XCTAssertEqual(moment.facts, try XCTUnwrap(counsel.word).facts)
        XCTAssertTrue(moment.prompt.hasPrefix(Voicing.commanderTask), moment.prompt)
        // The company's card shows it, kept with CI's screenshots.
        let unit = try XCTUnwrap(session.selectedUnit)
        try CardShot.keep(UnitPanel(session: session, unit: unit)
            .padding(16).frame(width: PanelWidth.record).panelBackground().padding(20),
                          as: "game-commander-word.png")

        // A march ordered: the realm's word comes, and the commander gives a
        // fresh word, letting the last go.
        var marching = state
        let index = try XCTUnwrap(marching.unitIndex(spear))
        let start = marching.units[index].position
        let far = try XCTUnwrap(marching.map.hexes.first { $0.distance(to: start) == 3 && marching.map[$0]?.terrain.isPassable == true })
        marching.units[index].destination = far
        link.onEvent?(.settled(marching.view(for: me), []))
        let fresh = try XCTUnwrap(session.commanderWord)
        XCTAssertNotEqual(fresh, key, "a new order, a fresh word")
        XCTAssertFalse(session.stillVoiced(key), "the last word is the commander's no longer")
        XCTAssertTrue(session.stillVoiced(fresh))
        try await wait(for: fresh, in: session)
        XCTAssertEqual(session.spoken[fresh], Marshal.words)
        XCTAssertNil(session.spoken[key], "one word of each commander kept, not one of every order")
    }

    func testTurnedFromTheCompanyItIsAskedNoLonger() async throws {
        let (state, _, spear) = try leading()
        let me = state.player
        let unled = try XCTUnwrap(state.units(of: me).first { $0.id != spear && $0.leader == nil }).id
        let session = session(state, link: WordLink(), voice: Slow())
        session.selection = .unit(spear)
        let key = try XCTUnwrap(session.commanderWord)
        let deadline = Date().addingTimeInterval(5)
        while session.voicing?.key != key, Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(session.voicing?.key, key, "asked first, at once")
        // Turned to a company no commander leads: no word, and the asking stops.
        session.selection = .unit(unled)
        XCTAssertNil(session.commanderWord)
        XCTAssertFalse(session.stillVoiced(key))
        let stopped = Date().addingTimeInterval(5)
        while session.voicing?.key == key, Date() < stopped { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertNotEqual(session.voicing?.key, key, "its asking stopped")
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertNil(session.spoken[key], "nothing of it kept")
        // Turned to again: asked again, never left wordless.
        session.selection = .unit(spear)
        XCTAssertEqual(session.commanderWord, key)
        let again = Date().addingTimeInterval(5)
        while session.voicing?.key != key, Date() < again { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(session.voicing?.key, key, "asked again once turned to again")
    }

    func testAVoiceThatGivesNoWordsIsSaidSo() async throws {
        let (state, _, spear) = try leading()
        let session = session(state, link: WordLink(), voice: Mute())
        session.selection = .unit(spear)
        let key = try XCTUnwrap(session.commanderWord)
        try await wait(for: key, in: session)
        XCTAssertNil(session.spoken[key], "no words put in the commander's mouth")
        XCTAssertNotNil(session.unvoiced[key], "why none, said plainly")
    }
}

/// Gives the commander's word at once.
private struct Marshal: Voice {
    static let words = "The spears stand at the seat, keeper, whole and rested. Nothing stirs within two tiles of us."
    func speak(_ moment: VoiceMoment) async -> String? { Marshal.words }
}

/// Gives words only after a long while, so the asking may be stopped.
private struct Slow: Voice {
    func speak(_ moment: VoiceMoment) async -> String? {
        try? await Task.sleep(for: .seconds(4))
        return Task.isCancelled ? nil : "Too late to matter, keeper."
    }
}

/// Gives no words, and says nothing of why.
private struct Mute: Voice {
    func speak(_ moment: VoiceMoment) async -> String? { nil }
}

/// A realm that hears nothing it is sent.
private final class WordLink: RealmLink {
    var onEvent: ((RealmEvent) -> Void)?
    func connect() {}
    func arrive(name: String?) {}
    func send(_ command: Command) {}
    func setReady(_ ready: Bool) {}
    func leave() {}
}
