import AppKit
import NullmereModels
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The words cut on the stone of a barrow the keeper's House raises over a
/// field's dead: once the realm tells the Mac of the burial, this Mac's model
/// is asked for them under the barrow's own key, from who raised it, over how
/// many, whose dead they are and where they fell; the tile panel shows them
/// under what the barrow is; a barrow raised before the keeper came back is
/// not given words again, and another House's barrow none.
@MainActor
final class GraveWordsTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func opened(_ world: GameState, house: Int, link: GraveLink) -> GameSession {
        let session = GameSession(link: link, house: house, world: world.view(for: house),
                                  store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)), voice: Stone())
        session.dismissSeatBriefing()
        return session
    }

    func testABarrowTheHouseRaisesIsGivenTheWordsOnItsStone() async throws {
        var state = GameState(settings: GameSettings(seedText: "the stone's words", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let company = try XCTUnwrap(state.units(of: me).first { $0.kind.isMilitary })
        state.layTheFallen(7_000, of: me, at: company.position)
        let link = GraveLink()
        let session = opened(state, house: me, link: link)
        XCTAssertNil(session.state.grave(at: company.position), "none raised yet")
        // Buried: the realm's word comes, and the stone's words are asked.
        var buried = state
        let events = try buried.perform(.bury(unit: company.id), as: me)
        link.onEvent?(.settled(buried.view(for: me), events))
        let grave = try XCTUnwrap(session.state.grave(at: company.position))
        XCTAssertEqual(grave.dead, [me])
        let key = GameSession.Spoken.grave(grave.key)
        XCTAssertEqual(key.key, "grave-\(grave.key)")
        XCTAssertEqual(GameSession.Spoken(key: "grave-\(grave.key)"), key)
        let deadline = Date().addingTimeInterval(5)
        while session.spoken[key] == nil, Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(session.spoken[key], Stone.words, "kept under the barrow's own key")
        XCTAssertNil(session.unvoiced[key])
        let moment = try XCTUnwrap(VoiceFacts.grave(grave, by: me, in: session.state))
        XCTAssertEqual(moment.kind, .grave)
        XCTAssertTrue(moment.prompt.hasPrefix(Voicing.graveTask), moment.prompt)
        XCTAssertEqual(moment.facts, session.state.voiced(grave, for: me)?.facts)
        // Another House's barrow: nothing for its stone.
        let other = try XCTUnwrap(buried.livingHouses.first { $0.id != me }).id
        XCTAssertNil(VoiceFacts.grave(grave, by: other, in: buried))
        // As a window draws it, kept with CI's screenshots.
        try CardShot.keep(TilePanel(session: session, hex: company.position)
            .padding(16).frame(width: PanelWidth.record).panelBackground().padding(20),
                          as: "game-barrow-words.png")

        // Picked up again with the barrow raised: not given words again.
        let again = opened(buried, house: me, link: GraveLink())
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNil(again.spoken[key], "raised before the keeper came back: not worded again")
        XCTAssertNotEqual(again.voicing?.key, key)
    }
}

/// Gives the stone's words at once.
private struct Stone: Voice {
    static let words = "Here the House laid its dead where they fell, and raised this mound over them."
    func speak(_ moment: VoiceMoment) async -> String? { Stone.words }
}

/// A realm that hears nothing it is sent.
private final class GraveLink: RealmLink {
    var onEvent: ((RealmEvent) -> Void)?
    func connect() {}
    func arrive(name: String?) {}
    func send(_ command: Command) {}
    func setReady(_ ready: Bool) {}
    func leave() {}
}
