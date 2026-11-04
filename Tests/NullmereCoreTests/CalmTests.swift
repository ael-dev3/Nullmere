import XCTest
@testable import NullmereCore

/// The Calm of the Still: a commons that grows each watch the water is
/// left alone, lies over keepers' holds on the shore as moonsalt, and is
/// broken for all by one company of war at the water's edge.
final class CalmTests: XCTestCase {
    /// A realm with no company of war anywhere, and a keeper's hold on the shore.
    private func quiet(_ seed: String) throws -> (GameState, Hold) {
        var state = Scene.world(seed, houses: 4)
        state.units.removeAll { $0.kind.isMilitary }
        let me = state.player
        let shore = try XCTUnwrap(state.map.hexes.first { state.isShore($0) && state.hold(at: $0) == nil && state.unit(at: $0) == nil })
        let hold = Hold(id: state.takeID(), name: "Calmwater", owner: me, position: shore, isSeat: false, foundedWatch: 0)
        state.holds.append(hold)
        return (state, hold)
    }

    func testTheCalmGrowsWhileTheWaterIsLeftAlone() throws {
        var (state, _) = try quiet("calm grows")
        XCTAssertEqual(state.stillCalm, 0)
        XCTAssertTrue(state.calmBreakers().isEmpty)
        for degree in 1...12 {
            XCTAssertTrue(state.turnCalm().isEmpty)
            XCTAssertEqual(state.stillCalm, min(degree, Calm.deepest))
        }
    }

    func testTheCalmLiesOverKeepersHoldsOnTheShoreAsMoonsalt() throws {
        var (state, hold) = try quiet("calm yields")
        let before = state.income(of: hold).moonsalt
        for _ in 0..<5 { _ = state.turnCalm() }
        let after = state.income(of: hold).moonsalt
        XCTAssertEqual(after - before, max(1, before) * Calm.moonsaltPerDegree * 5 / 100, "a tenth a degree")
        XCTAssertGreaterThan(after, before)
        // Not a steward's hold on the same shore, nor a keeper's inland.
        let steward = try XCTUnwrap(state.houses.firstIndex { !$0.isPlayer })
        var theirs = hold
        theirs.owner = steward
        XCTAssertEqual(state.calmMoonsalt(for: theirs, from: before), 0)
        let inland = try XCTUnwrap(state.holds.first { $0.owner == state.player && !state.isOnTheCalmShore($0) })
        XCTAssertEqual(state.calmMoonsalt(for: inland, from: 5), 0)
    }

    func testOneCompanyAtTheWaterBreaksItForAllAndADeepCalmNamesItsBreaker() throws {
        var (state, hold) = try quiet("calm broken")
        for _ in 0..<3 { _ = state.turnCalm() }
        let foe = (state.player + 1) % state.houses.count
        let edge = try XCTUnwrap(state.map.hexes.first { state.isShore($0) && state.hold(at: $0) == nil && state.unit(at: $0) == nil })
        state.units.append(NullmereCore.Unit(id: state.takeID(), kind: .spear, owner: foe, position: edge))
        XCTAssertEqual(state.calmBreakers(), [foe])
        XCTAssertTrue(state.turnCalm().isEmpty, "a shallow calm broken quietly")
        XCTAssertEqual(state.stillCalm, 0)
        // A deep calm broken is told, with whose companies broke it.
        state.units.removeAll { $0.owner == foe && $0.position == edge }
        for _ in 0..<7 { _ = state.turnCalm() }
        XCTAssertEqual(state.stillCalm, 7)
        state.units.append(NullmereCore.Unit(id: state.takeID(), kind: .rider, owner: foe, position: edge))
        let events = state.turnCalm()
        XCTAssertEqual(events, [.calmBroken(houses: [foe], calm: 7)])
        XCTAssertEqual(state.stillCalm, 0)
        XCTAssertEqual(state.calmMoonsalt(for: hold, from: 5), 0, "no calm, no more moonsalt")
        XCTAssertNotNil(state.tidings(of: events[0], for: state.player), "every House is told")
        XCTAssertNotNil(state.tidings(of: events[0], for: foe))
        XCTAssertFalse(state.events(events, heardBy: state.player).isEmpty)
        // A Lantern at the water troubles nothing.
        state.units.removeAll { $0.owner == foe && $0.position == edge }
        state.units.append(NullmereCore.Unit(id: state.takeID(), kind: .lantern, owner: foe, position: edge))
        XCTAssertTrue(state.calmBreakers().isEmpty)
    }

    func testTheCalmTurnsWithTheWatchAndIsSeenInEveryView() throws {
        var (state, _) = try quiet("calm watch")
        state.endWatch()
        let calm = state.stillCalm
        XCTAssertEqual(state.view(for: state.player).stillCalm, calm)
        let foe = (state.player + 1) % state.houses.count
        XCTAssertEqual(state.view(for: foe).stillCalm, calm, "no House's own")
        let round = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(round.stillCalm, calm)
    }
}
