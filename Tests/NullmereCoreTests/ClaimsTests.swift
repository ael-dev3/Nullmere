import Foundation
import XCTest
@testable import NullmereCore

/// What the holds claim of the land is kept with the map's ground and
/// given again only to the same holds: whatever changed between, the kept
/// claims are the claims a realm with nothing kept makes afresh.
final class ClaimsTests: XCTestCase {
    /// The realm's territory with nothing kept: its copy through a save,
    /// whose map keeps nothing yet.
    private func fresh(_ state: GameState) throws -> [Int?] {
        try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)).territory()
    }

    func testKeptClaimsAreTheClaimsMadeAfresh() throws {
        var state = GameState(settings: GameSettings(seedText: "what the holds claim", houseCount: 4, radius: 16))
        let first = state.territory()
        XCTAssertEqual(state.territory(), first, "Asked again, the same")
        XCTAssertEqual(first, try fresh(state))

        // A beacon raised: the hold reaches further.
        let index = try XCTUnwrap(state.holds.indices.first)
        state.holds[index].levels[.beacon] = BuildingKind.beacon.maxLevel
        XCTAssertEqual(state.territory(), try fresh(state))
        XCTAssertNotEqual(state.territory(), first, "A beacon at its height claims more")

        // The ground changed under a claimed tile: it is claimed no more.
        let claimed = try XCTUnwrap(state.territory().indices.first { state.territory()[$0] != nil && state.map.hexes[$0] != state.holds[index].position })
        state.map.set(state.map.hexes[claimed], Tile(terrain: .still))
        XCTAssertNil(state.territory()[claimed], "Open water is no one's")
        XCTAssertEqual(state.territory(), try fresh(state))

        // Two copies of one map, their holds not the same, asking by turns.
        var other = state
        other.holds.removeLast()
        for _ in 0..<2 {
            XCTAssertEqual(state.territory(), try fresh(state))
            XCTAssertEqual(other.territory(), try fresh(other))
        }
        XCTAssertNotEqual(state.territory(), other.territory())

        // A copy whose ground changes keeps its own; the other's stands.
        var changed = state
        let before = state.territory()
        let tile = try XCTUnwrap(before.indices.first { before[$0] != nil && state.map.hexes[$0] != state.holds[index].position })
        changed.map.set(state.map.hexes[tile], Tile(terrain: .still))
        XCTAssertNil(changed.territory()[tile])
        XCTAssertEqual(state.territory(), before)
        XCTAssertEqual(changed.territory(), try fresh(changed))
    }

    /// The holds' token changes with all that decides what they claim, and
    /// with nothing else: the claims given by it are always those made
    /// afresh, however the holds change and their copies part ways.
    func testTheClaimsTokenFollowsAllThatDecidesTheClaims() throws {
        var state = GameState(settings: GameSettings(seedText: "the claims' token", houseCount: 4, radius: 16))
        _ = state.territory()
        let index = try XCTUnwrap(state.holds.indices.first)
        var token = state.holds.claims
        func changes(_ change: (inout GameState) -> Void, _ note: String, line: UInt = #line) throws {
            change(&state)
            XCTAssertNotEqual(state.holds.claims, token, note, line: line)
            token = state.holds.claims
            XCTAssertEqual(state.territory(), try fresh(state), note, line: line)
        }
        func keeps(_ change: (inout GameState) -> Void, _ note: String, line: UInt = #line) throws {
            change(&state)
            XCTAssertEqual(state.holds.claims, token, note, line: line)
            XCTAssertEqual(state.territory(), try fresh(state), note, line: line)
        }
        // What doesn't decide the claims leaves the token as it was.
        try keeps({ $0.holds[index].ward = max(0, $0.holds[index].ward - 1) }, "A hold struck")
        try keeps({ $0.holds[index].owner = ($0.holds[index].owner + 1) % $0.houses.count }, "A hold taken")
        try keeps({ $0.holds[index].levels[.granary] = 2 }, "A granary raised")
        try keeps({ $0.holds[index].levels[.beacon] = $0.holds[index].levels[.beacon] }, "Written over the same")
        // What does, draws a new one.
        try changes({ $0.holds[index].levels[.beacon] = BuildingKind.beacon.maxLevel }, "A beacon raised")
        try changes({ $0.holds[index].levels[.beacon] = nil }, "A beacon lost")
        try changes({ $0.holds[index].isSeat.toggle() }, "A seat raised anew")
        try changes({ state in
            let was = state.holds[index]
            var anew = Hold(id: was.id, name: was.name, owner: was.owner, position: was.position, isSeat: was.isSeat,
                            foundedWatch: was.foundedWatch + 1)
            anew.levels = was.levels
            state.holds[index] = anew
        }, "Written over as founded a watch later")
        try changes({ state in
            let free = state.map.hexes.first { hex in
                state.map[hex]?.terrain.isPassable == true && state.map[hex]?.terrain.isWater == false && state.hold(at: hex) == nil
                    && hex.distance(to: state.holds[index].position) > 6
            }
            state.holds[index].position = free ?? state.holds[index].position
        }, "A hold moved")
        try changes({ state in
            let at = state.map.hexes.first { hex in
                state.map[hex]?.terrain.isPassable == true && state.map[hex]?.terrain.isWater == false && state.hold(at: hex) == nil
                    && state.holds.allSatisfy { $0.position.distance(to: hex) > 4 }
            } ?? state.holds[index].position
            state.holds.append(Hold(id: state.takeID(), name: "Newstead", owner: state.holds[index].owner, position: at, isSeat: false,
                                    foundedWatch: state.watch))
        }, "A hold founded")
        try changes({ $0.holds.removeLast() }, "A hold lost")
        // Copies part ways: each draws its own, unlike the other's.
        var other = state
        XCTAssertEqual(other.holds.claims, state.holds.claims, "A copy, the same token")
        other.holds[index].levels[.beacon] = 2
        state.holds[index].levels[.beacon] = 1
        XCTAssertNotEqual(other.holds.claims, state.holds.claims)
        for _ in 0..<2 {
            XCTAssertEqual(state.territory(), try fresh(state))
            XCTAssertEqual(other.territory(), try fresh(other))
        }
        // Through a save, a token of its own.
        let saved = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertNotEqual(saved.holds.claims, state.holds.claims)
        XCTAssertEqual(saved.territory(), state.territory())
    }

    /// The deepest of a lake's water is sought once and kept with its map,
    /// the same as sought afresh; let go of as the ground changes, by the
    /// copy whose ground changed alone.
    func testTheDeepestWaterIsKeptWithTheMapWhileItsGroundStands() throws {
        var state = GameState(settings: GameSettings(seedText: "the deepest water", houseCount: 4, radius: 16))
        let deep = try XCTUnwrap(state.map.deepestWater())
        XCTAssertEqual(deep, state.map.seekDeepestWater())
        XCTAssertEqual(state.map.deepestWater(), deep, "Asked again, the same")
        XCTAssertEqual(state.moonWater, deep, "Where the moon lies on the water")
        // A copy fills the deepest tile in: its own deepest water moves; the
        // other's stands.
        var other = state
        other.map.set(deep.hex, Tile(terrain: .shallows))
        let moved = try XCTUnwrap(other.map.deepestWater())
        XCTAssertNotEqual(moved.hex, deep.hex)
        XCTAssertEqual(moved, other.map.seekDeepestWater())
        XCTAssertEqual(state.map.deepestWater(), deep)
        // All the water filled in: none at all, and so kept.
        for index in state.map.hexes.indices where state.map[index].terrain == .still {
            state.map.set(state.map.hexes[index], Tile(terrain: .strand))
        }
        XCTAssertNil(state.map.deepestWater())
        XCTAssertNil(state.map.deepestWater(), "None, asked again")
    }
}
