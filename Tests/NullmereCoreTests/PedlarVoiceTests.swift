import XCTest
@testable import NullmereCore

/// The Pedlar of the Still calling up from his skiff to the keeper's hold,
/// as a device's own model is asked to voice him: only what he truly
/// offers, at his prices, what he has sold, and when he goes.
final class PedlarVoiceTests: XCTestCase {
    private func lyingOff() -> (GameState, Pedlar) {
        var state = Scene.world("the pedlar's call", houses: 4)
        let house = state.player
        let hold = state.holds(of: house)[0]
        let pedlar = Pedlar(house: house, hold: hold.id, at: hold.position, came: state.watch,
                            wares: GameState.pedlarWares(for: house, at: state.watch, firstID: 9_000))
        state.pedlars = [pedlar]
        return (state, pedlar)
    }

    func testHeOffersWhatHeCarriesAtHisPricesAndSaysWhenHeGoes() throws {
        let (state, pedlar) = lyingOff()
        let moment = state.voiced(pedlar)
        XCTAssertEqual(moment.task, Voicing.pedlarTask)
        let hold = try XCTUnwrap(state.hold(pedlar.hold))
        XCTAssertEqual(moment.facts.first, "He lies on the water off \(hold.name), a hold of \(state.houses[pedlar.house].title).")
        XCTAssertEqual(pedlar.wares.count, 3)
        for ware in pedlar.wares {
            XCTAssertTrue(moment.facts.contains("He offers \(ware.goods.title) for \(ware.price)."), "\(ware.goods.title), at its price")
        }
        XCTAssertFalse(moment.facts.contains { $0.contains("sold") }, "nothing sold yet")
        XCTAssertEqual(moment.facts.last, "He poles away in 2 watches.")
        XCTAssertTrue(moment.prompt.hasPrefix(Voicing.pedlarTask))
        XCTAssertTrue(Voicing.pedlarTask.contains("keeping every ware and price as given"), "held to his wares and prices")
    }

    func testOnceAWareIsSoldHeSaysSoAndCallsAfresh() throws {
        var (state, pedlar) = lyingOff()
        let key = GameState.voiceKey(of: pedlar)
        let ware = pedlar.wares[0]
        state.houses[pedlar.house].stock.credit(ware.price)
        _ = try state.perform(.buyFromPedlar(ware: ware.id), as: pedlar.house)
        let after = try XCTUnwrap(state.pedlar(for: pedlar.house))
        XCTAssertNotEqual(GameState.voiceKey(of: after), key, "a fresh call once a ware is bought")
        let facts = state.voiced(after).facts
        XCTAssertFalse(facts.contains("He offers \(ware.goods.title) for \(ware.price)."), "no longer offered")
        XCTAssertTrue(facts.contains("He has sold \(ware.goods.title) already."))
        XCTAssertEqual(facts.filter { $0.hasPrefix("He offers") }.count, 2, "the other two still offered")
        // Every ware sold: nothing left to offer.
        for other in after.wares where !other.sold {
            state.houses[pedlar.house].stock.credit(other.price)
            _ = try state.perform(.buyFromPedlar(ware: other.id), as: pedlar.house)
        }
        let bare = try XCTUnwrap(state.pedlar(for: pedlar.house))
        let last = state.voiced(bare).facts
        XCTAssertTrue(last.contains("He has nothing left to sell."))
        XCTAssertFalse(last.contains { $0.hasPrefix("He offers") })
        XCTAssertEqual(GameState.voiceKey(of: bare), key + 3)
    }

    func testHeSaysWhenHePolesAway() {
        let (_, pedlar) = lyingOff()
        XCTAssertEqual(GameState.pedlarLeaves(pedlar, at: pedlar.came), "He poles away in 2 watches.")
        XCTAssertEqual(GameState.pedlarLeaves(pedlar, at: pedlar.came + 1), "He poles away as this watch ends.")
        XCTAssertEqual(GameState.pedlarLeaves(pedlar, at: pedlar.came + 5), "He poles away as this watch ends.", "never in no watches")
    }

    func testTheDevicesGiveHisCallWordsUnderOneKey() {
        let (state, pedlar) = lyingOff()
        let keyed = state.voicedMoments(for: pedlar.house).filter { $0.key.hasPrefix("pedlar-") }
        XCTAssertEqual(keyed.map(\.key), ["pedlar-\(GameState.voiceKey(of: pedlar))"])
        XCTAssertEqual(keyed.first?.moment, state.voiced(pedlar))
        let other = (pedlar.house + 1) % state.houses.count
        XCTAssertTrue(state.voicedMoments(for: other).filter { $0.key.hasPrefix("pedlar-") }.isEmpty, "another House hears no call of his")
    }

    func testEachComingIsACallOfItsOwn() {
        let (state, pedlar) = lyingOff()
        let next = Pedlar(house: pedlar.house, hold: pedlar.hold, at: pedlar.at, came: pedlar.came + Pedlar.round,
                          wares: GameState.pedlarWares(for: pedlar.house, at: pedlar.came + Pedlar.round, firstID: 9_100))
        XCTAssertNotEqual(GameState.voiceKey(of: next), GameState.voiceKey(of: pedlar))
        XCTAssertEqual(state.voiced(pedlar), state.voiced(pedlar), "the same call, the same facts")
    }
}
