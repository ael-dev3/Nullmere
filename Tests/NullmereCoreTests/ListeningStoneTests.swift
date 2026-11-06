import Foundation
import XCTest
@testable import NullmereCore

/// Listening stones: sunk in the water before a hold on the shore, a
/// House's stone hears every march of another House's companies of war
/// within its reach and out of the House's sight: only the quarter and
/// whether near or far. Its House's alone.
final class ListeningStoneTests: XCTestCase {
    /// A world, a hold of the keeper's on the shore, and another House.
    private func world() throws -> (GameState, me: Int, other: Int, hold: Hold) {
        var state = GameState(settings: GameSettings(seedText: "listening stones", houseCount: 4, radius: 20, keepers: 1))
        let me = state.player
        let other = (me + 1) % state.houses.count
        let hold = try XCTUnwrap(state.holds(of: me).first { state.stoneWater(before: $0) != nil }
            ?? state.holds.first { state.stoneWater(before: $0) != nil })
        if hold.owner != me { state.holds[state.holdIndex(hold.id)!].owner = me }
        state.houses[me].stock.credit(Stock(moonsalt: 40))
        return (state, me, other, try XCTUnwrap(state.hold(hold.id)))
    }

    func testAStoneIsSunkBeforeAShoreHoldForMoonsaltAndKeptToThree() throws {
        var (state, me, other, hold) = try world()
        XCTAssertEqual(state.refusal(of: .sinkStone(hold: hold.id), as: other), .notYours)
        let salt = state.houses[me].stock.moonsalt
        let events = try state.perform(.sinkStone(hold: hold.id), as: me)
        let stone = try XCTUnwrap(state.stones(of: me).first)
        XCTAssertEqual(events, [.stoneSunk(stone: stone.id, house: me, hold: hold.id)])
        XCTAssertEqual(state.houses[me].stock.moonsalt, salt - GameState.stoneCost.moonsalt)
        XCTAssertEqual(state.map[stone.at]?.terrain.isWater, true, "It lies in the water")
        XCTAssertLessThanOrEqual(stone.at.distance(to: hold.position), GameState.stoneFromHold)
        XCTAssertEqual(state.refusal(of: .sinkStone(hold: hold.id), as: me), .stoneAlreadySunk)
        XCTAssertEqual(RuleError.tooManyStones(3).description, "Your House keeps 3 listening stones in the lake, and no more.")
        XCTAssertNotNil(state.tidings(of: events[0], for: me))
        XCTAssertNil(state.tidings(of: events[0], for: other))
        XCTAssertEqual(state.events(events, heardBy: other), [], "Another House knows nothing of it")
        // No stone where no water is near.
        if let inland = state.holds.first(where: { state.stoneWater(before: $0) == nil }) {
            XCTAssertEqual(state.refusal(of: .sinkStone(hold: inland.id), as: inland.owner), .notOnTheShore)
        }
        // A House without the moonsalt is short of it.
        state.houses[me].stock.debit(Stock(moonsalt: state.houses[me].stock.moonsalt))
        let second = state.holds.first { $0.id != hold.id && state.stoneWater(before: $0) != nil && state.stoneWater(before: $0) != stone.at }
        if let second {
            state.holds[state.holdIndex(second.id)!].owner = me
            XCTAssertEqual(state.refusal(of: .sinkStone(hold: second.id), as: me), .shortOf(Stock(moonsalt: GameState.stoneCost.moonsalt)))
        }
        XCTAssertEqual(state.problems(), [])
    }

