import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit
import NullmereRealm
import NullmereTestSupport

/// Trade as keepers see it: with a steward, answered by the realm; with
/// another keeper, by envoy; and the terms shown plainly.
@MainActor
final class TradeClientTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func enter(_ realm: LocalRealm, as identity: String, name: String) throws -> GameSession {
        let link = realm.link(identity: identity)
        var arrived: (Keeper, GameState)?
        link.onEvent = { event in
            if case .arrived(let keeper, let world) = event { arrived = (keeper, world) }
        }
        link.arrive(name: name)
        let (keeper, world) = try XCTUnwrap(arrived)
        return GameSession(link: link, house: try XCTUnwrap(keeper.house), world: world,
                           store: LocalStore(directory: dir.appendingPathComponent(identity)), host: realm)
    }

    private func realm() -> LocalRealm {
        LocalRealm(state: RealmState(name: "The Nullmere", seed: "traders", seats: 4, radius: 18, watchLength: 120, now: 0),
                   clock: { 0 })
    }

    func testAStewardsAnswerIsTheRealmsNotTheKeepersGuess() throws {
        let realm = realm()
        let ama = try enter(realm, as: "a", name: "Ama")
        let steward = try XCTUnwrap(ama.state.houses.first { !$0.isPlayer && !$0.isEliminated })
        XCTAssertEqual(ama.state.houses[steward.id].stock, .zero, "Its stores are hidden from Ama")
        XCTAssertTrue(GameSession.decidedByRealm(.offerTrade(Trade(give: .timber, 1, for: .stone, 1), to: steward.id, words: nil), in: ama.state))
        XCTAssertTrue(GameSession.decidedByRealm(.propose(.pact, to: steward.id), in: ama.state))
        XCTAssertFalse(GameSession.decidedByRealm(.gift(to: steward.id, resource: .grain, amount: 1), in: ama.state))

        let stone = ama.state.houses[ama.player].stock.stone
        let generous = Trade(give: .timber, 15, for: .stone, 10)
        ama.offerTrade(generous, to: steward, words: "")
        let told = ama.notices.map(\.text).filter { $0.contains("trade") }
        XCTAssertEqual(told, ["\(steward.title) takes your trade: 15 timber for 10 stone."], "Told once, as the realm decided")
        XCTAssertEqual(ama.state.houses[ama.player].stock.stone, stone + 10)

        let greedy = Trade(give: .timber, 1, for: .stone, 20)
        ama.offerTrade(greedy, to: steward, words: "")
        XCTAssertEqual(ama.notices.last?.text, "\(steward.title) won't trade 20 stone for 1 timber.")
        XCTAssertEqual(ama.notices.filter { $0.text.contains("won't trade") }.count, 1)
    }

    func testKeepersTradeByEnvoy() throws {
        let realm = realm()
        let ama = try enter(realm, as: "a", name: "Ama")
        let bel = try enter(realm, as: "b", name: "Bel")
        let belHouse = bel.state.houses[bel.player]
        let trade = Trade(give: .grain, 20, for: .timber, 15)
        ama.offerTrade(trade, to: ama.state.houses[bel.player], words: "For the winter.")
        XCTAssertTrue(ama.notices.contains { $0.text == "Your envoy takes \(belHouse.title) an offer: 20 grain for 15 timber." }, "\(ama.notices.map(\.text))")
        let envoy = try XCTUnwrap(bel.envoys.first)
        XCTAssertEqual(envoy.trade, trade)
        XCTAssertEqual(bel.words(of: envoy), "For the winter.")
        let card = EnvoyCards.words(for: envoy, from: bel.state.houses[ama.player], in: bel.state, player: bel.player)
        XCTAssertEqual(card, "House Ama offers 20 grain for 15 timber of yours. Generous: more given than asked, by barter worth.")
        try draw(EnvoyCards(session: bel))

        let grain = bel.state.houses[bel.player].stock.grain
        XCTAssertTrue(bel.perform(.answer(envoy: envoy.id, accept: true)))
        XCTAssertEqual(bel.state.houses[bel.player].stock.grain, grain + 20)
        XCTAssertTrue(bel.notices.contains { $0.text == "You trade 15 timber to House Ama for 20 grain." }, "\(bel.notices.map(\.text))")
        XCTAssertEqual(bel.notices.filter { $0.text.hasPrefix("You trade") }.count, 1, "Told once")
        XCTAssertTrue(ama.notices.contains { $0.text == "\(belHouse.title) takes your trade: 20 grain for 15 timber." }, "\(ama.notices.map(\.text))")
    }

    func testTheComposerSaysWhatTheTermsAre() throws {
        let stock = Stock(grain: 60, timber: 50, stone: 40, moonsalt: 5)
        XCTAssertEqual(TradeComposer.problem(with: Trade(give: .grain, 5, for: .grain, 5), stock: stock), "Choose two different stores.")
        XCTAssertEqual(TradeComposer.problem(with: Trade(give: .moonsalt, 6, for: .grain, 5), stock: stock), "You have only 5 moonsalt.")
        XCTAssertNil(TradeComposer.problem(with: Trade(give: .moonsalt, 5, for: .grain, 15), stock: stock))
        XCTAssertEqual(TradeComposer.line(for: Trade(give: .moonsalt, 5, for: .grain, 15), stock: stock, keeper: true),
                       "Even terms, by barter worth. Their keeper answers by envoy.")
        XCTAssertEqual(TradeComposer.note(asking: 150), "More asked than given, by barter worth.")
        XCTAssertEqual(TradeComposer.note(asking: 50), "Generous: more given than asked, by barter worth.")
        let house = House(id: 1, name: "Dravic", sigil: 1, isPlayer: false, temperament: .cunning, tileCount: 1)
        let composer = TradeComposer(house: house, stock: stock) { _ in }
        XCTAssertEqual(composer.trade.give, .grain, "It starts from the store there is most of")
        try draw(composer)
    }

    private func draw(_ view: some View) throws {
        let renderer = ImageRenderer(content: view.frame(width: 320).background(Color.black))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        XCTAssertGreaterThanOrEqual(litPixels(image), 20, "Drawn, not blank")
    }
}
