import Foundation
import XCTest
@testable import NullmereCore

final class TradeTests: XCTestCase {
    private func world() -> GameState {
        GameState(settings: GameSettings(seedText: "trade", houseCount: 5, radius: 20))
    }

    private func steward(_ state: GameState, _ temperament: Temperament) throws -> Int {
        guard let house = state.houses.first(where: { !$0.isPlayer && $0.temperament == temperament }) else {
            throw XCTSkip("No \(temperament) steward in this world")
        }
        return house.id
    }

    func testTheTermsSayWhatTheyAsk() {
        let trade = Trade(give: .timber, 30, for: .moonsalt, 10)
        XCTAssertEqual(trade.given, Stock(timber: 30))
        XCTAssertEqual(trade.taken, Stock(moonsalt: 10))
        XCTAssertEqual(trade.asking, 100, "Ten moonsalt is worth thirty timber")
        XCTAssertEqual(trade.description, "30 timber for 10 moonsalt")
        XCTAssertFalse(Trade(give: .grain, 5, for: .grain, 5).isWellFormed)
        XCTAssertFalse(Trade(give: .grain, 0, for: .stone, 5).isWellFormed)
        XCTAssertTrue(Trade(give: .grain, 1, for: .stone, 1).isWellFormed)
    }

    func testAStewardTakesFairTermsAndRefusesALopsidedOne() throws {
        var state = world()
        let me = state.player
        let other = try steward(state, .steadfast)
        let mine = state.houses[me].stock, theirs = state.houses[other].stock

        let fair = Trade(give: .timber, 12, for: .stone, 12)
        let events = try state.perform(.offerTrade(fair, to: other, words: nil), as: me)
        XCTAssertEqual(events, [.tradeAnswered(trade: fair, from: me, to: other, accepted: true)])
        XCTAssertEqual(state.houses[me].stock.timber, mine.timber - 12)
        XCTAssertEqual(state.houses[me].stock.stone, mine.stone + 12)
        XCTAssertEqual(state.houses[other].stock.timber, theirs.timber + 12)
        XCTAssertEqual(state.houses[other].stock.stone, theirs.stone - 12)

        let greedy = Trade(give: .timber, 5, for: .stone, 20)
        let before = state.houses
        let refused = try state.perform(.offerTrade(greedy, to: other, words: nil), as: me)
        XCTAssertEqual(refused, [.tradeAnswered(trade: greedy, from: me, to: other, accepted: false)])
        XCTAssertEqual(state.houses, before, "A refused trade moves nothing")
        XCTAssertEqual(state.problems(), [])
    }

    func testTheShrewdAskMoreAndFriendsLess() throws {
        var state = world()
        let me = state.player
        let cunning = try steward(state, .cunning)
        let even = Trade(give: .timber, 10, for: .stone, 10)
        XCTAssertFalse(RivalMind(house: cunning).acceptsTrade(even, from: me, in: state), "The cunning want more than even")
        XCTAssertTrue(RivalMind(house: cunning).acceptsTrade(Trade(give: .timber, 14, for: .stone, 10), from: me, in: state))
        // Gifts lately sent make even terms enough.
        _ = try state.perform(.gift(to: cunning, resource: .moonsalt, amount: 5), as: me)
        _ = try state.perform(.gift(to: cunning, resource: .grain, amount: 40), as: me)
        XCTAssertTrue(RivalMind(house: cunning).acceptsTrade(Trade(give: .timber, 12, for: .stone, 10), from: me, in: state))
    }

    func testAStewardNeverTradesAwayTheGrainItsCompaniesNeed() throws {
        let state = world()
        let me = state.player
        let other = try steward(state, .steadfast)
        let spare = state.houses[other].stock.grain - state.upkeep(of: other) * 3
        let generous = Trade(give: .moonsalt, 5, for: .grain, spare + 1)
        XCTAssertFalse(RivalMind(house: other).acceptsTrade(generous, from: me, in: state))
    }

    func testTradeIsRefusedAtWarAndWithoutTheStores() throws {
        var state = world()
        let me = state.player
        let other = (me + 1) % state.houses.count
        XCTAssertThrowsError(try state.perform(.offerTrade(Trade(give: .stone, 9_000, for: .grain, 1), to: other, words: nil), as: me)) {
            guard case .shortOf = $0 as? RuleError else { return XCTFail("\($0)") }
        }
        XCTAssertThrowsError(try state.perform(.offerTrade(Trade(give: .stone, 1, for: .stone, 1), to: other, words: nil), as: me)) {
            XCTAssertEqual($0 as? RuleError, .invalidAmount)
        }
        XCTAssertThrowsError(try state.perform(.offerTrade(Trade(give: .stone, 1, for: .grain, 1), to: me, words: nil), as: me)) {
            XCTAssertEqual($0 as? RuleError, .unknownHouse)
        }
        XCTAssertThrowsError(try state.perform(.propose(.trade, to: other), as: me), "Trade needs its terms") {
            XCTAssertEqual($0 as? RuleError, .notApplicable)
        }
        _ = try state.perform(.declareWar(on: other), as: me)
        XCTAssertThrowsError(try state.perform(.offerTrade(Trade(give: .stone, 1, for: .grain, 1), to: other, words: nil), as: me)) {
            XCTAssertEqual($0 as? RuleError, .atWarWith(other))
        }
    }

