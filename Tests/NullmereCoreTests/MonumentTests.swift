import XCTest
@testable import NullmereCore

final class MonumentTests: XCTestCase {
    /// The lake raises its Monument together: what each House does counts
    /// toward the stone being raised, each House's part kept; the stone set
    /// as the watch turns gives every House its gift and those who did their
    /// part a share of moonsalt by it; then the next stone is begun.
    func testTheLakeRaisesItsMonumentTogether() throws {
        var state = GameState(settings: GameSettings(seedText: "monument", houseCount: 4, radius: 14, keepers: 2))
        let me = state.player, other = (me + 1) % state.houses.count
        XCTAssertEqual(state.lakeMonument.raising, .foundations, "the first stone begun")
        let hold = try XCTUnwrap(state.holds(of: me).first), theirs = try XCTUnwrap(state.holds(of: other).first)
        state.countMonument([.buildingCompleted(hold: hold.id, kind: .granary, level: 2), .buildingCompleted(hold: hold.id, kind: .sawpit, level: 2),
                             .buildingCompleted(hold: theirs.id, kind: .quarry, level: 2), .studyCompleted(house: me, study: .woodcraft, grade: 1)])
        XCTAssertEqual(state.lakeMonument.done, 3, "works raised count toward the Foundations; a study does not")
        XCTAssertEqual(state.monumentPart(of: me), 2)
        XCTAssertEqual(state.monumentPart(of: other), 1)
        XCTAssertTrue(state.setMonumentStone().isEmpty, "not set before its deed is done")

        state.countMonument(Array(repeating: .buildingCompleted(hold: hold.id, kind: .granary, level: 3),
                                  count: MonumentStone.foundations.measure))
        let before = state.houses.map(\.stock), items = state.houses.indices.map { house in state.satchel(of: house).reduce(0) { $0 + $1.count } }
        let events = state.setMonumentStone()
        XCTAssertEqual(events.first, .monumentStoneSet(stone: .foundations))
        XCTAssertEqual(state.lakeMonument.raising, .musters, "the next stone begun")
        XCTAssertEqual(state.lakeMonument.done, 0)
        let gift = MonumentStone.foundations.gift
        for house in state.houses.indices where !state.houses[house].isEliminated {
            XCTAssertGreaterThanOrEqual(state.houses[house].stock.timber, min(before[house].timber + gift.stock.timber, state.storage(of: house)),
                                        "every House given its gift")
            XCTAssertGreaterThan(state.satchel(of: house).reduce(0) { $0 + $1.count }, items[house])
        }
        XCTAssertGreaterThan(state.houses[me].stock.moonsalt - before[me].moonsalt, state.houses[other].stock.moonsalt - before[other].moonsalt,
                             "the greater part, the greater share")
        // Seen by every keeper, and told to all.
        XCTAssertEqual(state.view(for: other).lakeMonument, state.lakeMonument)
        XCTAssertNotNil(state.tidings(of: .monumentStoneSet(stone: .foundations), for: other))
    }

    /// Played through, the stewards' realm sets stones of its own accord.
    func testAnAgeSetsStones() {
        var state = GameState(settings: GameSettings(seedText: "monument age", houseCount: 6, radius: 16, keepers: 0))
        for _ in 0..<60 { _ = state.endWatch() }
        XCTAssertGreaterThanOrEqual(state.lakeMonument.set, 1, "the lake's Houses set at least the Foundations in sixty watches")
    }
}
