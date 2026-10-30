import Foundation
import XCTest
@testable import NullmereCore

/// Marches as a keeper knows them: where their own companies are bound and
/// the watch they should be there; the way another House's company in
/// sight goes, as far as it is seen, and never where it is bound; a host's
/// march on its hold, to its side and to the House it marches on.
final class MarchTests: XCTestCase {
    /// The world's part of a watch, without the stewards.
    private func turn(_ state: inout GameState) {
        for index in state.units.indices {
            state.units[index].movesLeft = state.movement(of: state.units[index])
        }
        state.watch += 1
        for unit in state.units.sorted(by: { $0.id < $1.id }) where unit.destination != nil {
            _ = state.march(unit.id)
        }
        _ = state.advanceRallies()
    }

    func testAMarchTakesTheWatchesItsGroundAsks() {
        var state = Scene.world("walking")
        let hexes = Array(state.map.hexes.prefix(6))
        func route(_ terrains: [Terrain]) -> [Hex] {
            for (hex, terrain) in zip(hexes, terrains) { state.map.set(hex, Tile(terrain: terrain)) }
            return Array(hexes.prefix(terrains.count))
        }
        func walked(_ terrains: [Terrain], pace: Int) -> Int {
            let way = route(terrains)
            return state.watchesToWalk(way, pace: pace)
        }
        XCTAssertEqual(state.watchesToWalk([], pace: 2), 0)
        XCTAssertEqual(walked([.greyfield, .greyfield, .greyfield, .greyfield], pace: 2), 2)
        XCTAssertEqual(walked([.greyfield, .greyfield, .greyfield, .greyfield, .greyfield], pace: 2), 3)
        XCTAssertEqual(walked([.greyfield, .blackwood, .greyfield], pace: 2), 3, "A step it can't pay for waits for the next watch")
        XCTAssertEqual(walked([.blackwood, .barrow], pace: 1), 2, "With all its moves, any one step")
        XCTAssertEqual(walked([.strand, .saltFlat, .shallows], pace: 4), 1)
        XCTAssertEqual(walked([.strand, .saltFlat, .shallows, .greyfield], pace: 4), 2)
    }

