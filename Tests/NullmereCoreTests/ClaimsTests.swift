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

    /// Where a few holds differ from those that last asked, what was kept is
    /// amended about them, not made afresh for the whole map: tile by tile
    /// the claims made afresh, whether holds are founded (before their
    /// neighbours as well as after), grown, lost or moved, one at a time or
    /// several at once, or stand on the Spine.
    func testClaimsAreAmendedWhereAFewHoldsDiffer() throws {
        var state = GameState(settings: GameSettings(seedText: "claims amended", houseCount: 4, radius: 16))
        func land(_ hex: Hex) -> Bool {
            state.map[hex].map { Claims.claimable($0.terrain, tile: 0, home: nil) } == true && state.hold(at: hex) == nil
        }
        func reached(_ hex: Hex) -> Bool { state.holds.contains { $0.position.distance(to: hex) <= $0.territoryRadius } }
        // Two places for holds three from a seat and two apart, with land
        // between them that no hold reaches yet.
        var room: (seat: Int, a: Hex, b: Hex, between: Hex)?
        search: for seat in state.holds.indices {
            let home = state.holds[seat].position
            for a in home.spiral(3) where a.distance(to: home) == 3 && land(a) {
                for b in a.spiral(2) where b.distance(to: a) == 2 && land(b) && state.holds.allSatisfy({ $0.position.distance(to: b) >= 4 }) {
                    if let between = a.spiral(1).first(where: { $0.distance(to: b) == 1 && $0 != a && land($0) && !reached($0) }) {
                        room = (seat, a, b, between)
                        break search
                    }
                }
            }
        }
        let place = try XCTUnwrap(room, "Room for two holds by a seat")
        let between = try XCTUnwrap(state.map.index(of: place.between))
        // Ground of the Spine where the second hold will later stand.
        let spine = try XCTUnwrap(state.map.hexes.first { land($0) && !reached($0) && $0.distance(to: place.a) > 6 && $0.distance(to: place.b) > 6 })
        state.map.set(spine, Tile(terrain: .spine))
        _ = state.territory()

        /// Amends what was kept to the holds now, and finds it the claims
        /// made afresh.
        func amended(_ note: String, line: UInt = #line) throws -> [Int?] {
            let owners = try XCTUnwrap(state.map.claims.amend(to: state.claimants, token: state.holds.claims, on: state.map),
                                       "\(note): amended", line: line)
            XCTAssertEqual(owners, try fresh(state), note, line: line)
            XCTAssertEqual(state.territory(), owners, "\(note): kept under the holds' token", line: line)
            return owners
        }
        func found(at hex: Hex, in watch: Int) -> Int {
            let id = state.takeID()
            state.holds.append(Hold(id: id, name: "Hold \(id)", owner: state.holds[place.seat].owner, position: hex, isSeat: false, foundedWatch: watch))
            return id
        }

        // A hold founded late beside the seat: the seat keeps what both reach.
        let late = found(at: place.a, in: 5)
        var owners = try amended("Founded after its neighbours")
        XCTAssertEqual(owners[between], late)
        // One founded before it: it takes what both reach from the later.
        let early = found(at: place.b, in: 1)
        owners = try amended("Founded before its neighbour")
        XCTAssertEqual(owners[between], early, "The older hold keeps a tile when two reach it")
        // Grown: its beacon reaches further.
        let earlyIndex = try XCTUnwrap(state.holds.index(ofID: early))
        state.holds[earlyIndex].levels[.beacon] = 2
        _ = try amended("A beacon raised")
        // Lost: what it held goes to the next that reaches it, or to none.
        state.holds.remove(at: earlyIndex)
        owners = try amended("A hold lost")
        XCTAssertEqual(owners[between], late, "The later hold has it now")
        // Several at once: one moved onto the Spine, another founded, the
        // beacon raised of the seat farthest from where they stood.
        let lateIndex = try XCTUnwrap(state.holds.index(ofID: late))
        state.holds[lateIndex].position = spine
        let third = found(at: place.b, in: 0)
        let farthest = try XCTUnwrap(state.holds.indices.filter { state.holds[$0].isSeat }
            .max { state.holds[$0].position.distance(to: place.between) < state.holds[$1].position.distance(to: place.between) })
        state.holds[farthest].levels[.beacon] = 2
        owners = try amended("Moved, founded and grown in one")
        let onSpine = try XCTUnwrap(state.map.index(of: spine))
        XCTAssertEqual(owners[onSpine], late, "A hold claims the Spine it stands on")
        XCTAssertEqual(owners[between], third)
        // Lost from the Spine: none other may claim it.
        state.holds.remove(at: lateIndex)
        owners = try amended("Lost from the Spine")
        XCTAssertNil(owners[onSpine], "The Spine is no one's but the hold's that stands on it")
    }

    /// Nothing to amend from, too many holds changed, a map of another
    /// size, or a holder that is none of the holds: made afresh instead.
    func testClaimsAreMadeAfreshWhereTheyCannotBeAmended() throws {
        let state = GameState(settings: GameSettings(seedText: "claims made afresh", houseCount: 4, radius: 16))
        let claims = Claims()
        let claimants = state.claimants
        XCTAssertNil(claims.amend(to: claimants, token: 1, on: state.map), "Nothing kept")
        let many = (0..<(Claims.mostAmended + 1)).map { Claims.Claimant(id: 1_000 + $0, position: Hex(0, 0), founded: 0, reach: 1) }
        claims.keep(Array(repeating: nil, count: state.map.count), for: [], token: 1)
        XCTAssertNil(claims.amend(to: many, token: 2, on: state.map), "Too many changed")
        claims.keep([nil], for: [], token: 1)
        XCTAssertNil(claims.amend(to: Array(claimants.prefix(1)), token: 2, on: state.map), "Kept for another map")
        let first = try XCTUnwrap(claimants.first)
        var owners = [Int?](repeating: nil, count: state.map.count)
        owners[try XCTUnwrap(state.map.index(of: first.position))] = 999
        claims.keep(owners, for: [], token: 1)
        XCTAssertNil(claims.amend(to: [first], token: 2, on: state.map), "A holder none of the holds")
        XCTAssertNil(claims.owners(forToken: 2), "Nothing kept of it")
        XCTAssertEqual(Claims.founded(of: first.id, in: claimants), first.founded)
        XCTAssertEqual(Claims.founded(of: first.id, in: Array(claimants.reversed())), first.founded, "Found out of order")
        XCTAssertNil(Claims.founded(of: 999, in: claimants))
    }

    /// Through a played age, its holds founded, grown, taken and lost by
    /// the stewards in the midst of their watches, what the holds claim is
    /// always the claims made afresh.
    func testThroughAPlayedAgeTheClaimsAreAlwaysThoseMadeAfresh() throws {
        var state = GameState(settings: GameSettings(seedText: "claims through an age", houseCount: 6, radius: 20))
        let holds = state.holds.count
        for watch in 1...30 {
            state.endWatch()
            XCTAssertEqual(state.territory(), try fresh(state), "Watch \(watch)")
        }
        XCTAssertGreaterThan(state.holds.count, holds, "Holds founded through the age")
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
