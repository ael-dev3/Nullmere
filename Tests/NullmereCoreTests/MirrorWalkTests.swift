import XCTest
@testable import NullmereCore

/// Walking the Mirror: a company on the Still's shore comes out on the far
/// shore, reflected through the deep water, as the watch turns.
final class MirrorWalkTests: XCTestCase {
    /// A world with one of the keeper's companies of war on the Still's
    /// shore, and moonsalt to pay.
    private func staged() throws -> (GameState, Int, NullmereCore.Unit) {
        var state = Scene.world("mirror walk", houses: 4)
        let me = state.player
        let shore = try XCTUnwrap(state.map.hexes.first { hex in
            state.isOnTheStill(hex) && state.map[hex]!.terrain.isPassable && state.unit(at: hex) == nil
                && state.hold(at: hex) == nil && state.mirrorLanding(from: hex) != nil
        })
        let unit = NullmereCore.Unit(id: state.takeID(), kind: .spear, owner: me, position: shore)
        state.units.append(unit)
        state.houses[me].stock.credit(Stock(moonsalt: 40))
        return (state, me, unit)
    }

    func testTheStillReflectsThroughItsDeepestWater() throws {
        let state = Scene.world("mirror", houses: 4)
        let deep = try XCTUnwrap(state.map.deepestWater()).hex
        XCTAssertEqual(state.reflection(of: deep), deep)
        let near = Hex(deep.q + 3, deep.r - 1)
        XCTAssertEqual(state.reflection(of: near), Hex(deep.q - 3, deep.r + 1))
        XCTAssertEqual(near.distance(to: deep), try XCTUnwrap(state.reflection(of: near)).distance(to: deep))
    }

    func testACompanyWalksTheMirrorAndComesOutAsTheWatchTurns() throws {
        var (state, me, unit) = try staged()
        let landing = try XCTUnwrap(state.mirrorLanding(from: unit.position, for: unit.id))
        let salt = state.houses[me].stock.moonsalt
        let begun = try state.perform(.walkTheMirror(unit: unit.id), as: me)
        XCTAssertEqual(begun, [.mirrorWalkBegun(unit: unit.id, house: me, from: unit.position, to: landing)])
        XCTAssertEqual(state.houses[me].stock.moonsalt, salt - MirrorWalk.price.moonsalt)
        XCTAssertEqual(state.events(begun, heardBy: 1), begun, "The water stills for every shore")
        XCTAssertEqual(state.tidings(of: begun[0], for: 1)?.tone, .bad, "A warning to the others")
        XCTAssertEqual(state.refusal(of: .walkTheMirror(unit: unit.id), as: me), .mirrorWalkedThisMoon)
        let turned = state.endWatch()
        XCTAssertTrue(turned.contains(.mirrorWalked(unit: unit.id, house: me, from: unit.position, to: landing)), "\(turned)")
        XCTAssertEqual(state.unit(unit.id)?.position, landing)
        XCTAssertNil(state.mirrorWalks)
        let again = state.refusal(of: .walkTheMirror(unit: unit.id), as: me)
        XCTAssertEqual(again, state.isOnTheStill(landing) ? .mirrorWalkedThisMoon : .notOnTheStill, "Once a moon")
    }

    func testWhoMayWalkTheMirror() throws {
        var (state, me, unit) = try staged()
        XCTAssertEqual(state.refusal(of: .walkTheMirror(unit: unit.id), as: 1), .notYours)
        var poor = state
        poor.houses[me].stock = Stock()
        XCTAssertEqual(poor.refusal(of: .walkTheMirror(unit: unit.id), as: me), .shortOf(MirrorWalk.price))
        let inland = try XCTUnwrap(state.map.hexes.first { hex in
            !state.isOnTheStill(hex) && state.map[hex]!.terrain.isPassable && !state.map[hex]!.terrain.isWater && state.unit(at: hex) == nil
        })
        state.units[state.unitIndex(unit.id)!].position = inland
        XCTAssertEqual(state.refusal(of: .walkTheMirror(unit: unit.id), as: me), .notOnTheStill)
        let lantern = NullmereCore.Unit(id: state.takeID(), kind: .lantern, owner: me, position: unit.position)
        state.units.append(lantern)
        XCTAssertEqual(state.refusal(of: .walkTheMirror(unit: lantern.id), as: me), .notACompanyOfWar)
    }

    func testAFarShoreThatFillsSendsTheCompanyBack() throws {
        var (state, me, unit) = try staged()
        _ = try state.perform(.walkTheMirror(unit: unit.id), as: me)
        let to = state.mirrorWalks![0].to
        // The far shore heaved up into the Spine before the watch turns.
        for hex in to.spiral(MirrorWalk.reach) where state.map[hex] != nil && state.unit(at: hex) == nil && state.hold(at: hex) == nil {
            state.map.set(hex, Tile(terrain: .spine))
        }
        let turned = state.endWatch()
        XCTAssertTrue(turned.contains(.mirrorWalked(unit: unit.id, house: me, from: unit.position, to: unit.position)))
        XCTAssertEqual(state.unit(unit.id)?.position, unit.position)
    }
}
