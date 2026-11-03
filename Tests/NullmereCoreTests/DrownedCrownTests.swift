import XCTest
@testable import NullmereCore

/// The Drowned Crown: surfaced at the heart of the ford as it lies bare,
/// taken up by a company of war that stands on it, marking its side each
/// watch it is borne, let fall when its bearer is struck down, and given
/// to the side that bore it longest as the water comes back.
final class DrownedCrownTests: XCTestCase {
    /// A world as the ford lies bare, the crown at its heart.
    private func bare(_ seed: String) throws -> (GameState, heart: Hex) {
        var state = GameState(settings: GameSettings(seedText: seed, keepers: 1))
        state.watch = Sundering.first - 1
        let events = state.endWatch()
        let crown = try XCTUnwrap(state.crown, "Surfaced with the ford")
        XCTAssertTrue(events.contains(.crownSurfaced(at: crown.hex)), "\(events)")
        let course = try XCTUnwrap(state.ford)
        XCTAssertEqual(crown.hex, course[course.count / 2])
        XCTAssertNil(crown.bearer)
        state.units.removeAll { $0.position == crown.hex }
        return (state, crown.hex)
    }

    func testACompanyTakesUpTheCrownAndItsSideIsMarkedEachWatch() throws {
        var (state, heart) = try bare("the drowned crown")
        let me = state.player
        let company = Unit(id: state.takeID(), kind: .spear, owner: me, position: heart, tier: 1)
        state.units.append(company)
        XCTAssertEqual(state.contestCrown(), [.crownTaken(unit: company.id, house: me)])
        XCTAssertEqual(state.crown?.bearer, company.id)
        XCTAssertEqual(state.crown?.marks[state.crownSide(of: me)], 1, "Taken up: the watch is its side's")

        // Borne where it goes, a mark a watch.
        let step = try XCTUnwrap(state.map.neighbors(of: heart).first { state.map[$0]?.terrain == .ford })
        state.units[try XCTUnwrap(state.unitIndex(company.id))].position = step
        XCTAssertEqual(state.contestCrown(), [])
        XCTAssertEqual(state.crown?.hex, step)
        XCTAssertEqual(state.crown?.marks[state.crownSide(of: me)], 2)
        _ = state.contestCrown()
        XCTAssertEqual(state.crownLeader()?.marks, 3)
        XCTAssertEqual(state.crownLeader()?.side, -1 - me, "A House with no alliance is its own side")
        XCTAssertEqual(state.tidings(of: .crownTaken(unit: company.id, house: me), for: me)?.tone, .good)

        // Struck down, its bearer lets it fall where it stood.
        state.units.removeAll { $0.id == company.id }
        XCTAssertEqual(state.contestCrown(), [.crownFell(at: step)])
        XCTAssertNil(state.crown?.bearer)
        XCTAssertEqual(state.crown?.hex, step)

        // The water comes back: the side that bore it longest is given moonsalt.
        let salt = state.houses[me].stock.moonsalt
        state.ford = nil
        XCTAssertEqual(state.contestCrown(), [.crownSank(side: -1 - me, houses: [me])])
        XCTAssertNil(state.crown)
        XCTAssertEqual(state.houses[me].stock.moonsalt, salt + GameState.crownPrize.moonsalt)
        XCTAssertEqual(state.tidings(of: .crownSank(side: -1 - me, houses: [me]), for: me)?.tone, .good)
        XCTAssertEqual(state.problems(), [])
    }

    func testOnlyACompanyOfWarTakesItAndNoneBorneSinksUngiven() throws {
        var (state, heart) = try bare("the crown untaken")
        let lantern = Unit(id: state.takeID(), kind: .lantern, owner: state.player, position: heart, tier: 1)
        state.units.append(lantern)
        XCTAssertEqual(state.contestCrown(), [], "A Lantern does not take it up")
        XCTAssertNil(state.crown?.bearer)
        state.ford = nil
        XCTAssertEqual(state.contestCrown(), [.crownSank(side: nil, houses: [])])
        XCTAssertEqual(state.contestCrown(), [], "Gone until the next full moon")
    }

    func testEveryHouseSeesTheCrown() throws {
        var (state, heart) = try bare("the crown seen")
        let company = Unit(id: state.takeID(), kind: .bow, owner: state.player, position: heart, tier: 1)
        state.units.append(company)
        let event = state.contestCrown()[0]
        let other = try XCTUnwrap(state.houses.indices.first { $0 != state.player })
        XCTAssertEqual(state.view(for: other).crown?.bearer, company.id)
        XCTAssertNotNil(state.tidings(of: event, for: other))
        XCTAssertEqual(state.crownSideName(-1 - state.player), state.houses[state.player].name)
    }
}

extension DrownedCrownTests {
    /// Over whole ages the stewards go for it: some House bears it, and the
    /// lake gives the side that bore it longest.
    func testStewardsContendForTheCrownOverAnAge() {
        var state = GameState(settings: GameSettings(seedText: "contended crown", houseCount: 8, keepers: 1))
        var taken = 0, given = 0
        while state.watch < Sundering.first + GameState.fordLasts + 2 {
            // How the age ends is not this test's: it plays on to the
            // water's return whoever has prevailed.
            state.outcome = nil
            let turn = state.stewardTurn(for: state.player)
            for event in turn + state.endWatch() {
                if case .crownTaken = event { taken += 1 }
                if case .crownSank(let side, _) = event, side != nil { given += 1 }
            }
        }
        XCTAssertGreaterThan(taken, 0, "Some steward's company took up the crown")
        XCTAssertEqual(given, 1, "And the lake gave it as the water came back")
        XCTAssertEqual(state.problems(), [])
    }
}
