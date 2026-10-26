import Foundation
import XCTest
@testable import NullmereCore

final class GiftTests: XCTestCase {
    private func world() -> GameState {
        GameState(settings: GameSettings(seedText: "gifts", houseCount: 4, radius: 18))
    }

    func testAGiftMovesStoresBetweenHousesAtPeace() throws {
        var state = world()
        let me = state.player, other = (me + 1) % state.houses.count
        let mine = state.houses[me].stock.grain, theirs = state.houses[other].stock.grain
        let events = try state.perform(.gift(to: other, resource: .grain, amount: 25), as: me)
        XCTAssertEqual(events, [.gifted(from: me, to: other, gift: Stock(grain: 25))])
        XCTAssertEqual(state.houses[me].stock.grain, mine - 25)
        XCTAssertEqual(state.houses[other].stock.grain, theirs + 25)
        XCTAssertEqual(state.goodwill(from: me, to: other), 25)
        XCTAssertEqual(state.goodwill(from: other, to: me), 0, "Goodwill runs one way")
        XCTAssertFalse(state.chronicle.contains { $0.kind == .gift }, "A small gift goes unrecorded")

        _ = try state.perform(.gift(to: other, resource: .moonsalt, amount: 5), as: me)
        XCTAssertEqual(state.goodwill(from: me, to: other), 45, "Moonsalt weighs four times")

        XCTAssertThrowsError(try state.perform(.gift(to: me, resource: .grain, amount: 1), as: me)) { XCTAssertEqual($0 as? RuleError, .unknownHouse) }
        XCTAssertThrowsError(try state.perform(.gift(to: other, resource: .grain, amount: 0), as: me)) { XCTAssertEqual($0 as? RuleError, .invalidAmount) }
        XCTAssertThrowsError(try state.perform(.gift(to: other, resource: .stone, amount: 9_000), as: me)) {
            guard case .shortOf = $0 as? RuleError else { return XCTFail("\($0)") }
        }
        _ = try state.perform(.declareWar(on: other), as: me)
        XCTAssertThrowsError(try state.perform(.gift(to: other, resource: .grain, amount: 5), as: me)) { XCTAssertEqual($0 as? RuleError, .atWarWith(other)) }
    }

    func testAGenerousGiftIsRecordedAndForgottenInTime() throws {
        var state = world()
        let me = state.player, other = (me + 1) % state.houses.count
        _ = try state.perform(.gift(to: other, resource: .grain, amount: 40), as: me)
        XCTAssertTrue(state.chronicle.last?.text.contains("sends") ?? false)
        XCTAssertEqual(state.chronicle.last?.kind, .gift)
        // The gift is heard by giver and receiver alone.
        let third = (me + 2) % state.houses.count
        let event = GameEvent.gifted(from: me, to: other, gift: Stock(grain: 40))
        XCTAssertEqual(state.events([event], heardBy: other), [event])
        XCTAssertEqual(state.events([event], heardBy: third), [])
        for _ in 0..<GameState.giftMemory { _ = state.endWatch() }
        XCTAssertEqual(state.goodwill(from: me, to: other), 0, "Twenty watches on, it is forgotten")
        XCTAssertEqual(state.problems(), [])
    }

    func testGoodwillWinsAPactAStewardWouldRefuse() throws {
        var state = world()
        let me = state.player
        // A steward that wouldn't take a pact this early in the age.
        guard let wary = state.houses.first(where: { !$0.isPlayer && ($0.temperament == .wary || $0.temperament == .steadfast) }) else {
            throw XCTSkip("No wary or steadfast steward in this world")
        }
        XCTAssertFalse(RivalMind(house: wary.id).accepts(.pact, from: me, in: state), "Too soon")
        _ = try state.perform(.gift(to: wary.id, resource: .grain, amount: 40), as: me)
        _ = try state.perform(.gift(to: wary.id, resource: .moonsalt, amount: 5), as: me)
        XCTAssertGreaterThanOrEqual(state.goodwill(from: me, to: wary.id), GameState.pactGoodwill)
        XCTAssertTrue(RivalMind(house: wary.id).accepts(.pact, from: me, in: state), "Goodwill wins the pact")
    }
}
