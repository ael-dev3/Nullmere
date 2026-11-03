import XCTest
@testable import NullmereCore

/// False reflections: a House teaches the lake to lie at its Still Hour.
final class FalseReflectionTests: XCTestCase {
    private func world() throws -> (GameState, me: Int, other: Int, hold: Hold, shore: Hex) {
        var state = GameState(settings: GameSettings(seedText: "false reflections", houseCount: 4, radius: 20, keepers: 1))
        let me = state.player, other = (me + 1) % 4
        let pair = try XCTUnwrap(state.holds.lazy.compactMap { hold -> (Hold, Hex)? in
            guard let hex = hold.position.spiral(GameState.falseReflectionReach).first(where: { state.isShore($0) && state.unit(at: $0) == nil && state.hold(at: $0) == nil }) else { return nil }
            return (hold, hex)
        }.first)
        state.holds[state.holdIndex(pair.0.id)!].owner = me
        state.houses[me].stock.credit(Stock(moonsalt: 60))
        return (state, me, other, try XCTUnwrap(state.hold(pair.0.id)), pair.1)
    }

    func testAFalseReflectionIsMirroredAtTheStillHourAsATrueOne() throws {
        var (state, me, other, hold, shore) = try world()
        XCTAssertEqual(state.refusal(of: .castReflection(hold: hold.id, at: shore, kind: .spear), as: other), .notYours)
        XCTAssertEqual(state.refusal(of: .castReflection(hold: hold.id, at: shore, kind: .founder), as: me), .cannotFight)
        let salt = state.houses[me].stock.moonsalt
        let events = try state.perform(.castReflection(hold: hold.id, at: shore, kind: .spear), as: me)
        XCTAssertEqual(events, [.reflectionCast(house: me, at: shore)])
        XCTAssertEqual(state.houses[me].stock.moonsalt, salt - GameState.falseReflectionCost.moonsalt)
        XCTAssertEqual(state.refusal(of: .castReflection(hold: hold.id, at: shore, kind: .spear), as: me), .reflectionThere)
        XCTAssertNotNil(state.tidings(of: events[0], for: me))
        XCTAssertEqual(state.events(events, heardBy: other), [], "Its secret")
        XCTAssertNil(state.view(for: other).reflections)
        XCTAssertEqual(state.view(for: me).falseReflections(of: me).count, 1)
        // At the Still Hour the lake mirrors it, a glimpse like any other.
        state.watch = GameState.nextStillHour(from: state.watch + 1)
        _ = state.layTheLakeStill()
        let mirrored = try XCTUnwrap(state.stillHour)
        let glimpse = try XCTUnwrap(mirrored.glimpses.first { $0.at == shore })
        XCTAssertEqual(glimpse.owner, me)
        XCTAssertEqual(glimpse.kind, .spear)
        XCTAssertGreaterThan(glimpse.troops, 0)
        XCTAssertNil(state.unit(at: shore), "Though none stands there")
        XCTAssertEqual(state.view(for: other).stillHour?.glimpses.contains(glimpse), true, "Every House sees it alike")
        XCTAssertTrue(state.falseReflections(of: me).isEmpty, "Spent")
        XCTAssertEqual(state.problems(), [])
    }

    func testThreeAStillHourAndNoneWhereACompanyStands() throws {
        var (state, me, _, hold, shore) = try world()
        let shores = hold.position.spiral(GameState.falseReflectionReach).filter { state.isShore($0) && state.unit(at: $0) == nil && state.hold(at: $0) == nil }
        guard shores.count >= 4 else { throw XCTSkip("Too little shore by this hold") }
        for hex in shores.prefix(3) { _ = try state.perform(.castReflection(hold: hold.id, at: hex, kind: .bow), as: me) }
        XCTAssertEqual(state.refusal(of: .castReflection(hold: hold.id, at: shores[3], kind: .bow), as: me), .tooManyReflections(3))
        XCTAssertEqual(RuleError.tooManyReflections(3).description, "The lake takes 3 false reflections of a House to a Still Hour, and no more.")
        // A company come to stand on a falsely mirrored shore: the lake shows the true one.
        state.units.append(Unit(id: state.takeID(), kind: .spear, owner: (me + 2) % 4, position: shore))
        state.watch = GameState.nextStillHour(from: state.watch + 1)
        _ = state.layTheLakeStill()
        let glimpses = try XCTUnwrap(state.stillHour).glimpses
        XCTAssertEqual(glimpses.filter { $0.at == shore }.count, 1)
        XCTAssertEqual(glimpses.first { $0.at == shore }?.owner, (me + 2) % 4)
    }
}
