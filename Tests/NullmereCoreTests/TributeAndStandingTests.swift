import Foundation
import XCTest
@testable import NullmereCore

final class TributeTests: XCTestCase {
    private func game() -> GameState {
        GameState(settings: GameSettings(seedText: "tribute", houseCount: 3, radius: 16, keepers: 1))
    }

    func testAPaidTributeMovesAFifthOfTheStoresAndKeepsThePeace() throws {
        var state = game()
        let rival = 1
        let price = state.tribute(from: state.player)
        XCTAssertEqual(price, state.houses[state.player].stock.share(1, of: 5))
        let mine = state.houses[state.player].stock
        let theirs = state.houses[rival].stock

        let events = try state.propose(.tribute, from: rival, to: state.player)
        let envoy = try XCTUnwrap(state.envoys.first)
        XCTAssertEqual(envoy.proposal, .tribute)
        XCTAssertTrue(events.contains(.envoyArrived(envoy)))
        try state.perform(.answer(envoy: envoy.id, accept: true), as: state.player)

        XCTAssertEqual(state.houses[state.player].stock + price, mine)
        XCTAssertEqual(state.houses[rival].stock, theirs + price)
        XCTAssertEqual(state.stance(state.player, rival), .peace)
        XCTAssertTrue(state.paidTributeLately(rival, state.player))
        XCTAssertThrowsError(try state.propose(.tribute, from: rival, to: state.player), "Not again so soon")
        XCTAssertTrue(state.chronicle.contains { $0.kind == .tribute && $0.text.contains("pays tribute") })
    }

    func testARefusedDemandMeansWar() throws {
        var state = game()
        let rival = 1
        _ = try state.propose(.tribute, from: rival, to: state.player)
        let envoy = try XCTUnwrap(state.envoys.first)
        let events = try state.perform(.answer(envoy: envoy.id, accept: false), as: state.player)
        XCTAssertEqual(state.stance(state.player, rival), .war)
        XCTAssertTrue(events.contains(.stanceChanged(first: rival, second: state.player, stance: .war, by: rival)))
        XCTAssertTrue(state.chronicle.contains { $0.text.contains("refuses tribute") })
    }

    func testAnUnansweredDemandIsARefusal() throws {
        var state = game()
        let rival = 1
        _ = try state.propose(.tribute, from: rival, to: state.player)
        for _ in 0..<Envoy.patience where state.stance(state.player, rival) != .war {
            _ = state.endWatch()
        }
        XCTAssertEqual(state.stance(state.player, rival), .war)
    }

    func testAWeakRivalPaysTheStrongAndAStrongOneRefuses() throws {
        var state = game()
        let rival = 1
        // Strip the rival bare; give the player an army.
        state.units.removeAll { $0.owner == rival }
        let seat = try XCTUnwrap(state.seat(of: state.player))
        for _ in 0..<6 { state.placeUnit(.spear, for: state.player, near: seat.position) }
        let theirs = state.houses[rival].stock
        let events = try state.propose(.tribute, from: state.player, to: rival)
        XCTAssertTrue(events.contains(.proposalAnswered(proposal: .tribute, from: state.player, to: rival, accepted: true)))
        XCTAssertEqual(state.houses[rival].stock + theirs.share(1, of: 5), theirs)

        // The other rival is as strong as the player was at the start: no
        // tribute, and a steward that refuses is marched on, the war the
        // demander's own.
        var even = game()
        even.gifts = [Gift(from: even.player, to: 2, worth: 50, watch: even.watch)]
        let refused = try even.propose(.tribute, from: even.player, to: 2)
        XCTAssertTrue(refused.contains(.proposalAnswered(proposal: .tribute, from: even.player, to: 2, accepted: false)))
        XCTAssertTrue(refused.contains(.stanceChanged(first: even.player, second: 2, stance: .war, by: even.player)))
        XCTAssertEqual(even.relation(even.player, 2)?.aggressor, even.player, "A demand refused is no free throw")
        XCTAssertEqual(even.goodwill(from: even.player, to: 2), 0, "and the war throws away the goodwill")
    }

