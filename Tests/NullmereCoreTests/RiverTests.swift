import Foundation
import XCTest
@testable import NullmereCore

/// Streams from the Spine down to the lake, crossed at their shoals, and
/// the regions of the shores between them, named in the realm's atlas.
final class RiverTests: XCTestCase {
    private func world(_ seed: String = "rivers", seats: Int = 12, radius: Int = 24, lake: Lake = .round, rivers: Bool = true) -> GameState {
        GameState(settings: GameSettings(seedText: seed, houseCount: seats, radius: radius, lake: lake, rivers: rivers))
    }

    /// Tiles reachable on foot from `start`.
    private func reachable(_ map: WorldMap, from start: Hex) -> Set<Hex> {
        var seen: Set<Hex> = [start]
        var queue = [start]
        while let hex = queue.popLast() {
            for next in map.neighbors(of: hex) where !seen.contains(next) && map[next]?.terrain.isPassable == true {
                seen.insert(next)
                queue.append(next)
            }
        }
        return seen
    }

    /// A world without streams is made exactly as it always was; one with
    /// them is the same land, seats and Houses, the streams laid over it.
    func testAWorldWithoutStreamsIsMadeAsItAlwaysWas() throws {
        let plain = GameState(settings: GameSettings(seedText: "rivers", houseCount: 12, radius: 24))
        XCTAssertEqual(plain.map, world(rivers: false).map)
        XCTAssertNil(plain.atlas)
        let settings = try JSONEncoder().encode(plain.settings)
        let keys = try XCTUnwrap(JSONSerialization.jsonObject(with: settings) as? [String: Any]).keys
        XCTAssertEqual(Set(keys), ["seedText", "houseCount", "radius", "playerHouse", "keepers", "lake"], "Kept as it always was")
        XCTAssertFalse(try JSONDecoder().decode(GameSettings.self, from: settings).rivers)

        let streams = world()
        XCTAssertTrue(streams.settings.rivers)
        XCTAssertEqual(try JSONDecoder().decode(GameSettings.self, from: JSONEncoder().encode(streams.settings)), streams.settings)
        XCTAssertEqual(streams.holds.map(\.position), plain.holds.map(\.position), "The same seats")
        XCTAssertEqual(streams.houses.map(\.name), plain.houses.map(\.name), "The same Houses")
        for index in 0..<plain.map.count where plain.map[index] != streams.map[index] {
            XCTAssertTrue([.stream, .shoal].contains(streams.map[index].terrain), "Only the streams differ")
        }
    }

    /// Each stream rises under the Spine and runs step by step to the
    /// lake, clear of every seat's country and of every feature, crossed
    /// at a shoal every few steps; no land a company could walk to before
    /// is shut off.
    func testStreamsRunFromTheSpineToTheLakeCrossedAtShoals() throws {
        for lake in Lake.allCases {
            let plain = world("streams \(lake)", lake: lake, rivers: false)
            let state = world("streams \(lake)", lake: lake)
            let atlas = try XCTUnwrap(state.atlas)
            XCTAssertGreaterThanOrEqual(atlas.rivers.count, 3, "\(lake)")
            XCTAssertLessThanOrEqual(atlas.rivers.count, WorldGenerator.streamCount(seats: 12))
            XCTAssertEqual(Set(atlas.rivers.map(\.name)).count, atlas.rivers.count, "Each its own name")
            for river in atlas.rivers {
                let course = river.course
                let spring = try XCTUnwrap(course.first), mouth = try XCTUnwrap(course.last)
                XCTAssertTrue(state.map.neighbors(of: spring).contains { state.map[$0]?.terrain == .spine }, "\(river.name) rises under the Spine")
                XCTAssertTrue(state.map.neighbors(of: mouth).contains { [.still, .shallows].contains(state.map[$0]?.terrain) },
                              "\(river.name) runs into the lake")
                for (a, b) in zip(course, course.dropFirst()) { XCTAssertEqual(a.distance(to: b), 1, "Step by step") }
                XCTAssertTrue(course.allSatisfy { [.stream, .shoal].contains(state.map[$0]?.terrain) })
                XCTAssertTrue(course.contains { state.map[$0]?.terrain == .shoal }, "\(river.name) is crossed somewhere")
                XCTAssertTrue(course.allSatisfy { hex in state.holds.allSatisfy { $0.position.distance(to: hex) > 2 } }, "Clear of every seat")
                XCTAssertTrue(course.allSatisfy { plain.map[$0]?.feature == nil && plain.map[$0]?.terrain.isSettleable == true },
                              "Over open land")
                XCTAssertEqual(atlas.river(at: course[course.count / 2]), river)
            }
            let before = reachable(plain.map, from: plain.holds[0].position)
            let after = reachable(state.map, from: state.holds[0].position)
            let streams = Set(atlas.rivers.flatMap(\.course))
            XCTAssertTrue(before.subtracting(streams).isSubset(of: after), "\(lake): nothing shut off")
            XCTAssertTrue(state.holds.allSatisfy { after.contains($0.position) }, "Every seat reaches every other")
        }
        XCTAssertNil(world().atlas?.river(at: .origin))
    }