    func testAKeeperKnowsWhereTheirCompaniesAreBoundAndWhen() throws {
        var state = Scene.world("bound for", houses: 3, radius: 16)
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me)).position
        state.reveal(around: seat, range: 9, for: me)
        let spear = try XCTUnwrap(state.units(of: me).first { $0.kind == .spear })
        let destination = try XCTUnwrap(state.map.hexes.first { hex in
            hex.distance(to: spear.position) == 7 && state.map[hex]?.terrain == .greyfield && state.isClear(hex)
                && state.wild(at: hex) == nil && state.path(for: spear, to: hex) != nil
        })
        _ = try state.perform(.move(unit: spear.id, to: destination), as: me)
        let march = try XCTUnwrap(state.marches(seenBy: me).first { $0.unit == spear.id })
        let standing = try XCTUnwrap(state.unit(spear.id))
        XCTAssertEqual(march.owner, me)
        XCTAssertEqual(march.destination, destination)
        XCTAssertEqual(march.route.last, destination)
        XCTAssertEqual(march.route.first?.distance(to: standing.position), 1)
        let arrives = try XCTUnwrap(march.arrives)
        XCTAssertGreaterThan(arrives, state.watch)
        while state.unit(spear.id)?.position != destination, state.watch < arrives + 3 {
            turn(&state)
            if state.unit(spear.id)?.position != destination {
                XCTAssertEqual(state.marches(seenBy: me).first { $0.unit == spear.id }?.arrives, arrives, "The same watch, as it goes")
            }
        }
        XCTAssertEqual(state.watch, arrives, "There in the watch foretold")
        XCTAssertNil(state.marches(seenBy: me).first { $0.unit == spear.id }, "A march done is no march")
    }

    func testAnotherHousesMarchIsSeenOnlyAsFarAsItGoesInSight() throws {
        var state = Scene.world("seen going", houses: 3, radius: 16)
        let me = state.player
        let mine = try XCTUnwrap(state.units(of: me).first { $0.kind == .spear })
        let near = try XCTUnwrap(state.freeHex(near: mine.position, within: 2...2))
        let theirs = state.put(.rider, of: 1, at: near)
        let seen = state.visibility(for: me)
        // Bound far off, by a way that sets out in sight.
        let rider = try XCTUnwrap(state.unit(theirs))
        let far = try XCTUnwrap(state.map.hexes.first { hex in
            guard hex.distance(to: near) >= 8, state.map[hex]?.terrain.isPassable == true, state.isClear(hex),
                  let first = state.path(for: rider, to: hex)?.first else { return false }
            return seen[state.map.index(of: first)!]
        })
        state.units[try XCTUnwrap(state.unitIndex(theirs))].destination = far
        let march = try XCTUnwrap(state.marches(seenBy: me).first { $0.unit == theirs })
        XCTAssertEqual(march.owner, 1)
        XCTAssertNil(march.destination, "Not where it is bound")
        XCTAssertNil(march.arrives)
        XCTAssertFalse(march.route.isEmpty)
        XCTAssertTrue(march.route.allSatisfy { seen[state.map.index(of: $0)!] }, "Only the way it goes in sight")
        XCTAssertNotEqual(march.route.last, far)
        XCTAssertNil(state.view(for: me).unit(theirs)?.destination, "A company in sight, not its orders")

        // Out of sight, no march at all.
        let hidden = try XCTUnwrap(state.map.hexes.first { hex in
            !seen[state.map.index(of: hex)!] && hex.distance(to: mine.position) >= 8 && state.map[hex]?.terrain.isPassable == true
                && state.isClear(hex) && state.wild(at: hex) == nil
        })
        let unseen = state.put(.spear, of: 2, at: hidden)
        state.units[try XCTUnwrap(state.unitIndex(unseen))].destination = mine.position
        XCTAssertNil(state.marches(seenBy: me).first { $0.unit == unseen })
        XCTAssertNotNil(state.marches(seenBy: 2).first { $0.unit == unseen && $0.destination == mine.position })
    }

    func testAHostsMarchIsKnownToItsSideAndToTheHouseItMarchesOn() throws {
        var state = Scene.world("host's march", houses: 4, radius: 18)
        let me = state.player
        state.houses[1].temperament = .steadfast
        _ = try state.perform(.foundAlliance(name: "Marchward"), as: me)
        _ = try state.perform(.inviteToAlliance(house: 1), as: me)
        _ = try state.declareWar(by: me, on: 2)
        let seat = try XCTUnwrap(state.seat(of: me))
        state.holds[try XCTUnwrap(state.holdIndex(seat.id))].levels[.musterHall] = 1
        let target = try XCTUnwrap(state.seat(of: 2))
        state.reveal(around: target.position, range: 0, for: me)
        _ = try state.perform(.callRally(from: seat.id, against: target.id, watches: 1), as: me)
        let rally = try XCTUnwrap(state.ralliesStanding.first)
        let spot = try XCTUnwrap(state.freeHex(near: seat.position, within: 1...1))
        let spear = state.put(.spear, of: me, at: spot)
        _ = try state.perform(.joinRally(rally: rally.id, unit: spear), as: me)
        turn(&state)
        XCTAssertTrue(try XCTUnwrap(state.rally(rally.id)).marching)
        let ours = try XCTUnwrap(state.marches(seenBy: me).first { $0.unit == spear })
        XCTAssertEqual(ours.destination, target.position)
        XCTAssertEqual(ours.route.last.map { $0.distance(to: target.position) }, 1, "To the hold's gates")
        XCTAssertEqual(ours.arrives, state.watch + state.view(for: me).watchesToWalk(ours.route, pace: 2), "Over the ground as its side knows it")
        XCTAssertEqual(state.marches(seenBy: 1).first { $0.unit == spear }?.destination, target.position, "Its side knows")

        // The House it marches on, once the host is in its sight, knows
        // where it goes; a House apart, seeing it, only the way.
        let watcherSpot = try XCTUnwrap(state.freeHex(near: try XCTUnwrap(state.unit(spear)).position, within: 2...2))
        state.put(.lantern, of: 2, at: watcherSpot)
        XCTAssertEqual(state.marches(seenBy: 2).first { $0.unit == spear }?.destination, target.position)
        state.put(.lantern, of: 3, at: try XCTUnwrap(state.freeHex(near: watcherSpot, within: 1...2)))
        XCTAssertNil(state.marches(seenBy: 3).first { $0.unit == spear }, "A host's company has no orders of its own to show")
    }

    func testTheRealmTellsAKeeperTheirMarches() throws {
        var realm = RealmState(name: "R", seed: "realm marches", seats: 4, radius: 18, watchLength: 60, now: 0)
        let keeper = try realm.arrive("id-marcher", name: "Marcher", now: 1)
        let house = try XCTUnwrap(keeper.house)
        let spear = try XCTUnwrap(realm.world.units(of: house).first { $0.kind == .spear })
        let destination = try XCTUnwrap(realm.world.map.hexes.first { hex in
            hex.distance(to: spear.position) == 6 && realm.world.map[hex]?.terrain.isPassable == true && realm.world.isClear(hex)
                && realm.world.wild(at: hex) == nil && realm.world.path(for: spear, to: hex) != nil
        })
        _ = try realm.perform(.move(unit: spear.id, to: destination), by: "id-marcher")
        let view = try XCTUnwrap(realm.view(for: "id-marcher"))
        let march = try XCTUnwrap(view.world.marches?.first { $0.unit == spear.id })
        XCTAssertEqual(march.destination, destination)
        XCTAssertNil(realm.world.marches, "The world itself keeps none")
        let older = try JSONDecoder().decode(RealmView.self, from: Scene.without(["marches"], in: view))
        XCTAssertNil(older.world.marches)
        XCTAssertEqual(try JSONDecoder().decode(RealmView.self, from: JSONEncoder().encode(view)), view)
    }
}
