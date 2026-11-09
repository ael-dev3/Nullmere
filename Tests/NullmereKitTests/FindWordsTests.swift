import AppKit
import NullmereModels
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// A hamlet's folk and a barrow's stones on the Mac: once the keeper's
/// Lanterns have sought one, this Mac's model is asked for the folk's own
/// words, or the words cut at the barrow's mouth, under the find's own key,
/// from what the realm's chronicle says came of it; the ground panel shows
/// what came of it and those words; a find sought before the keeper came
/// back is not told again.
@MainActor
final class FindWordsTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    /// A keeper's House whose Lanterns stand beside a hamlet or a barrow it
    /// knows of.
    private func world(_ kind: Find.Kind, seed: String) throws -> (GameState, lantern: NullmereCore.Unit, find: Find) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let lantern = try XCTUnwrap(state.units(of: me).first { $0.kind == .lantern })
        func open(_ hex: Hex) -> Bool {
            state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && state.unit(at: hex) == nil
        }
        let find = try XCTUnwrap(state.findsInLand.first { $0.kind == kind && $0.position.neighbors.contains(where: open) })
        let beside = try XCTUnwrap(find.position.neighbors.first(where: open))
        state.units[try XCTUnwrap(state.unitIndex(lantern.id))].position = beside
        state.refreshSight()
        return (state, try XCTUnwrap(state.unit(lantern.id)), find)
    }

    /// A session over `link`, or a realm that hears nothing; built here on
    /// the main actor, where a link is made, never as a default argument.
    private func opened(_ state: GameState, link: FolkLink? = nil, voice: (any Voice)? = Eldest()) -> GameSession {
        let session = GameSession(link: link ?? FolkLink(), house: state.player, world: state.view(for: state.player),
                                  store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)), voice: voice)
        session.dismissSeatBriefing()
        return session
    }

    private func draw(_ view: some View) {
        let renderer = ImageRenderer(content: view.frame(width: PanelWidth.record).background(Color.black))
        renderer.scale = 1
        XCTAssertNotNil(renderer.cgImage)
    }

    func testTheHamletsFolkAreAskedOnceSoughtAndTheirWordsStandOnTheGroundPanel() async throws {
        let (state, lantern, hamlet) = try world(.hamlet, seed: "found in the mist")
        let me = state.player
        let key = GameSession.Spoken.find(hamlet.id)
        XCTAssertEqual(key.key, "find-\(hamlet.id)")
        XCTAssertEqual(GameSession.Spoken(key: "find-\(hamlet.id)"), key)
        let link = FolkLink()
        let session = opened(state, link: link)
        // Not sought yet: nothing asked, and the panel says what seeking brings.
        XCTAssertNotEqual(session.voicing?.key, key)
        XCTAssertNil(VoiceFacts.find(hamlet, by: me, in: session.state))
        XCTAssertEqual(FindRow.said(hamlet, in: session.state, player: me), UnitPanel.seekHelp(hamlet))
        draw(TilePanel(session: session, hex: hamlet.position))
        // Sought: the realm's word comes, and the folk's words are asked.
        var sought = state
        let events = try sought.perform(.seek(unit: lantern.id, find: hamlet.id), as: me)
        link.onEvent?(.settled(sought.view(for: me), events))
        let deadline = Date().addingTimeInterval(5)
        while session.spoken[key] == nil, Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(session.spoken[key], Eldest.words, "Kept under the find's own key")
        XCTAssertNil(session.unvoiced[key])
        let moment = try XCTUnwrap(VoiceFacts.find(hamlet, by: me, in: session.state))
        XCTAssertEqual(moment.kind, .find(.hamlet))
        XCTAssertEqual(moment.facts, session.state.voiced(hamlet, by: me)?.facts)
        XCTAssertTrue(moment.prompt.hasPrefix(Voicing.hamletTask), moment.prompt)
        let entry = try XCTUnwrap(session.state.discovery(of: hamlet, by: me))
        XCTAssertEqual(FindRow.said(hamlet, in: session.state, player: me), entry.text)
        XCTAssertEqual(FindRow.who(hamlet), "the hamlet's eldest")
        XCTAssertEqual(Portrait.key(of: hamlet), .folk(variant: Folk.elder), "The eldest's face beside the hamlet's name")
        // Another House never sought it: nothing to voice for it.
        let other = try XCTUnwrap(sought.livingHouses.first { $0.id != me }).id
        XCTAssertNil(VoiceFacts.find(hamlet, by: other, in: sought))
        // As a window draws it, kept with CI's screenshots.
        try CardShot.keep(TilePanel(session: session, hex: hamlet.position)
            .padding(16).frame(width: PanelWidth.record).panelBackground().padding(20),
                          as: "game-hamlet-words.png")
    }

    /// A barrow's words are asked as the stones' own, and a hamlet or barrow
    /// the House had sought before this session began is not told again.
    func testABarrowsStonesAreVoicedAndWhatWasSoughtBeforeIsNotRetold() async throws {
        let (state, lantern, barrow) = try world(.barrow, seed: "the old graves")
        let me = state.player
        var sought = state
        _ = try sought.perform(.seek(unit: lantern.id, find: barrow.id), as: me)
        let moment = try XCTUnwrap(VoiceFacts.find(barrow, by: me, in: sought))
        XCTAssertEqual(moment.kind, .find(.barrow))
        XCTAssertTrue(moment.prompt.hasPrefix(Voicing.barrowTask), moment.prompt)
        XCTAssertEqual(FindRow.who(barrow), "the barrow's stones")
        XCTAssertEqual(Portrait.key(of: barrow), .furnishing(.barrowMound), "The barrow's mound beside its name")
        // Picked up again with the barrow already sought: counted as told.
        let session = opened(sought)
        let key = GameSession.Spoken.find(barrow.id)
        XCTAssertNotEqual(session.voicing?.key, key)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNil(session.spoken[key], "Sought before the keeper came back: not told again")
        XCTAssertNotEqual(session.voicing?.key, key)
        XCTAssertTrue(FindRow.said(barrow, in: session.state, player: me).hasPrefix("\(sought.houses[me].title)'s Lanterns go down into"))
        draw(TilePanel(session: session, hex: barrow.position))
    }
}

/// Gives the folk words at once.
private struct Eldest: Voice {
    static let words = "Be welcome, Lanterns of the keeper. Take what our ground could spare, and go carefully."
    func speak(_ moment: VoiceMoment) async -> String? { Eldest.words }
}

/// A realm that hears nothing it is sent.
private final class FolkLink: RealmLink {
    var onEvent: ((RealmEvent) -> Void)?
    func connect() {}
    func arrive(name: String?) {}
    func send(_ command: Command) {}
    func setReady(_ ready: Bool) {}
    func leave() {}
}