    /// A stream can't be waded; its shoal can, slowly, and is a poor place
    /// to fight. Neither is raised on, worked or gathered.
    func testAStreamIsCrossedOnlyAtItsShoals() {
        XCTAssertFalse(Terrain.stream.isPassable)
        XCTAssertTrue(Terrain.shoal.isPassable)
        XCTAssertEqual(Terrain.shoal.moveCost, 2)
        XCTAssertEqual(Terrain.shoal.defenseBonus, -25)
        for terrain in [Terrain.stream, .shoal] {
            XCTAssertTrue(terrain.isWater)
            XCTAssertFalse(terrain.isSettleable)
            XCTAssertEqual(terrain.yield, .zero)
            XCTAssertNil(Site.store(of: terrain))
            XCTAssertEqual(WildKind.of(terrain), .drowned)
        }
        XCTAssertEqual(Terrain.stream.title, "Stream")
        XCTAssertEqual(Terrain.shoal.title, "Shoal")

        // A march to the far bank finds its way over a shoal.
        let state = world()
        let river = state.atlas!.rivers[0]
        let shoal = river.course.first { state.map[$0]?.terrain == .shoal }!
        let banks = state.map.neighbors(of: shoal).filter { state.map[$0]?.terrain.isSettleable == true }
        XCTAssertGreaterThanOrEqual(banks.count, 2)
        let territory = state.territory()
        for hex in river.course { XCTAssertNil(territory[state.map.index(of: hex)!], "No hold claims a stream") }
    }

    /// Between each stream and the next lies a region of the shores, named
    /// in the atlas; every keeper's view works out the same regions from
    /// the atlas alone, and the two banks of a stream lie in two of them.
    func testTheShoresAreDividedIntoNamedRegions() throws {
        let state = world()
        let atlas = try XCTUnwrap(state.atlas)
        XCTAssertEqual(atlas.regions.count, atlas.rivers.count)
        XCTAssertEqual(Set(atlas.regions.map(\.name)).count, atlas.regions.count, "Each its own name")
        let owners = atlas.regionIndices(over: state.map)
        for (number, region) in atlas.regions.enumerated() {
            XCTAssertEqual(owners[state.map.index(of: region.heart)!], number, "\(region.name)'s heart lies in it")
            XCTAssertEqual(state.region(of: region.heart), region)
            XCTAssertTrue(state.map[region.heart]?.terrain.isSettleable == true)
        }
        let land = state.map.hexes.filter { state.map[$0]?.terrain.isSettleable == true }
        let named = land.filter { owners[state.map.index(of: $0)!] != nil }
        XCTAssertGreaterThan(Double(named.count) / Double(land.count), 0.95, "Nearly all the land lies in a region")
        for river in atlas.rivers {
            let banks = Set(river.course.flatMap { state.map.neighbors(of: $0) }
                .filter { state.map[$0]?.terrain.isSettleable == true }
                .compactMap { owners[state.map.index(of: $0)!] })
            XCTAssertEqual(banks.count, 2, "\(river.name) runs between two regions")
        }
        for river in atlas.rivers { XCTAssertNil(owners[state.map.index(of: river.course[0])!], "A stream lies in none") }

        // A keeper's view, with the land unexplored and no seed, holds the
        // same atlas and finds the same regions.
        let view = state.view(for: 3)
        XCTAssertEqual(view.atlas, atlas)
        XCTAssertEqual(atlas.regionIndices(over: view.map), owners)
        XCTAssertEqual(view.region(of: atlas.regions[1].heart)?.name, atlas.regions[1].name)
        XCTAssertNil(world(rivers: false).region(of: .origin), "No regions without streams")
        XCTAssertNil(state.region(of: Hex(400, 0)), "Off the map")
    }

