import AppKit
import NullmereModels
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The Pedlar of the Still calling up from his skiff to the keeper's hold:
/// this Mac's model is asked for his call under its own key, from the wares
/// he truly carries, their prices and when he poles away; his card shows it
/// over his wares; once a ware is bought he calls afresh, and the words of
/// a call no longer his are not kept.
@MainActor
final class PedlarWordsTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func lyingOff() throws -> (GameState, Pedlar) {
        var state = GameState(settings: GameSettings(seedText: "the pedlar calls", houseCount: 4, radius: 16, keepers: 1))
        let me = state.player
        let hold = try XCTUnwrap(state.holds(of: me).first)
        let pedlar = Pedlar(house: me, hold: hold.id, at: hold.position, came: state.watch,
                            wares: GameState.pedlarWares(for: me, at: state.watch, firstID: 9_000))
        state.pedlars = [pedlar]
        return (state, pedlar)
    }

    private func wait(for key: GameSession.Spoken, in session: GameSession) async throws {
        let deadline = Date().addingTimeInterval(5)
        while session.spoken[key] == nil, Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
    }

    func testThePedlarsCallIsVoicedFromHisWaresAndCalledAfreshOnceOneIsBought() async throws {
        let (state, pedlar) = try lyingOff()
        let me = state.player
        let link = PedlarLink()
        let session = GameSession(link: link, house: me, world: state.view(for: me),
                                  store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)), voice: Hawker())
        session.dismissSeatBriefing()
        let key = GameSession.Spoken.pedlar(GameState.voiceKey(of: pedlar))
        XCTAssertEqual(key.key, "pedlar-\(GameState.voiceKey(of: pedlar))")
        XCTAssertEqual(GameSession.Spoken(key: key.key), key)
        try await wait(for: key, in: session)
        XCTAssertEqual(session.spoken[key], Hawker.words, "kept under his call's own key")
        let moment = VoiceFacts.pedlar(pedlar, in: session.state)
        XCTAssertEqual(moment.kind, .pedlar)
        XCTAssertTrue(moment.prompt.hasPrefix(Voicing.pedlarTask), moment.prompt)
        XCTAssertEqual(moment.facts, session.state.voiced(pedlar).facts)
        XCTAssertTrue(moment.facts.contains("He offers \(pedlar.wares[0].goods.title) for \(pedlar.wares[0].price)."))
        // His card shows his call over his wares, kept with CI's screenshots.
        let shown = try XCTUnwrap(session.state.pedlar(for: me))
        try CardShot.keep(PedlarCard(session: session, pedlar: shown)
            .padding(16).frame(width: PanelWidth.record).panelBackground().padding(20),
                          as: "game-pedlar-words.png")

        // A ware bought: the realm's word comes, and he calls afresh.
        var bought = state
        let ware = pedlar.wares[2]
        bought.houses[me].stock.credit(ware.price)
        let events = try bought.perform(.buyFromPedlar(ware: ware.id), as: me)
        link.onEvent?(.settled(bought.view(for: me), events))
        let after = try XCTUnwrap(session.state.pedlar(for: me))
        let fresh = GameSession.Spoken.pedlar(GameState.voiceKey(of: after))
        XCTAssertNotEqual(fresh, key)
        XCTAssertFalse(session.stillVoiced(key), "his first call is his no longer")
        XCTAssertTrue(session.stillVoiced(fresh))
        try await wait(for: fresh, in: session)
        XCTAssertEqual(session.spoken[fresh], Hawker.words, "called afresh, its words its own")
        XCTAssertTrue(VoiceFacts.pedlar(after, in: session.state).facts.contains("He has sold \(ware.goods.title) already."))
    }

    func testAVoiceThatGivesNoWordsIsSaidSoAndHisWaresStand() async throws {
        let (state, pedlar) = try lyingOff()
        let me = state.player
        let session = GameSession(link: PedlarLink(), house: me, world: state.view(for: me),
                                  store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)), voice: Silent())
        session.dismissSeatBriefing()
        let key = GameSession.Spoken.pedlar(GameState.voiceKey(of: pedlar))
        let deadline = Date().addingTimeInterval(5)
        while session.unvoiced[key] == nil, Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertNil(session.spoken[key], "no words put in his mouth")
        XCTAssertNotNil(session.unvoiced[key], "why none, said plainly")
        // His wares stand to be bought, words or none.
        let shown = try XCTUnwrap(session.state.pedlar(for: me))
        XCTAssertEqual(shown.wares.filter { !$0.sold }.count, 3)
    }
}

/// Gives the pedlar's call at once.
private struct Hawker: Voice {
    static let words = "Timber for grain, keeper, and draughts that mend. Two watches I lie here, then the water takes me."
    func speak(_ moment: VoiceMoment) async -> String? { Hawker.words }
}

/// Gives no words, and says nothing of why.
private struct Silent: Voice {
    func speak(_ moment: VoiceMoment) async -> String? { nil }
}

/// A realm that hears nothing it is sent.
private final class PedlarLink: RealmLink {
    var onEvent: ((RealmEvent) -> Void)?
    func connect() {}
    func arrive(name: String?) {}
    func send(_ command: Command) {}
    func setReady(_ ready: Bool) {}
    func leave() {}
}