    func testAKeeperAnswersAnOfferOfTradeByEnvoy() throws {
        var state = world()
        let me = state.player
        let other = (me + 1) % state.houses.count
        state.houses[other].isPlayer = true
        let trade = Trade(give: .grain, 20, for: .timber, 15)
        let events = try state.perform(.offerTrade(trade, to: other, words: "Grain for your timber, neighbour. <b>"), as: me)
        guard case .envoyArrived(let envoy) = events.first else { return XCTFail("\(events)") }
        XCTAssertEqual(envoy.proposal, .trade)
        XCTAssertEqual(envoy.trade, trade)
        XCTAssertEqual(envoy.words, "Grain for your timber, neighbour. b", "A keeper's words, plainly")
        XCTAssertThrowsError(try state.perform(.offerTrade(trade, to: other, words: nil), as: me), "One offer at a time") { error in
            XCTAssertEqual(error as? RuleError, .envoyWaiting)
        }
        // It travels whole, as the realm keeps it.
        let kept = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(kept.envoys.first?.trade, trade)

        let mine = state.houses[me].stock, theirs = state.houses[other].stock
        let answered = try state.perform(.answer(envoy: envoy.id, accept: true), as: other)
        XCTAssertEqual(answered, [.tradeAnswered(trade: trade, from: me, to: other, accepted: true)])
        XCTAssertEqual(state.houses[me].stock.grain, mine.grain - 20)
        XCTAssertEqual(state.houses[me].stock.timber, mine.timber + 15)
        XCTAssertEqual(state.houses[other].stock.grain, theirs.grain + 20)
        XCTAssertEqual(state.houses[other].stock.timber, theirs.timber - 15)
        XCTAssertTrue(state.envoys.isEmpty)

        // Heard by the two alone.
        let third = (me + 2) % state.houses.count
        XCTAssertEqual(state.events(answered, heardBy: other), answered)
        XCTAssertEqual(state.events(answered, heardBy: third), [])
    }

    func testAnOfferTheMakerCanNoLongerKeepFallsThrough() throws {
        var state = world()
        let me = state.player
        let other = (me + 1) % state.houses.count
        state.houses[other].isPlayer = true
        let all = state.houses[me].stock.grain
        let events = try state.perform(.offerTrade(Trade(give: .grain, all, for: .timber, 5), to: other, words: nil), as: me)
        guard case .envoyArrived(let envoy) = events.first else { return XCTFail("\(events)") }
        // Meanwhile its grain goes elsewhere.
        _ = try state.perform(.gift(to: (me + 2) % state.houses.count, resource: .grain, amount: 1), as: me)
        let before = state.houses
        let answered = try state.perform(.answer(envoy: envoy.id, accept: true), as: other)
        XCTAssertEqual(answered.first, .tradeAnswered(trade: envoy.trade!, from: me, to: other, accepted: false))
        XCTAssertEqual(state.houses, before)

        // Refused, nothing moves either.
        let second = try state.perform(.offerTrade(Trade(give: .timber, 5, for: .stone, 5), to: other, words: nil), as: me)
        guard case .envoyArrived(let next) = second.first else { return XCTFail("\(second)") }
        let held = state.houses
        XCTAssertEqual(try state.perform(.answer(envoy: next.id, accept: false), as: other).first,
                       .tradeAnswered(trade: next.trade!, from: me, to: other, accepted: false))
        XCTAssertEqual(state.houses, held)
    }

    func testStewardsTradeAmongThemselvesBeforeBartering() {
        // A realm of stewards alone, played a while: their wants meet now
        // and then, and they trade rather than lose two thirds to barter.
        var traded = 0, bartered = 0
        for seed in ["market a", "market b", "market c"] {
            var state = GameState(settings: GameSettings(seedText: seed, houseCount: 6, radius: 22, keepers: 0))
            for _ in 0..<60 where state.outcome == nil {
                for house in state.livingHouses {
                    for event in state.stewardTurn(for: house.id) {
                        if case .tradeAnswered(_, _, _, true) = event { traded += 1 }
                        if case .bartered = event { bartered += 1 }
                    }
                }
                _ = state.endWatch()
            }
            XCTAssertEqual(state.problems(), [], seed)
        }
        print("PERF trade among stewards over 3 x 60 watches: \(traded) trades, \(bartered) barters")
        XCTAssertGreaterThan(traded, 0, "Stewards find each other to trade with")
    }
}
