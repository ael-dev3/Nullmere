import Foundation
import XCTest
@testable import NullmereCore

final class GiftTests: XCTestCase {
    private func world() -> GameState {
        GameState(settings: GameSettings(seedText: "gifts", houseCount: 4, radius: 18, keepers: 1))
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
        // Their stores full: the refusal says it is their room, not yours.
        let room = state.storage(of: other)
        state.houses[other].stock.timber = room
        state.houses[me].stock.timber = 50
        XCTAssertThrowsError(try state.perform(.gift(to: other, resource: .timber, amount: 10), as: me)) {
            XCTAssertEqual($0 as? RuleError, .noRoomWithThem)
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

    /// What a House takes in from gifts in a watch is bounded, all givers
    /// together, so Houses one keeper holds under other names can't pour
    /// their stores into one; the next watch it may take as much again.
    func testAHouseTakesInOnlySoMuchInGiftsAWatch() throws {
        var state = world()
        let me = state.player
        let others = state.houses.filter { !$0.isPlayer }.map(\.id)
        let (receiver, second) = (others[0], others[1])
        // Another House held by a keeper, both sending to a third.
        state.houses[second].isPlayer = true
        for giver in [me, second] { state.houses[giver].stock = Stock(grain: 300, timber: 300, stone: 300, moonsalt: 50) }
        XCTAssertEqual(GameState.giftsTakenPerWatch, 100)
        _ = try state.perform(.gift(to: receiver, resource: .grain, amount: 50), as: me)
        _ = try state.perform(.gift(to: receiver, resource: .moonsalt, amount: 5), as: second)
        XCTAssertThrowsError(try state.perform(.gift(to: receiver, resource: .timber, amount: 31), as: second)) { error in
            XCTAssertEqual(error as? RuleError, .giftsThisWatch(left: 30), "Moonsalt counts four")
        }
        _ = try state.perform(.gift(to: receiver, resource: .timber, amount: 30), as: second)
        XCTAssertThrowsError(try state.perform(.gift(to: receiver, resource: .stone, amount: 1), as: me)) { error in
            XCTAssertEqual(error as? RuleError, .giftsThisWatch(left: 0))
        }
        XCTAssertNoThrow(try state.perform(.gift(to: second, resource: .stone, amount: 10), as: me), "Another House takes its own")
        _ = state.endWatch()
        XCTAssertNoThrow(try state.perform(.gift(to: receiver, resource: .stone, amount: 50), as: me), "A new watch, a new bound")
        XCTAssertEqual(RuleError.giftsThisWatch(left: 0).description, "They can take no more gifts this watch.")
        XCTAssertEqual(RuleError.giftsThisWatch(left: 20).description, "They can take gifts worth only 20 more this watch; moonsalt counts four.")
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
