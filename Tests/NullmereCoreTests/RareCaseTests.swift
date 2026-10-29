import Foundation
import XCTest
@testable import NullmereCore

/// The rules for what seldom happens: a save that can't be read, names run
/// out, a draw that must be thrown again, the forecast's every reading.
final class RareCaseTests: XCTestCase {
    /// Every temperament, omen and feature has a name of its own.
    func testEveryKindIsNamed() {
        for titles in [Temperament.allCases.map(\.title), OmenKind.allCases.map(\.title), Feature.allCases.map(\.title)] {
            XCTAssertFalse(titles.contains(where: \.isEmpty))
            XCTAssertEqual(Set(titles).count, titles.count, "\(titles)")
        }
        XCTAssertEqual(Feature.drownedRuin.title, "Drowned Ruin")
        XCTAssertEqual(OmenKind.stillNight.title, "Still Night")
        XCTAssertEqual(Temperament.cunning.title, "Cunning")
    }

    /// A map whose tiles can't be read, or don't fill its radius, is refused.
    func testAMapThatCantBeReadIsRefused() throws {
        let map = GameState(settings: GameSettings(seedText: "unreadable", houseCount: 3, radius: 16)).map
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(map)) as? [String: Any])
        XCTAssertNotNil(saved["cells"], "Maps are kept as cells")
        func decoded(_ changes: [String: Any]) throws -> WorldMap {
            try JSONDecoder().decode(WorldMap.self, from: JSONSerialization.data(withJSONObject: saved.merging(changes) { $1 }))
        }
        XCTAssertEqual(try decoded([:]), map)
        XCTAssertThrowsError(try decoded(["cells": "not cells"]), "Unreadable tiles")
        XCTAssertThrowsError(try decoded(["radius": map.radius + 1]), "Too few tiles for the radius")
    }

    /// A House whose explored ground can't be read is refused.
    func testAHouseWhoseGroundCantBeReadIsRefused() throws {
        let house = GameState(settings: GameSettings(seedText: "unreadable", houseCount: 3, radius: 16)).houses[0]
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(house)) as? [String: Any])
        func decoded(_ bits: String) throws -> House {
            var changed = saved
            changed["exploredBits"] = bits
            return try JSONDecoder().decode(House.self, from: JSONSerialization.data(withJSONObject: changed))
        }
        XCTAssertEqual(try decoded(try XCTUnwrap(saved["exploredBits"] as? String)), house)
        XCTAssertThrowsError(try decoded("12:###"))
        XCTAssertThrowsError(try decoded("no count"))
    }

    /// With every name taken, a hold is numbered; with that taken too, the
    /// next number.
    func testHoldsAreNumberedWhenTheNamesRunOut() {
        var random = SeededRandom(seed: 7)
        var used: Set<String> = []
        var numbered: [String] = []
        for _ in 0..<50_000 where !numbered.contains(where: { $0.hasSuffix(" 3") }) {
            let name = Names.hold(using: &random, avoiding: used)
            XCTAssertFalse(used.contains(name), "A name not already in use")
            used.insert(name)
            if let last = name.split(separator: " ").last, Int(last) != nil { numbered.append(name) }
        }
        XCTAssertTrue(numbered.contains { $0.hasSuffix(" 2") }, "The names ran out, and numbers followed")
        XCTAssertTrue(numbered.contains { $0.hasSuffix(" 3") }, "A number taken, the next: \(numbered)")
    }

    /// Draws below a bound that doesn't divide the generator's range are
    /// thrown again where they would bias it; all land in range.
    func testDrawsStayInRangeAndUnbiased() {
        var random = SeededRandom(seed: 11)
        let bound = (1 << 62) + 1
        for _ in 0..<200 {
            let value = random.int(below: bound)
            XCTAssertTrue((0..<bound).contains(value))
        }
        var units: [Double] = []
        for _ in 0..<1_000 { units.append(random.unit()) }
        XCTAssertTrue(units.allSatisfy { (0..<1).contains($0) })
        let mean = units.reduce(0, +) / Double(units.count)
        XCTAssertEqual(mean, 0.5, accuracy: 0.05)
    }

    func testTheForecastReadsEachWay() {
        let glancing = Forecast(target: .unit(.spear), dealt: 3...5, taken: 0...0, defenderHealth: 4, attackerHealth: 10, couldCapture: false)
        XCTAssertTrue(glancing.mayFinish)
        XCTAssertFalse(glancing.surelyFinishes)
        XCTAssertFalse(glancing.mayFall)
        let costly = Forecast(target: .hold(1), dealt: 9...12, taken: 6...11, defenderHealth: 8, attackerHealth: 10, couldCapture: true)
        XCTAssertTrue(costly.surelyFinishes)
        XCTAssertTrue(costly.mayFall)
    }

    /// What a company could strike are the hexes the forecast reaches.
    func testStrikeTargetsAreWhatCouldBeStruck() throws {
        let state = GameState(settings: GameSettings(seedText: "strikes", houseCount: 3, radius: 16))
        for unit in state.units where unit.kind.isMilitary {
            for hex in state.strikeTargets(of: unit) {
                XCTAssertNotNil(state.forecast(unit: unit.id, at: hex))
                XCTAssertLessThanOrEqual(unit.position.distance(to: hex), unit.kind.range)
            }
        }
    }

    /// A company trained where every hex near the hold is taken waits, its
    /// training done, and musters the watch a hex falls free.
    func testATrainedCompanyWaitsForRoomToStand() throws {
        var state = GameState(settings: GameSettings(seedText: "no room", houseCount: 3, radius: 16))
        let me = state.player
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        state.holds[seat].training = Hold.Training(kind: .spear, watchesLeft: 1)
        let around = state.holds[seat].position.spiral(3).filter { hex in
            state.map[hex]?.terrain.isPassable == true && state.unit(at: hex) == nil
        }
        var blockers: [Int] = []
        for hex in around {
            var lantern = Unit(id: state.nextID, kind: .lantern, owner: me, position: hex)
            lantern.fortified = true
            state.units.append(lantern)
            blockers.append(state.nextID)
            state.nextID += 1
        }
        let mustered = { (events: [GameEvent]) in
            events.contains { if case .unitTrained(_, let hold) = $0 { return hold == state.holds[seat].id } else { return false } }
        }
        let first = state.endWatch()
        XCTAssertFalse(mustered(first), "No room to stand")
        XCTAssertEqual(state.holds[seat].training?.watchesLeft, 0, "Its training done, it waits")
        state.units.removeAll { $0.id == blockers[0] }
        let second = state.endWatch()
        XCTAssertTrue(mustered(second), "A hex free, it musters")
        XCTAssertNil(state.holds[seat].training)
    }

    /// A trade is weighed on its terms alone, never accepted as a proposal.
    func testATradeIsNotAcceptedAsAProposal() {
        let state = GameState(settings: GameSettings(seedText: "terms", houseCount: 3, radius: 16))
        let rival = state.houses.first { !$0.isPlayer }!.id
        XCTAssertFalse(RivalMind(house: rival).accepts(.trade, from: state.player, in: state))
    }
}
