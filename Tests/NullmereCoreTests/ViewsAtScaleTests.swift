import Foundation
import XCTest
@testable import NullmereCore

/// A keeper's view costs what is theirs alone: the map fogged from what
/// their House has explored, what every view takes alike worked out once,
/// and each page of the map and the long lists just as every keeper is told
/// it taken as written once. Whatever is taken, the view and its parts are
/// exactly those worked out afresh.
final class ViewsAtScaleTests: XCTestCase {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    /// A realm of twelve seats a few watches in, two keepers seated, its
    /// map more than a page.
    private func played(watches: Int = 6) throws -> RealmState {
        var realm = RealmState(name: "The Nullmere", seed: "views at scale", seats: 12, radius: 36, watchLength: 600, now: 0)
        _ = try realm.arrive("id-ama", name: "Ama", now: 1)
        _ = try realm.arrive("id-bel", name: "Bel", now: 1)
        for watch in 0..<watches {
            _ = realm.setReady("id-ama", true, now: Double(2 + watch))
            _ = realm.setReady("id-bel", true, now: Double(2 + watch))
        }
        XCTAssertGreaterThan(realm.world.map.count, RealmState.mapPage, "More than a page of map")
        return realm
    }

    /// The map as it was fogged before, tile by tile.
    private func foggedTileByTile(_ map: WorldMap, _ explored: Explored) -> WorldMap {
        var fogged = map
        for index in 0..<map.count where !(explored.indices.contains(index) && explored[index]) {
            fogged.set(index: index, GameState.unknown(map[index]))
        }
        return fogged
    }

    func testTheMapKnownIsTheMapFoggedTileByTile() throws {
        let world = try played().world
        let map = world.map, unexplored = map.unexplored
        XCTAssertEqual(unexplored.tiles, map.tiles.map(GameState.unknown))
        XCTAssertEqual(unexplored.steps, unexplored.tiles.map { WorldMap.step(onto: $0.terrain) })
        var random = SeededRandom(seed: 11)
        let patterns: [Explored] = [
            [],
            Explored(repeating: false, count: map.count),
            Explored(repeating: true, count: map.count),
            Explored((0..<map.count).map { _ in random.chance(25) }),
            Explored((0..<(map.count / 2)).map { _ in random.chance(60) }),
            Explored(repeating: true, count: map.count + 70),
        ] + world.houses.map(\.explored)
        for (number, explored) in patterns.enumerated() {
            let known = map.known(by: explored, from: unexplored)
            let fogged = foggedTileByTile(map, explored)
            XCTAssertEqual(known.tiles, fogged.tiles, "Pattern \(number)")
            XCTAssertEqual(known.steps, fogged.steps, "Pattern \(number): its steps as its tiles are")
            XCTAssertEqual(known, fogged)
        }
        // Known in full, it is the map; known not at all, the unexplored map.
        XCTAssertEqual(map.known(by: Explored(repeating: true, count: map.count), from: unexplored), map)
        XCTAssertEqual(map.known(by: [], from: unexplored), unexplored)
    }

    /// The lie of the land, the claims and the nearest of a terrain kept by
    /// a map known in part are its own, not the unexplored map's.
    func testAMapKnownInPartKeepsWhatIsItsOwn() throws {
        let world = try played().world
        let unexplored = world.map.unexplored
        let lake = try XCTUnwrap(world.map.hexes.first { world.map[$0]?.terrain == .still })
        _ = unexplored.nearest(.greyfield, to: lake)
        let explored = world.houses[0].explored
        let known = world.map.known(by: explored, from: unexplored)
        let fogged = foggedTileByTile(world.map, explored)
        for terrain in [Terrain.greyfield, .strand, .blackwood, .still] {
            XCTAssertEqual(known.nearest(terrain, to: lake), fogged.nearest(terrain, to: lake), "\(terrain)")
        }
        XCTAssertEqual(known.deepestWater(), fogged.deepestWater())
    }

    func testTerrainAndFeatureCodesAreTheirPlaces() {
        for (place, terrain) in Terrain.allCases.enumerated() { XCTAssertEqual(Int(terrain.code), place, "\(terrain)") }
        for (place, feature) in Feature.allCases.enumerated() { XCTAssertEqual(Int(feature.code), place, "\(feature)") }
        let tiles = Terrain.allCases.flatMap { terrain in
            [Tile(terrain: terrain, relief: 7)] + Feature.allCases.map { Tile(terrain: terrain, feature: $0, relief: 93) }
        }
        XCTAssertEqual(WorldMap.tiles(fromCells: WorldMap.cells(of: tiles)), tiles)
        XCTAssertEqual(WorldMap.cells(of: tiles[3..<9]), WorldMap.cells(of: Array(tiles[3..<9])), "A run of tiles as the tiles alone")
    }

