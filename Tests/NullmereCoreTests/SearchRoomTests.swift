import Foundation
import XCTest
@testable import NullmereCore

/// A search's room keeps what stands in the way from one search to the
/// next, brought up to the realm as it stands: the way it finds is always
/// the way a room laid out afresh would find, however the realm changed
/// between, and whichever realm of its size it served last.
final class SearchRoomTests: XCTestCase {
    /// The way a search finds with what stands in the way marked afresh, as
    /// every search once did.
    private func freshWay(for unit: NullmereCore.Unit, to target: Hex, in state: GameState) -> [Hex]? {
        let map = state.map
        guard unit.position != target, let start = map.index(of: unit.position), let goal = map.index(of: target),
              map.steps[goal] != 0
        else { return nil }
        var blocked = [Bool](repeating: false, count: map.count)
        func mark(_ hex: Hex) {
            if let index = map.index(of: hex), index != goal { blocked[index] = true }
        }
        for other in state.units where other.id != unit.id { mark(other.position) }
        for hold in state.holds where hold.owner != unit.owner { mark(hold.position) }
        for wild in state.wildsStanding { mark(wild.position) }
        for lair in state.lairsStanding { mark(lair.position) }
        for hall in state.hallsStanding where !state.isOfHall(unit.owner, hall) { mark(hall.position) }
        for storehouse in state.storehousesStanding where !state.isOf(storehouse.alliance, unit.owner) { mark(storehouse.position) }
        var search = WaySearch(count: map.count)
        if let guide = map.guide(from: start, to: goal) {
            return search.way(on: map, from: start, to: goal, around: blocked, guide: guide)
        }
        return search.way(on: map, from: start, to: goal, around: blocked)
    }

    /// A lake wide enough for far marches to be guided, played a few watches
    /// so its companies have gone out from their holds.
    private func played(_ seed: String) -> GameState {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 8, radius: RealmState.defaultRadius + 4))
        for _ in 0..<4 { _ = state.endWatch() }
        return state
    }

    private func land(_ state: GameState, _ random: inout SeededRandom) -> Hex {
        let land = state.map.hexes.indices.filter { state.map.steps[$0] != 0 }
        return state.map.hexes[land[random.int(below: land.count)]]
    }

    func testAKeptRoomFindsTheWayAFreshOneWouldHoweverTheRealmChanges() {
        var realms = [played("a kept room"), played("another realm")]
        XCTAssertEqual(realms[0].map.count, realms[1].map.count, "Two realms of one size, to share the rooms")
        var random = SeededRandom(seed: 41)
        var nextID = realms.map { $0.units.map(\.id).max() ?? 0 }.max()! + 1_000
        var guided = 0, found = 0
        for round in 0..<48 {
            // Now and then the other realm, then back.
            let which = round % 4 == 3 ? 1 : 0
            var state = realms[which]
            // Between searches: companies moved, one fallen, one raised, now
            // and then one put among the rest out of the order of their ids,
            // and a hold taken by another House.
            for _ in 0..<1 + random.int(below: 4) {
                let index = random.int(below: state.units.count)
                state.units[index].position = land(state, &random)
            }
            if round % 3 == 0, state.units.count > 10 { state.units.remove(at: random.int(below: state.units.count)) }
            if round % 4 == 1 {
                let owner = state.units[random.int(below: state.units.count)].owner
                state.units.append(NullmereCore.Unit(id: nextID, kind: .spear, owner: owner, position: land(state, &random)))
                nextID += 1
            }
            if round % 11 == 5 {
                state.units.insert(NullmereCore.Unit(id: nextID, kind: .rider, owner: state.units[0].owner, position: land(state, &random)), at: 0)
                nextID += 1
            }
            if round % 7 == 6, state.holds.count > 1 {
                let index = random.int(below: state.holds.count)
                state.holds[index].owner = state.holds[(index + 1) % state.holds.count].owner
            }
            for _ in 0..<6 {
                let unit = state.units[random.int(below: state.units.count)]
                // Half the time a near goal, half the time anywhere on the lake.
                let near = Hex(unit.position.q + random.int(in: -5...5), unit.position.r + random.int(in: -5...5))
                let target = random.chance(50) ? near : land(state, &random)
                let way = state.path(for: unit, to: target)
                XCTAssertEqual(way, freshWay(for: unit, to: target, in: state), "Round \(round): company \(unit.id) to \(target)")
                if way != nil { found += 1 }
                if let start = state.map.index(of: unit.position), let goal = state.map.index(of: target),
                   state.map.guide(from: start, to: goal) != nil { guided += 1 }
            }
            realms[which] = state
        }
        XCTAssertGreaterThan(found, 100, "Ways found, not only refused")
        XCTAssertGreaterThan(guided, 20, "Far marches guided by the lie of the land among them")
    }
}
