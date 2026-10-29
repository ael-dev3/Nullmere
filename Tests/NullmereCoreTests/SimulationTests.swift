import XCTest
@testable import NullmereCore

/// Whole games played by stewards, checking the rules' invariants every watch.
final class SimulationTests: XCTestCase {
    func testWholeGamesKeepTheirInvariants() {
        for seed in ["sim one", "sim two"] {
            var state = GameState(settings: GameSettings(seedText: seed, keepers: 1))
            for _ in 0..<110 {
                state.stewardTurn(for: state.player)
                state.endWatch()
                assertInvariants(state, seed)
                if state.outcome != nil { break }
            }
            XCTAssertGreaterThan(state.chronicle.count, 5, "\(seed): something happened")
        }
    }

    private func assertInvariants(_ state: GameState, _ seed: String, file: StaticString = #filePath, line: UInt = #line) {
        let positions = state.units.map(\.position)
        XCTAssertEqual(Set(positions).count, positions.count, "\(seed): two units share a tile at watch \(state.watch)", file: file, line: line)
        for unit in state.units {
            XCTAssertEqual(state.map[unit.position]?.terrain.isPassable, true, "\(seed): unit on impassable ground", file: file, line: line)
            XCTAssertFalse(state.houses[unit.owner].isEliminated, "\(seed): a fallen House still has units", file: file, line: line)
            XCTAssertTrue((1...100).contains(unit.health), file: file, line: line)
            if let hold = state.hold(at: unit.position) {
                XCTAssertEqual(hold.owner, unit.owner, "\(seed): a unit stands in a foreign hold", file: file, line: line)
            }
        }
        for hold in state.holds {
            XCTAssertFalse(state.houses[hold.owner].isEliminated, file: file, line: line)
            XCTAssertTrue((0...hold.maximumWard).contains(hold.ward), file: file, line: line)
            for (kind, level) in hold.levels {
                XCTAssertTrue((1...kind.maxLevel).contains(level), file: file, line: line)
            }
        }
        for house in state.livingHouses {
            XCTAssertEqual(state.holds(of: house.id).filter(\.isSeat).count, 1, "\(seed): \(house.title) needs exactly one seat", file: file, line: line)
            for resource in Resource.allCases {
                XCTAssertTrue((0...Stock.cap).contains(house.stock[resource]), file: file, line: line)
            }
        }
    }
}