    func testEachTileSeenIsToldInOrder() {
        var random = SeededRandom(seed: 5)
        for count in [0, 1, 63, 64, 65, 200, 1_031] {
            let list = (0..<count).map { _ in random.chance(35) }
            var told: [Int] = []
            Explored(list).forEachSeen { told.append($0) }
            XCTAssertEqual(told, list.indices.filter { list[$0] }, "\(count) tiles")
        }
    }

    /// A view worked out with what every view takes alike, worked out once
    /// for many, is the view worked out alone.
    func testAViewWithItsCommonsIsTheViewAlone() throws {
        let world = try played().world
        let commons = world.viewCommons(ways: world.ways())
        for house in [-1] + Array(world.houses.indices) {
            XCTAssertEqual(world.view(for: house, commons: commons), world.view(for: house), "House \(house)")
        }
        let realm = try played()
        let realmCommons = realm.world.viewCommons()
        for keeper in ["id-ama", "id-bel"] {
            XCTAssertEqual(realm.view(for: keeper, commons: realmCommons), realm.view(for: keeper))
        }
        XCTAssertNil(realm.view(for: "id-nobody", commons: realmCommons))
    }

    func testTheMapGoesInPages() throws {
        let realm = try played()
        let map = realm.world.map
        let pages = (map.count + RealmState.mapPage - 1) / RealmState.mapPage
        for parts in [try realm.parts(using: encoder), try XCTUnwrap(realm.view(for: "id-ama")).parts(using: encoder)] {
            XCTAssertEqual(parts["map"], "{\"page\":\(RealmState.mapPage),\"radius\":\(map.radius)}")
            XCTAssertEqual(parts.keys.filter { $0.hasPrefix("map.") }.count, pages)
            XCTAssertNil(parts["map.\(pages)"])
        }
        let parts = try realm.parts(using: encoder)
        let last = (pages - 1) * RealmState.mapPage
        XCTAssertEqual(parts["map.0"], WorldMap.cells(of: map.tiles[0..<RealmState.mapPage]))
        XCTAssertEqual(parts["map.\(pages - 1)"], WorldMap.cells(of: map.tiles[last...]))
        XCTAssertEqual(try RealmState(parts: parts), realm)
        let view = try XCTUnwrap(realm.view(for: "id-ama"))
        XCTAssertEqual(try RealmView(parts: view.parts(using: encoder)), view)
    }

    /// A world kept before its map went in pages, its map one part whole,
    /// reads as it did.
    func testAMapKeptWholeStillReads() throws {
        let realm = try played()
        var parts = try realm.parts(using: encoder)
        for key in parts.keys where key.hasPrefix("map.") { parts[key] = nil }
        parts["map"] = String(decoding: try encoder.encode(realm.world.map), as: UTF8.self)
        XCTAssertEqual(try RealmState(parts: parts), realm)
    }

    func testAMapHalfKeptIsRefused() throws {
        let realm = try played()
        let parts = try realm.parts(using: encoder)
        func refused(_ change: (inout [String: String]) -> Void, as expected: RealmPartsError, line: UInt = #line) {
            var broken = parts
            change(&broken)
            XCTAssertThrowsError(try RealmState(parts: broken), line: line) { error in
                XCTAssertEqual(error as? RealmPartsError, expected, line: line)
            }
        }
        refused({ $0["map.1"] = nil }, as: .missing("map.1"))
        refused({ $0["map.0"] = "not cells" }, as: .unreadable("map.0"))
        refused({ $0["map.1"] = $0["map.0"].map { String($0.dropLast(4)) } }, as: .unreadable("map.1"))
        refused({ $0["map"] = "{\"page\":\(RealmState.mapPage),\"radius\":\(1 << 20)}" }, as: .unreadable("map"))
        refused({ $0["map"] = "{\"page\":0,\"radius\":36}" }, as: .unreadable("map"))
        refused({ $0["map"] = "{\"page\":1,\"radius\":36}" }, as: .unreadable("map"))
        refused({ $0["map"] = "{\"page\":\(RealmState.mapPage),\"radius\":0}" }, as: .unreadable("map"))
        var wrong = parts
        wrong["map"] = "{\"page\":\(RealmState.mapPage),\"radius\":35}"
        XCTAssertThrowsError(try RealmState(parts: wrong), "Pages that don't make the map its head says")
    }

