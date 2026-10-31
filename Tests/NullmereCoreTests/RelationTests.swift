import XCTest
@testable import NullmereCore

/// Every pair of Houses has its relation, found at once where the
/// relations lie in the order they are made, and found still where they
/// lie otherwise.
final class RelationTests: XCTestCase {
    func testEveryPairsRelationIsFoundAtItsPlace() {
        var state = GameState(settings: GameSettings(seedText: "relations", houseCount: 6, keepers: 1))
        let count = state.houses.count
        for a in 0..<count {
            XCTAssertNil(state.relation(a, a))
            XCTAssertEqual(state.stance(a, a), .pact)
            for b in 0..<count where b != a {
                let found = state.relation(a, b)
                XCTAssertEqual(found?.first, min(a, b))
                XCTAssertEqual(found?.second, max(a, b))
                XCTAssertEqual(state.relationIndex(a, b), state.relationIndex(b, a))
            }
        }
        XCTAssertNil(state.relation(0, count), "No House beyond the last")
        XCTAssertNil(state.relation(-1, 0))
        // Out of their order, each is found still, and its stance set.
        state.setStance(.war, between: 1, and: 4, by: 1)
        state.relations.reverse()
        XCTAssertTrue(state.isAtWar(4, 1))
        state.setStance(.pact, between: 2, and: 3, by: 2)
        XCTAssertEqual(state.stance(3, 2), .pact)
        XCTAssertEqual(state.relation(2, 3)?.stance, .pact)
    }
}
