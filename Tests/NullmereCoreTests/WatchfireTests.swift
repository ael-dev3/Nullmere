import Foundation
import XCTest
@testable import NullmereCore

/// Watchfires: a House lights one on open ground of its own land for
/// timber; it burns eight watches, lights the ground about it for its House
/// and those whose sight it shares, and makes out there a company marching
/// dark; every House sees it burn; a House keeps three at most; the realm
/// keeps them with the rest of it.
final class WatchfireTests: XCTestCase {
    /// A keeper's House with timber to spare, and the open ground of its own land.
    private func lighting(_ seed: String = "watchfires") throws -> (GameState, me: Int, ground: [Hex]) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        state.houses[me].stock.timber = 100
        let owners = state.territory()
        let ground = state.map.hexes.filter { hex in
            guard let terrain = state.map[hex]?.terrain else { return false }
            return terrain.isPassable && !terrain.isWater && state.hold(at: hex) == nil && state.territoryOwner(of: hex, in: owners) == me
        }
        XCTAssertGreaterThan(ground.count, Watchfire.most)
        return (state, me, ground)
    }

    func testAHouseLightsAWatchfireOnItsOwnLandForTimber() throws {
        var (state, me, ground) = try lighting()
        let at = ground[0]
        XCTAssertNil(state.watchfireRefusal(at: at, as: me))
        let timber = state.houses[me].stock.timber
        let events = try state.perform(.watchfire(at), as: me)
        XCTAssertEqual(events, [.watchfireLit(at: at, by: me)])
        XCTAssertEqual(state.houses[me].stock.timber, timber - Watchfire.cost.timber)
        XCTAssertEqual(state.watchfire(at: at), Watchfire(at: at, by: me, lit: state.watch, out: state.watch + Watchfire.burns))
        // Told to its House, and to every other: a watchfire is seen from afar.
        let other = (me + 1) % state.houses.count
        let told = try XCTUnwrap(state.tidings(of: events[0], for: me)).text
        XCTAssertTrue(told.hasPrefix("Your watchfire burns"), told)
        let seen = try XCTUnwrap(state.tidings(of: events[0], for: other)).text
        XCTAssertTrue(seen.contains("lights a watchfire"), seen)
        XCTAssertEqual(state.events(events, heardBy: other), events)
        XCTAssertEqual(state.view(for: other).watchfiresBurning, state.watchfiresBurning, "Every House sees it burn")
        XCTAssertEqual(RuleError.watchfireBurning.description, "A watchfire burns there already.")
    }

    func testOnlyOnOpenGroundOfItsOwnLandThreeAtMostAndPaidFor() throws {
        var (state, me, ground) = try lighting()
        let seat = try XCTUnwrap(state.seat(of: me)).position
        XCTAssertEqual(state.watchfireRefusal(at: seat, as: me), .unfitGround(try XCTUnwrap(state.map[seat]).terrain), "Not in a hold")
        let water = try XCTUnwrap(state.map.hexes.first { state.map[$0]?.terrain.isWater == true })
        XCTAssertEqual(state.watchfireRefusal(at: water, as: me), .unfitGround(try XCTUnwrap(state.map[water]).terrain))
        let owners = state.territory()
        let foreign = try XCTUnwrap(state.map.hexes.first { hex in
            guard let terrain = state.map[hex]?.terrain, terrain.isPassable, !terrain.isWater, state.hold(at: hex) == nil else { return false }
            return state.territoryOwner(of: hex, in: owners) != me
        })
        XCTAssertEqual(state.watchfireRefusal(at: foreign, as: me), .foreignTerritory)
        for at in ground.prefix(Watchfire.most) { _ = try state.perform(.watchfire(at), as: me) }
        XCTAssertEqual(state.watchfireRefusal(at: ground[0], as: me), .watchfireBurning)
        XCTAssertEqual(state.watchfireRefusal(at: ground[Watchfire.most], as: me), .watchfiresLit(Watchfire.most))
        XCTAssertEqual(RuleError.watchfiresLit(3).description, "Your House keeps 3 watchfires burning already, as many as it may.")
        // Short of timber, told what it lacks.
        var (poor, house, open) = try lighting()
        poor.houses[house].stock.timber = 5
        XCTAssertEqual(poor.watchfireRefusal(at: open[0], as: house), .shortOf(Stock(timber: 7)))
        XCTAssertThrowsError(try poor.perform(.watchfire(open[0]), as: house))
        XCTAssertNil(poor.watchfires)
    }

    func testItLightsTheGroundAboutItAndMakesOutTheDark() throws {
        var (state, me, ground) = try lighting()
        // The open ground of its land whose light would reach the most the
        // House doesn't see now.
        let seen = state.visibility(for: me)
        func unseen(about hex: Hex) -> Int {
            hex.spiral(Watchfire.reach).filter { state.map.index(of: $0).map { !seen[$0] } ?? false }.count
        }
        let at = try XCTUnwrap(ground.max { (unseen(about: $0), $1.q, $1.r) < (unseen(about: $1), $0.q, $0.r) })
        XCTAssertGreaterThan(unseen(about: at), 0, "Ground its light would reach that the House doesn't see")
        // A foe's company marching dark within its reach, on ground the
        // House can't make out the dark on.
        let foe = try XCTUnwrap(state.livingHouses.first { $0.id != me && !state.watchers(for: me).contains($0.id) }).id
        let close = state.closeSight(for: me)
        let spot = try XCTUnwrap(at.spiral(Watchfire.reach).first { hex in
            guard let index = state.map.index(of: hex), let terrain = state.map[hex]?.terrain else { return false }
            return !close[index] && terrain.isPassable && !terrain.isWater && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        }, "Ground within its reach the House can't make out the dark on")
        let company = try XCTUnwrap(state.placeUnit(.spear, tier: 1, for: foe, near: spot))
        state.units[try XCTUnwrap(state.unitIndex(company.id))].position = spot
        _ = try state.perform(.torches(unit: company.id, lit: false), as: foe)
        XCTAssertNil(state.view(for: me).unit(company.id), "Dark, unseen")
        _ = try state.perform(.watchfire(at), as: me)
        let lit = state.visibility(for: me)
        XCTAssertTrue(at.spiral(Watchfire.reach).allSatisfy { state.map.index(of: $0).map { lit[$0] } ?? true }, "All about it seen")
        XCTAssertTrue(state.closeSight(for: me)[try XCTUnwrap(state.map.index(of: spot))])
        XCTAssertNotNil(state.view(for: me).unit(company.id), "Made out in the watchfire's light")
        XCTAssertEqual(state.view(for: me).unlit, [company.id], "And seen to carry no torches")
        // Neither the foe nor any House else sees by another's watchfire.
        XCTAssertTrue(state.watchfiresLighting(for: foe).isEmpty)
        // A House in a pact with it sees by its light as its own House does.
        let friend = try XCTUnwrap(state.livingHouses.first { $0.id != me && $0.id != foe }).id
        XCTAssertTrue(state.watchfiresLighting(for: friend).isEmpty)
        state.setStance(.pact, between: me, and: friend, by: me)
        XCTAssertEqual(state.watchfiresLighting(for: friend).map(\.at), [at])
    }

    func testItBurnsOutAfterItsWatchesAndTheRealmKeepsIt() throws {
        var realm = RealmState(name: "The Nullmere", seed: "watchfires kept", seats: 6, radius: 18, watchLength: 600, now: 0)
        _ = try realm.arrive("id-ama", name: "Ama", now: 1)
        let me = try XCTUnwrap(realm.world.houses.first { $0.isPlayer }).id
        realm.world.houses[me].stock.timber = 100
        let owners = realm.world.territory()
        let at = try XCTUnwrap(realm.world.map.hexes.first { hex in
            guard let terrain = realm.world.map[hex]?.terrain else { return false }
            return terrain.isPassable && !terrain.isWater && realm.world.hold(at: hex) == nil
                && realm.world.territoryOwner(of: hex, in: owners) == me
        })
        _ = try realm.world.perform(.watchfire(at), as: me)
        let parts = try realm.parts(using: Scene.encoder)
        XCTAssertEqual(try RealmState(parts: parts), realm, "The realm keeps its watchfires")
        for _ in 1..<Watchfire.burns { _ = realm.world.endWatch() }
        XCTAssertNotNil(realm.world.watchfire(at: at), "Burning in its last watch")
        _ = realm.world.endWatch()
        XCTAssertNil(realm.world.watchfire(at: at), "Burnt out after \(Watchfire.burns) watches")
        XCTAssertNil(realm.world.watchfires)
    }
}