    /// Each keeper's view in parts, taken where it can be from the view of a
    /// keeper of no House and from the world, each as written: the same
    /// parts, to the character, as the view written afresh, and the view
    /// they make the view itself.
    func testPagesTakenAsWrittenAreThePagesWrittenAfresh() throws {
        let realm = try played()
        let world = realm.world
        let commons = world.viewCommons(ways: world.ways())
        let worldParts = try world.parts(using: encoder)
        let stranger = world.view(for: -1, commons: commons)
        let strangerParts = try stranger.parts(using: encoder, reusing: [(world, worldParts)])
        XCTAssertEqual(strangerParts, try stranger.parts(using: encoder))
        for keeper in ["id-ama", "id-bel"] {
            let view = try XCTUnwrap(realm.view(for: keeper, commons: commons))
            let fresh = try view.parts(using: encoder)
            let taken = try view.parts(using: encoder, reusing: [(stranger, strangerParts), (world, worldParts)])
            XCTAssertEqual(taken, fresh, keeper)
            XCTAssertEqual(try RealmView(parts: taken), view)
            // Ground the keeper's House hasn't explored a tile of is as the
            // stranger is told it; and what every keeper is told alike, too.
            let explored = view.world.houses[try XCTUnwrap(view.keeper.house)].explored
            let unseen = (0..<((world.map.count + RealmState.mapPage - 1) / RealmState.mapPage)).filter { page in
                !(page * RealmState.mapPage..<min((page + 1) * RealmState.mapPage, world.map.count)).contains { explored.indices.contains($0) && explored[$0] }
            }
            for page in unseen { XCTAssertEqual(taken["map.\(page)"], strangerParts["map.\(page)"]) }
            XCTAssertEqual(taken["relations.0"], worldParts["relations.0"])
            XCTAssertEqual(taken["chronicle.0"], worldParts["chronicle.0"])
        }
    }

    /// A page unlike the one written is written afresh, not taken; and the
    /// map is never taken from a world whose pages are another size.
    func testAPageUnlikeIsWrittenAfresh() throws {
        let realm = try played()
        let world = realm.world
        let view = try XCTUnwrap(realm.view(for: "id-ama"))
        let fresh = try view.parts(using: encoder)
        // A world written otherwise than it is: its House renamed, its map
        // filled with another ground, its parts as they were.
        var other = world
        other.houses[0].name = "House Otherwise"
        other.map.set(index: 0, Tile(terrain: .barrow))
        var otherParts = try other.parts(using: encoder)
        otherParts["houses.0"] = try view.world.parts(using: encoder)["houses.0"].map { $0 + " " }
        otherParts["map.0"] = "AAAA"
        let taken = try view.parts(using: encoder, reusing: [(other, otherParts)])
        XCTAssertEqual(taken, fresh)
        // The same world, its map head saying pages of another size.
        var resized = try view.world.parts(using: encoder)
        resized["map"] = "{\"page\":1024,\"radius\":\(world.map.radius)}"
        resized["map.0"] = "AAAA"
        XCTAssertEqual(try view.parts(using: encoder, reusing: [(view.world, resized)])["map.0"], fresh["map.0"])
        // A list that ran on past a page taken as written is not taken for
        // the shorter list's last page.
        var less = view.world
        less.chronicle.removeLast()
        let shorter = RealmView(keeper: view.keeper, age: view.age, world: less)
        let shorterFresh = try shorter.parts(using: encoder)
        XCTAssertEqual(try shorter.parts(using: encoder, reusing: [(view.world, fresh)]), shorterFresh)
    }

    /// The world's parts a pace on, taking what is just as it was when last
    /// written, are the world's parts written afresh.
    func testTheWorldAPaceOnTakesWhatStandsAsItWas() throws {
        var realm = try played()
        let before = realm.world, beforeParts = try realm.parts(using: encoder)
        _ = realm.world.walk(to: 1)
        _ = realm.world.walk(to: 2)
        let taken = try realm.parts(using: encoder, reusing: [(before, beforeParts)])
        XCTAssertEqual(taken, try realm.parts(using: encoder))
        XCTAssertEqual(try RealmState(parts: taken), realm)
        XCTAssertEqual(taken["map.0"], beforeParts["map.0"], "The ground as it was")
    }
}
