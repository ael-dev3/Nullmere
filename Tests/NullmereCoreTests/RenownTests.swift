import XCTest
@testable import NullmereCore

/// A House's renown, for ranking the Houses: reckoned for one House from
/// its own holds and companies, or for every House at once from the whole
/// realm, the same either way.
final class RenownTests: XCTestCase {
    /// Whether a House is the most renowned is asked of each House's own
    /// holds and companies as the realm keeps them: always what the renown
    /// of every House reckoned at once from the whole realm says, through a
    /// played age.
    func testTheForemostHouseIsTheOneTheWholeRealmsRenownSays() {
        var state = GameState(settings: GameSettings(seedText: "the foremost house", houseCount: 6, radius: 20))
        var foremost = 0
        for _ in 1...24 {
            state.endWatch()
            let renowns = state.renowns()
            XCTAssertEqual(renowns, state.houses.indices.map { state.renown(of: $0) })
            for house in state.houses.indices {
                let expected = state.livingIDs.allSatisfy { $0 == house || renowns[$0] <= renowns[house] }
                XCTAssertEqual(state.isForemost(house), expected, "House \(house) in watch \(state.watch)")
                if expected { foremost += 1 }
            }
        }
        XCTAssertGreaterThan(foremost, 0)
        XCTAssertFalse(state.isForemost(-1))
        XCTAssertFalse(state.isForemost(state.houses.count))
    }
}
