import Foundation
import XCTest
@testable import NullmereCore

/// A scout's room keeps what stands where from one look to the next,
/// brought up to the realm as it stands: what it holds is always what a
/// room laid out afresh would hold, however the realm changed between and
/// whichever realm of its size it served last, and each look starts with no
/// tile reached.
final class ScoutRoomTests: XCTestCase {
    /// Each tile a company, the wilds or a lair stands on, marked afresh, as
    /// every look once marked them.
    private func freshlyOccupied(_ state: GameState) -> [Bool] {
        var occupied = [Bool](repeating: false, count: state.map.count)
        for unit in state.units { if let index = state.map.index(of: unit.position) { occupied[index] = true } }
        for wild in state.wildsStanding { if let index = state.map.index(of: wild.position) { occupied[index] = true } }
        for lair in state.lairsStanding { if let index = state.map.index(of: lair.position) { occupied[index] = true } }
        return occupied
    }

    private func played(_ seed: String) -> GameState {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 8, radius: RealmState.defaultRadius + 4))
        for _ in 0..<4 { _ = state.endWatch() }
        return state
    }

    func testAKeptRoomHoldsWhatAFreshOneWouldHoweverTheRealmChanges() throws {
        var realms = [played("a scout's room"), played("another scout's realm")]
        XCTAssertEqual(realms[0].map.count, realms[1].map.count, "Two realms of one size, to share the rooms")
        var random = SeededRandom(seed: 17)
        var nextID = realms.map { $0.units.map(\.id).max() ?? 0 }.max()! + 1_000
        func land(_ state: GameState) -> Hex {
            let land = state.map.hexes.indices.filter { state.map.steps[$0] != 0 }
            return state.map.hexes[land[random.int(below: land.count)]]
        }
        var occupiedSeen = 0
        for round in 0..<36 {
            // Now and then the other realm, then back.
            let which = round % 4 == 3 ? 1 : 0
            var state = realms[which]
            // Between looks: companies moved, one fallen, one raised, now and
            // then one put among the rest out of the order of their ids, and
            // a company of the wilds gone.
            for _ in 0..<1 + random.int(below: 4) {
                state.units[random.int(below: state.units.count)].position = land(state)
            }
            if round % 3 == 0, state.units.count > 10 { state.units.remove(at: random.int(below: state.units.count)) }
            if round % 4 == 1 {
                state.units.append(NullmereCore.Unit(id: nextID, kind: .lantern, owner: state.units[0].owner, position: land(state)))
                nextID += 1
            }
            if round % 11 == 5 {
                state.units.insert(NullmereCore.Unit(id: nextID, kind: .spear, owner: state.units[0].owner, position: land(state)), at: 0)
                nextID += 1
            }
            if round % 5 == 2, var wilds = state.wilds, !wilds.isEmpty {
                wilds.remove(at: random.int(below: wilds.count))
                state.wilds = wilds
            }
            var room = ScoutRoom.take(count: state.map.count)
            room.ready(in: state)
            let fresh = freshlyOccupied(state)
            XCTAssertEqual(room.occupied, fresh, "Round \(round): what stands where")
            occupiedSeen += fresh.filter { $0 }.count
            // A new look reaches no tile until it reaches it, whatever the
            // look before it reached.
            let tiles = (0..<8).map { _ in random.int(below: state.map.count) }
            XCTAssertFalse(tiles.contains { room.hasReached($0) }, "Round \(round): none reached yet")
            for tile in tiles { room.reach(tile) }
            XCTAssertTrue(tiles.allSatisfy { room.hasReached($0) })
            ScoutRoom.give(back: &room)
            realms[which] = state
        }
        XCTAssertGreaterThan(occupiedSeen, 36 * 20, "Companies, wilds and lairs stood about the lake")
    }

    /// When its looks' numbers come round again, after four thousand
    /// million of them, a look still starts with no tile reached.
    func testALookStartsWithNoTileReachedWhenItsNumbersComeRound() {
        let state = played("numbers come round")
        var room = ScoutRoom(count: state.map.count, look: .max - 1)
        room.ready(in: state)
        room.reach(7)
        XCTAssertTrue(room.hasReached(7))
        room.ready(in: state)
        XCTAssertFalse(room.hasReached(7), "The last number before they come round")
        room.reach(9)
        room.ready(in: state)
        XCTAssertFalse(room.hasReached(9) || room.hasReached(7), "Come round, every tile told afresh")
        XCTAssertEqual(room.occupied, freshlyOccupied(state))
    }

    /// A steward's scout still finds the edge of what its House knows: out
    /// toward it, never onto a tile something stands on.
    func testAScoutGoesOutTowardTheUnknown() throws {
        var state = GameState(settings: GameSettings(seedText: "a scout goes out", houseCount: 4))
        let me = state.player
        let scout = try XCTUnwrap(state.units.first { $0.owner == me && $0.kind == .lantern })
        let before = state.houses[me].explored.filter { $0 }.count
        for _ in 0..<6 {
            _ = state.stewardTurn(for: me)
            _ = state.endWatch()
        }
        XCTAssertGreaterThan(state.houses[me].explored.filter { $0 }.count, before, "More of the lake known")
        if let moved = state.unit(scout.id) {
            XCTAssertNotEqual(moved.position, scout.position, "Gone out from where it stood")
        }
    }
}