    /// The atlas keeps the crests the lake gave each House, so a keeper's
    /// view, which has no seed, shows the realm's own; each realm's are its
    /// own.
    func testTheAtlasKeepsTheLakesCrestsForEveryView() throws {
        let state = world()
        let view = state.view(for: 2)
        XCTAssertEqual(view.settings.seedText, "", "A view keeps no seed")
        for house in state.houses.indices {
            XCTAssertEqual(view.crest(of: house), Crest.given(to: house, seedText: "rivers"))
            XCTAssertEqual(view.crest(of: house), state.crest(of: house))
        }
        XCTAssertNotEqual(world("another").atlas?.crests, state.atlas?.crests)
    }

    /// The atlas goes in a part of its own, the same all age long: a view
    /// shares the world's, and the head written at every pace leaves it out.
    func testTheAtlasTravelsInAPartOfItsOwn() throws {
        var realm = RealmState(name: "The Nullmere", seed: "atlas", now: 0)
        XCTAssertTrue(realm.world.settings.rivers, "A realm's worlds run streams")
        let atlas = try XCTUnwrap(realm.world.atlas)
        XCTAssertFalse(atlas.rivers.isEmpty)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let parts = try realm.parts(using: encoder)
        XCTAssertNotNil(parts["atlas"])
        XCTAssertFalse(try XCTUnwrap(parts["head"]).contains(atlas.rivers[0].name), "Not in the head")
        XCTAssertEqual(try RealmState(parts: parts).world.atlas, atlas)

        _ = try realm.arrive("k1", name: "Ama", now: 1)
        let view = try XCTUnwrap(realm.view(for: "k1"))
        let viewParts = try view.parts(using: encoder, sharing: (realm.world, parts))
        XCTAssertEqual(viewParts["atlas"], parts["atlas"], "Shared as written")
        XCTAssertEqual(try RealmView(parts: viewParts).world.atlas, atlas)

        // A realm kept from before the atlas is given one with its crests,
        // and its streams come with its next age.
        var old = realm
        old.world.atlas = nil
        old.fillIn()
        XCTAssertEqual(old.world.atlas?.crests, atlas.crests)
        XCTAssertEqual(old.world.atlas?.rivers, [])
        let oldParts = try old.parts(using: encoder)
        XCTAssertEqual(try RealmState(parts: oldParts).world.atlas, old.world.atlas)
        var bare = old
        bare.world.atlas = nil
        XCTAssertNil(try RealmState(parts: bare.parts(using: encoder)).world.atlas, "None kept, none read")
    }

    /// A wide realm runs a stream for every two seats, twelve at the most.
    func testAWideRealmRunsTwelveStreams() throws {
        XCTAssertEqual(WorldGenerator.streamCount(seats: 2), 2)
        XCTAssertEqual(WorldGenerator.streamCount(seats: 5), 3)
        XCTAssertEqual(WorldGenerator.streamCount(seats: 12), 6)
        XCTAssertEqual(WorldGenerator.streamCount(seats: 48), 12)
        let started = Date()
        let wide = world("wide streams", seats: 48, radius: RealmState.radius(forSeats: 48))
        print("PERF a realm of 48 seats with its streams made in \(String(format: "%.0f", Date().timeIntervalSince(started) * 1000)) ms")
        XCTAssertEqual(try XCTUnwrap(wide.atlas).rivers.count, 12)
        let two = world("two seats", seats: 2, radius: 14)
        XCTAssertLessThanOrEqual(try XCTUnwrap(two.atlas).rivers.count, 2)
    }
}