    func testAStoneHearsAMarchOutOfSightByItsQuarterNotWhereItIs() throws {
        var (state, me, other, hold) = try world()
        _ = try state.perform(.sinkStone(hold: hold.id), as: me)
        let stone = try XCTUnwrap(state.stones(of: me).first)
        // A company of the other House's, on land within reach and out of sight.
        let seen = state.visibility(for: me)
        let hidden = try XCTUnwrap(stone.at.spiral(GameState.stoneReach).first { hex in
            guard let index = state.map.index(of: hex), !seen[index], let tile = state.map[hex], tile.terrain.isPassable else { return false }
            return hex.distance(to: stone.at) >= 2 && state.unit(at: hex) == nil && state.hold(at: hex) == nil
                && hex.neighbors.contains { state.map[$0]?.terrain.isPassable == true && state.unit(at: $0) == nil && state.hold(at: $0) == nil
                    && !(state.map.index(of: $0).map { seen[$0] } ?? true) && $0.distance(to: stone.at) <= GameState.stoneReach }
        })
        let step = try XCTUnwrap(hidden.neighbors.first { state.map[$0]?.terrain.isPassable == true && state.unit(at: $0) == nil
            && state.hold(at: $0) == nil && !(state.map.index(of: $0).map { seen[$0] } ?? true) && $0.distance(to: stone.at) <= GameState.stoneReach })
        var company = Unit(id: state.takeID(), kind: .spear, owner: other, position: hidden)
        company.health = 100
        state.units.append(company)
        // The first listening only learns where all stand.
        _ = state.listenAtTheStones()
        XCTAssertTrue(state.soundings(heardBy: me).isEmpty, "Standing still, it is not heard")
        state.units[state.unitIndex(company.id)!].position = step
        let events = state.listenAtTheStones()
        XCTAssertEqual(events, [.stoneHeard(stone: stone.id, house: me, marches: 1)])
        let sounding = try XCTUnwrap(state.soundings(heardBy: me).first)
        XCTAssertEqual(sounding.quarter, GameState.quarter(of: step, from: stone.at))
        XCTAssertEqual(sounding.near, step.distance(to: stone.at) <= GameState.stoneReach / 2)
        let told = try XCTUnwrap(state.tidings(of: events[0], for: me)).text
        XCTAssertTrue(told.contains("to the \(sounding.quarterName)"), told)
        XCTAssertFalse(told.contains(state.houses[other].title), "Whose it is, the stone can't tell")
        // Its House alone knows: the other's view holds no stone nor sounding.
        XCTAssertEqual(state.view(for: other).listeningStones, nil)
        XCTAssertEqual(state.view(for: other).soundings, nil)
        XCTAssertEqual(state.view(for: me).soundings, [sounding])
        XCTAssertNil(state.view(for: me).listened, "Where others stand is never in a view")
        // A march in plain sight is seen, not heard.
        state.units[state.unitIndex(company.id)!].position = hidden
        state.houses[me].explored = Explored(repeating: true, count: state.houses[me].explored.count)
        var sighted = state
        sighted.units.append(Unit(id: sighted.takeID(), kind: .spear, owner: me, position: step))
        sighted.refreshSight()
        XCTAssertTrue(sighted.listenAtTheStones().isEmpty, "In sight: no sounding")
        XCTAssertEqual(state.problems(), [])
    }

    func testAStoneIsLostWithItsHold() throws {
        var (state, me, other, hold) = try world()
        _ = try state.perform(.sinkStone(hold: hold.id), as: me)
        let stone = try XCTUnwrap(state.stones(of: me).first)
        state.holds[state.holdIndex(hold.id)!].owner = other
        XCTAssertEqual(state.listenAtTheStones(), [.stoneLost(stone: stone.id, house: me)])
        XCTAssertTrue(state.stones(of: me).isEmpty)
        XCTAssertNil(state.listeningStones)
        // And the watch's turn listens.
        var turned = try world().0
        _ = try turned.perform(.sinkStone(hold: hold.id), as: me)
        _ = turned.endWatch()
        XCTAssertEqual(turned.stones(of: me).count, 1)
        XCTAssertEqual(turned.stones(of: me).first?.listening, true, "The turn of the watch listens at the stone")
    }
}

extension ListeningStoneTests {
    func testAWaryStewardAtWarSinksOneStoneBeforeItsSeat() throws {
        var (state, me, other, _) = try world()
        _ = me
        let steward = other
        state.houses[steward].temperament = .wary
        state.houses[steward].stock.credit(Stock(moonsalt: 40))
        XCTAssertTrue(RivalMind(house: steward).sinkAListeningStone(in: &state).isEmpty, "At peace, no stone")
        state.setStance(.war, between: steward, and: (steward + 1) % state.houses.count, by: steward)
        let sunk = RivalMind(house: steward).sinkAListeningStone(in: &state)
        if state.holds(of: steward).contains(where: { state.stoneWater(before: $0) != nil }) {
            XCTAssertEqual(sunk.count, 1)
            XCTAssertEqual(state.stones(of: steward).count, 1)
            XCTAssertTrue(RivalMind(house: steward).sinkAListeningStone(in: &state).isEmpty, "One, never more")
        }
        XCTAssertEqual(state.problems(), [])
    }
}
