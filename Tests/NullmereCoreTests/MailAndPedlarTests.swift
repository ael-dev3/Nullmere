import XCTest
@testable import NullmereCore

/// Letters between two keepers, and the Pedlar of the Still.
final class MailAndPedlarTests: XCTestCase {
    private func keepers() -> (GameState, a: Int, b: Int, steward: Int) {
        var state = Scene.world("letters and pedlars", houses: 4)
        let a = state.player, b = (a + 1) % 4
        state.houses[b].isPlayer = true
        return (state, a, b, (a + 2) % 4)
    }

    func testALetterIsReadByItsWriterAndItsReaderAlone() throws {
        var (state, a, b, steward) = keepers()
        let third = (a + 3) % 4
        state.houses[third].isPlayer = true
        XCTAssertEqual(state.refusal(of: .writeLetter(to: steward, words: "Hail"), as: a), .notAKeeper, "A steward reads no letters")
        XCTAssertEqual(state.refusal(of: .writeLetter(to: a, words: "Hail"), as: a), .unknownHouse)
        XCTAssertEqual(state.refusal(of: .writeLetter(to: b, words: "   "), as: a), .nothingToSay)
        let events = try state.perform(.writeLetter(to: b, words: "Meet me at the ford"), as: a)
        guard case .letterSent(let letter) = try XCTUnwrap(events.first) else { return XCTFail("\(events)") }
        XCTAssertEqual(letter.from, a)
        XCTAssertEqual(letter.to, b)
        XCTAssertEqual(letter.text, "Meet me at the ford")
        XCTAssertEqual(state.view(for: a).lettersSent, [letter], "Its writer keeps it")
        XCTAssertEqual(state.view(for: b).lettersSent, [letter], "Its reader has it")
        XCTAssertTrue(state.view(for: third).lettersSent.isEmpty, "No one else reads it")
        XCTAssertEqual(state.events(events, heardBy: third), [])
        XCTAssertEqual(state.events(events, heardBy: b), events)
        XCTAssertEqual(state.tidings(of: events[0], for: b)?.text, "A letter from \(state.houses[a].title): \u{201C}Meet me at the ford\u{201D}")
        XCTAssertNil(state.tidings(of: events[0], for: a))
        for _ in 1..<GameState.lettersPerWatch { _ = try state.perform(.writeLetter(to: b, words: "And again"), as: a) }
        XCTAssertEqual(state.refusal(of: .writeLetter(to: b, words: "Once more"), as: a), .saidEnough)
        XCTAssertEqual(state.problems(), [])
    }

    func testThePedlarComesOnHisRoundSellsEachWareOnceAndLeaves() throws {
        var (state, a, b, _) = keepers()
        guard state.holds(of: a).contains(where: { state.stoneWater(before: $0) != nil }) else { throw XCTSkip("No hold by the lake in this world") }
        state.watch = GameState.pedlarComes(to: a, from: state.watch + 1)
        let came = state.turnThePedlars()
        XCTAssertTrue(came.contains { if case .pedlarCame(a, _) = $0 { return true } else { return false } })
        let pedlar = try XCTUnwrap(state.pedlar(for: a))
        XCTAssertEqual(pedlar.wares.count, 3)
        XCTAssertEqual(state.map[pedlar.at]?.terrain.isWater, true, "His skiff lies on the water")
        XCTAssertNil(state.view(for: b).pedlar(for: a), "Another keeper knows nothing of him")
        XCTAssertNotNil(state.view(for: a).pedlar(for: a))
        XCTAssertNotNil(state.tidings(of: came.first { if case .pedlarCame = $0 { return true } else { return false } }!, for: a))

        // Each ware once, for its price.
        let sculptures = try XCTUnwrap(pedlar.wares.first { if case .sculptures = $0.goods { return true } else { return false } })
        state.houses[a].stock.credit(sculptures.price)
        let stock = state.houses[a].stock
        let bought = try state.perform(.buyFromPedlar(ware: sculptures.id), as: a)
        XCTAssertEqual(bought.first, .pedlarSold(house: a, ware: sculptures.id))
        guard case .sculptures(let count) = sculptures.goods else { return XCTFail() }
        XCTAssertEqual(state.sculptures(of: a), count)
        var paid = stock
        paid.debit(sculptures.price)
        XCTAssertEqual(state.houses[a].stock, paid)
        XCTAssertEqual(state.refusal(of: .buyFromPedlar(ware: sculptures.id), as: a), .wareSold)
        XCTAssertEqual(state.refusal(of: .buyFromPedlar(ware: sculptures.id), as: b), .noPedlar, "Not another House's to buy")
        // Short of its price, refused.
        let stores = try XCTUnwrap(pedlar.wares.first { if case .stores = $0.goods { return true } else { return false } })
        state.houses[a].stock = .zero
        XCTAssertEqual(state.refusal(of: .buyFromPedlar(ware: stores.id), as: a), .shortOf(stores.price))
        // His stay done, he goes.
        state.watch += Pedlar.stays
        XCTAssertTrue(state.turnThePedlars().contains(.pedlarLeft(house: a)))
        XCTAssertNil(state.pedlar(for: a))
        XCTAssertEqual(state.problems(), [])
    }

    func testThePedlarsWaresAreTheSameForTheSameHouseAndWatch() {
        XCTAssertEqual(GameState.pedlarWares(for: 2, at: 40, firstID: 9), GameState.pedlarWares(for: 2, at: 40, firstID: 9))
        XCTAssertEqual(GameState.pedlarComes(to: 1, from: 0) % Pedlar.round, (Pedlar.round - 3 % Pedlar.round) % Pedlar.round)
    }
}