    /// Between two keepers, a refusal is the end of it: the demander may
    /// choose war, but none follows of itself.
    func testAKeeperRefusedByAKeeperIsNotAtWar() throws {
        var state = game()
        let me = state.player, other = 1
        state.houses[other].isPlayer = true
        _ = try state.propose(.tribute, from: me, to: other)
        let demand = try XCTUnwrap(state.envoys.first { $0.from == me && $0.to == other })
        let events = try state.perform(.answer(envoy: demand.id, accept: false), as: other)
        XCTAssertTrue(events.contains(.proposalAnswered(proposal: .tribute, from: me, to: other, accepted: false)))
        XCTAssertEqual(state.stance(me, other), .peace)
    }

    func testTributeIsOnlyAskedInPeace() throws {
        var state = game()
        _ = try state.declareWar(by: state.player, on: 1)
        XCTAssertThrowsError(try state.propose(.tribute, from: 1, to: state.player))
    }

    /// Over simulated games, rivals do demand tribute of one another, and
    /// some pay it.
    func testRivalsDemandTributeInPlay() {
        var demanded = 0, paid = 0
        // Played until a tribute is paid, in one of a few worlds.
        for seed in 0..<6 where paid == 0 {
            var state = GameState(settings: GameSettings(seedText: "tribute play \(seed)", keepers: 1))
            while state.outcome == nil, state.watch < 120,
                  !state.chronicle.contains(where: { $0.kind == .tribute && $0.text.contains("pays tribute") }) {
                state.stewardTurn(for: state.player)
                _ = state.endWatch()
            }
            demanded += state.chronicle.filter { $0.kind == .tribute }.count
            paid += state.chronicle.filter { $0.kind == .tribute && $0.text.contains("pays tribute") }.count
        }
        XCTAssertGreaterThan(demanded, 0)
        XCTAssertGreaterThan(paid, 0)
    }
}

final class StandingAndHistoryTests: XCTestCase {
    func testEveryWatchLeavesASnapshot() {
        var state = GameState(settings: GameSettings(seedText: "history", houseCount: 3, radius: 16, keepers: 1))
        XCTAssertEqual(state.history.map(\.watch), [1])
        for _ in 0..<5 {
            state.stewardTurn(for: state.player)
            _ = state.endWatch()
        }
        XCTAssertEqual(state.history.map(\.watch), [1, 2, 3, 4, 5, 6])
        let last = state.history.last!
        XCTAssertEqual(last.holds, state.houses.map { state.holds(of: $0.id).count })
        XCTAssertEqual(last.strength[state.player], state.strength(of: state.player))
    }

    func testSavesFromBeforeTheHistoryStillOpen() throws {
        let state = GameState(settings: GameSettings(seedText: "old history", houseCount: 3, radius: 16, keepers: 1))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json["recorded"] = nil
        // Its relations kept field by field, as they were then, with no tribute.
        json["relations"] = state.relations.map { relation -> [String: Any] in
            ["first": relation.first, "second": relation.second, "stance": relation.stance.rawValue, "since": relation.since,
             "betrayals": relation.betrayals]
        }
        let restored = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(restored.history.isEmpty)
        XCTAssertNil(restored.relations.first?.tributePaid)
        XCTAssertEqual(restored.relations, state.relations)
    }

    func testStandingsNameTheNearestThreat() throws {
        var state = GameState(settings: GameSettings(seedText: "standing", houseCount: 3, radius: 16, keepers: 1))
        XCTAssertEqual(state.dominionNeed, GameState.supremacyMinimum, "A young lake still needs ten holds")
        XCTAssertTrue(state.standings().allSatisfy { $0.threat == nil })

        let rival = 1
        let seat = try XCTUnwrap(state.seat(of: rival))
        state.holds[state.holdIndex(seat.id)!].levels[.moonspire] = 4
        let standing = state.standing(of: rival)
        XCTAssertEqual(standing.spire, 4)
        XCTAssertEqual(standing.spirePercent, 80)
        XCTAssertEqual(standing.threat, .ascendancy)
        XCTAssertEqual(state.standings().first?.house, rival, "The nearest to winning comes first")

        state.houses[rival].liege = state.player
        XCTAssertNil(state.standing(of: rival).threat, "A vassal threatens no one")
    }
}
