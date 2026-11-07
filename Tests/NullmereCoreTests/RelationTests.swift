import XCTest
@testable import NullmereCore

/// Every two Houses have their relation: kept for those that have dealt,
/// found at once among them in their order, and for every other two as
/// they stand, at peace as the age begins.
final class RelationTests: XCTestCase {
    func testEveryPairsRelationIsFound() {
        var state = GameState(settings: GameSettings(seedText: "relations", houseCount: 6, keepers: 1))
        let count = state.houses.count
        XCTAssertTrue(state.relations.isEmpty, "None kept before any two Houses deal")
        for a in 0..<count {
            XCTAssertNil(state.relation(a, a))
            XCTAssertEqual(state.stance(a, a), .pact)
            for b in 0..<count where b != a {
                XCTAssertEqual(state.relation(a, b), Relation(first: a, second: b), "At peace since the age began")
                XCTAssertNil(state.relationIndex(a, b))
            }
        }
        XCTAssertNil(state.relation(0, count), "No House beyond the last")
        XCTAssertNil(state.relation(-1, 0))
        // Dealing keeps their relation, in its place among those kept.
        state.setStance(.war, between: 4, and: 1, by: 4)
        state.setStance(.pact, between: 3, and: 2, by: 2)
        state.setStance(.peace, between: 5, and: 0, by: 0)
        XCTAssertEqual(state.relations.map { [$0.first, $0.second] }, [[0, 5], [1, 4], [2, 3]])
        XCTAssertTrue(state.isAtWar(1, 4))
        XCTAssertEqual(state.relation(4, 1)?.aggressor, 4)
        XCTAssertEqual(state.stance(3, 2), .pact)
        XCTAssertEqual(state.relationIndex(2, 3), state.relationIndex(3, 2))
        XCTAssertEqual(state.relation(0, 5)?.since, state.watch)
        XCTAssertEqual(state.relation(1, 2), Relation(first: 1, second: 2), "Two that never dealt, as ever")
        XCTAssertEqual(state.problems(), [])
        // Kept again, the same one, not another.
        XCTAssertEqual(state.keptRelationIndex(1, 4), state.relationIndex(4, 1))
        XCTAssertEqual(state.relations.count, 3)
        XCTAssertNil(state.keptRelationIndex(2, 2))
        XCTAssertNil(state.keptRelationIndex(0, count))
        XCTAssertEqual(state.relations.count, 3)
        // Out of their order, they are no world's.
        state.relations.reverse()
        XCTAssertTrue(state.problems().contains("The standings kept are out of order"))
    }
}
