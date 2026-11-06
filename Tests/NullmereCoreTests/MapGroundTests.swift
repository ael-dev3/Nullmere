import Foundation
import XCTest
@testable import NullmereCore

/// The map's ground travels as its runs, terrain and feature each, and its
/// relief apart, each tile's as its difference from the one before: both
/// come back exactly, whatever they hold, and what doesn't read is refused.
final class MapGroundTests: XCTestCase {
    /// Tiles as maps were kept before their ground went as its runs: three
    /// bytes a tile, base64 (terrain, feature or 0, relief).
    static func cells<Tiles: Collection>(of tiles: Tiles) -> String where Tiles.Element == Tile {
        var bytes: [UInt8] = []
        for tile in tiles {
            bytes += [tile.terrain.code, tile.feature.map { $0.code + 1 } ?? 0, UInt8(clamping: tile.relief)]
        }
        return Data(bytes).base64EncodedString()
    }

    private func base64(_ bytes: [UInt8]) -> String { Data(bytes).base64EncodedString() }

    func testGroundAndReliefComeBackExactly() {
        var random = SeededRandom(seed: 11)
        let terrains = Terrain.allCases, features = Feature.allCases
        for count in [0, 1, 2, 127, 128, 129, 2_048, 5_000] {
            var tiles: [Tile] = []
            while tiles.count < count {
                // Ground lying together, now and then a tile unlike its
                // neighbours, and relief rising and falling by any amount.
                let terrain = terrains[random.int(below: terrains.count)]
                let feature = random.chance(30) ? features[random.int(below: features.count)] : nil
                for _ in 0..<min(1 + random.int(below: 300), count - tiles.count) {
                    let relief = random.chance(5) ? random.int(below: 2_000_001) - 1_000_000 : random.int(below: 101)
                    tiles.append(Tile(terrain: terrain, feature: random.chance(90) ? feature : nil, relief: relief))
                }
            }
            let ground = WorldMap.ground(of: tiles), relief = WorldMap.relief(of: tiles)
            XCTAssertEqual(WorldMap.tiles(ground: ground, relief: relief), tiles, "\(count) tiles")
            XCTAssertEqual(WorldMap.reliefs(fromText: relief), tiles.map(\.relief))
            XCTAssertEqual(WorldMap.tiles(fromGround: ground, count: count), tiles.map { Tile(terrain: $0.terrain, feature: $0.feature) })
        }
        // The widest differences either way, and every terrain and feature.
        let extremes = [Int.max, Int.min, 0, -1, 1, Int.max, Int.min].map { Tile(terrain: .still, relief: $0) }
        XCTAssertEqual(WorldMap.tiles(ground: WorldMap.ground(of: extremes), relief: WorldMap.relief(of: extremes)), extremes)
        let every = terrains.flatMap { terrain in [Tile(terrain: terrain)] + features.map { Tile(terrain: terrain, feature: $0, relief: 50) } }
        XCTAssertEqual(WorldMap.tiles(ground: WorldMap.ground(of: every), relief: WorldMap.relief(of: every)), every)
    }

    /// A lake's ground is a few runs: a page of it a small part of its
    /// cells, and a page of nothing but open water a few bytes.
    func testALakesGroundIsAFewRuns() {
        let map = GameState(settings: GameSettings(seedText: "a few runs", houseCount: 12, radius: 36)).map
        let ground = WorldMap.ground(of: map.tiles), relief = WorldMap.relief(of: map.tiles), cells = MapGroundTests.cells(of: map.tiles)
        XCTAssertLessThan(ground.utf8.count * 4, cells.utf8.count, "The ground a quarter of the cells at most")
        XCTAssertLessThan(relief.utf8.count * 2, cells.utf8.count, "The relief half of them at most")
        let water = Array(repeating: Tile(terrain: .still), count: RealmState.mapPage)
        XCTAssertLessThanOrEqual(WorldMap.ground(of: water).utf8.count, 12)
        XCTAssertEqual(WorldMap.tiles(ground: WorldMap.ground(of: map.tiles), relief: relief), map.tiles)
    }

    /// A map's relief is known to be another's at a glance where it is one
    /// map's: its copies', and the maps a keeper is shown of it. A copy whose
    /// relief changes, and a map read, are compared tile by tile.
    func testAMapsReliefIsKnownAtAGlanceForItsCopiesAndViews() throws {
        let map = GameState(settings: GameSettings(seedText: "relief at a glance", houseCount: 3, radius: 16)).map
        let unexplored = map.unexplored
        var seen = Explored(repeating: false, count: map.count)
        seen[3] = true
        let known = map.known(by: seen, from: unexplored)
        var ford = map
        ford.set(index: 7, Tile(terrain: .ford, relief: map.tiles[7].relief))
        for other in [map, unexplored, known, ford] {
            XCTAssertTrue(other.reliefOf === map.reliefOf, "Its relief kept")
            XCTAssertTrue(other.hasTheRelief(of: map))
        }
        var risen = map
        risen.set(index: 5, Tile(terrain: map.tiles[5].terrain, feature: map.tiles[5].feature, relief: map.tiles[5].relief + 3))
        XCTAssertFalse(risen.reliefOf === map.reliefOf)
        XCTAssertFalse(risen.hasTheRelief(of: map))
        var fallen = risen
        fallen.set(index: 5, map.tiles[5])
        XCTAssertFalse(fallen.reliefOf === map.reliefOf, "Its relief changed twice")
        XCTAssertTrue(fallen.hasTheRelief(of: map), "and is the same again, tile for tile")
        let read = try JSONDecoder().decode(WorldMap.self, from: JSONEncoder().encode(map))
        XCTAssertFalse(read.reliefOf === map.reliefOf)
        XCTAssertTrue(read.hasTheRelief(of: map))
        // What one map's keeper is shown, made from another's unexplored
        // map, has some of each relief: its own.
        let mixed = risen.known(by: seen, from: unexplored)
        XCTAssertFalse(mixed.reliefOf === risen.reliefOf)
        XCTAssertFalse(mixed.reliefOf === map.reliefOf)
        XCTAssertTrue(risen.known(by: Explored(repeating: false, count: map.count), from: unexplored).reliefOf === map.reliefOf,
                      "Nothing known: the unexplored map's")
        let smaller = GameState(settings: GameSettings(seedText: "relief at a glance", houseCount: 3, radius: 12)).map
        XCTAssertFalse(smaller.hasTheRelief(of: map), "A map of another size")
    }

    /// A map's ground is known to be another's page by page at a glance
    /// where both lie on one ground: its copies', and the pages of the
    /// maps a keeper is shown of the unexplored map that they explored
    /// none of. A page either wrote tiles of its own to, and maps of other
    /// ground, are compared tile by tile, and found alike or not as they are.
    func testAMapsGroundIsKnownPageByPage() throws {
        let map = GameState(settings: GameSettings(seedText: "ground at a glance", houseCount: 12, radius: 40)).map
        let pages = GameState.MapPages(radius: map.radius, page: RealmState.mapPage)
        XCTAssertGreaterThan(pages.count, 2)
        let unexplored = map.unexplored
        XCTAssertFalse(unexplored.groundOf === map.groundOf, "The unexplored map's ground its own")
        var seen = Explored(repeating: false, count: map.count)
        // A few tiles of the second page explored, and the whole of the
        // first.
        for index in pages.tiles(of: 0) { seen[index] = true }
        let unlike = try XCTUnwrap(pages.tiles(of: 1).first { map.tiles[$0] != unexplored.tiles[$0] })
        seen[unlike] = true
        let known = map.known(by: seen, from: unexplored)
        XCTAssertTrue(known.groundOf === unexplored.groundOf)
        XCTAssertEqual(known.apart, [0, 1])
        for page in 0..<pages.count {
            let range = pages.tiles(of: page)
            XCTAssertEqual(known.hasTheGround(of: unexplored, onPage: page, tiles: range), known.tiles[range] == unexplored.tiles[range], "page \(page)")
            XCTAssertEqual(known.hasTheGround(of: map, onPage: page, tiles: range), known.tiles[range] == map.tiles[range], "page \(page)")
        }
        XCTAssertTrue(known.hasTheGround(of: map, onPage: 0, tiles: pages.tiles(of: 0)), "Explored whole, the world's page, tile for tile")
        XCTAssertFalse(known.hasTheGround(of: unexplored, onPage: 1, tiles: pages.tiles(of: 1)))
        XCTAssertTrue(known.hasTheGround(of: unexplored, onPage: 2, tiles: pages.tiles(of: 2)))
        XCTAssertTrue(map.known(by: Explored(repeating: false, count: map.count), from: unexplored).apart.isEmpty)
        // A copy whose tile changes sets its page apart; the map it was
        // made from keeps its own.
        var ford = map
        let index = pages.tiles(of: 2).lowerBound + 7
        ford.set(index: index, Tile(terrain: .ford, relief: map.tiles[index].relief))
        XCTAssertTrue(ford.groundOf === map.groundOf)
        XCTAssertEqual(ford.apart, [2])
        XCTAssertTrue(map.apart.isEmpty, "A ground no other map shared when its tiles were laid")
        XCTAssertFalse(ford.hasTheGround(of: map, onPage: 2, tiles: pages.tiles(of: 2)))
        XCTAssertTrue(ford.hasTheGround(of: map, onPage: 1, tiles: pages.tiles(of: 1)))
        var back = ford
        back.set(index: index, map.tiles[index])
        XCTAssertTrue(back.hasTheGround(of: map, onPage: 2, tiles: pages.tiles(of: 2)), "Changed and changed back: the same tiles")
        let read = try JSONDecoder().decode(WorldMap.self, from: JSONEncoder().encode(map))
        XCTAssertFalse(read.groundOf === map.groundOf, "A map read: ground of its own")
        XCTAssertTrue(read.hasTheGround(of: map, onPage: 1, tiles: pages.tiles(of: 1)))
    }

    func testWhatDoesntReadIsRefused() {
        let tiles = [Tile(terrain: .still), Tile(terrain: .still), Tile(terrain: .barrow, feature: .stoneSeam, relief: 40)]
        let ground = WorldMap.ground(of: tiles), relief = WorldMap.relief(of: tiles)
        XCTAssertEqual(WorldMap.tiles(ground: ground, relief: relief), tiles)
        // Three tiles: still twice, then barrow; no feature twice, then a
        // stone seam. Each as it ought to be, then each wrong.
        XCTAssertEqual(ground, base64([3, 2, 0, 1, 6, 2, 0, 1, 3]))
        XCTAssertNotNil(WorldMap.tiles(fromGround: base64([3, 2, 0, 1, 6, 2, 0, 1, 3]), count: 3))
        for wrong: [UInt8] in [
            [3, 2, 0, 1, 6, 2, 0, 1],        // cut short
            [3, 2, 0, 1, 6, 2, 0, 1, 3, 9],  // more after the last run
            [3, 2, 0, 2, 6, 2, 0, 1, 3],     // terrain runs past the tiles
            [3, 2, 0, 0, 6, 1, 6, 2, 0, 1, 3], // a run of none
            [3, 2, 0, 1, 200, 2, 0, 1, 3],   // no such terrain
            [3, 2, 0, 1, 6, 2, 0, 1, 6],     // no such feature
            [4, 2, 0, 1, 6, 2, 0, 1, 3],     // more tiles than the page has
            [0x80],                          // a count cut short
        ] {
            XCTAssertNil(WorldMap.tiles(fromGround: base64(wrong), count: 3), "\(wrong)")
        }
        XCTAssertNil(WorldMap.tiles(fromGround: "not base64!", count: 3))
        XCTAssertNil(WorldMap.tiles(fromGround: ground, count: 4), "Fewer tiles than asked for")
        XCTAssertNil(WorldMap.tiles(fromGround: ground, count: -1))
        XCTAssertEqual(WorldMap.tiles(fromGround: WorldMap.ground(of: [Tile]()), count: 0), [])

        XCTAssertEqual(WorldMap.reliefs(fromText: base64([3, 0, 0, 80])), [0, 0, 40])
        XCTAssertEqual(WorldMap.reliefs(fromText: base64([2, 80, 79])), [40, 0], "Down by forty")
        XCTAssertNil(WorldMap.reliefs(fromText: base64([3, 0, 0])), "Cut short")
        XCTAssertNil(WorldMap.reliefs(fromText: base64([2, 0, 0, 0])), "More after the last")
        XCTAssertNil(WorldMap.reliefs(fromText: base64([100, 0, 0])), "More tiles than bytes to tell them")
        XCTAssertNil(WorldMap.reliefs(fromText: "not base64!"))
        XCTAssertNil(WorldMap.tiles(ground: ground, relief: base64([2, 0, 0])), "The relief of fewer tiles than the ground")
        XCTAssertNil(WorldMap.tiles(ground: ground, relief: "not base64!"))
    }

    /// Numbers seven bits to a byte: as wide as sixty-four bits and no
    /// wider, a difference either way as small as it is.
    func testNumbersSevenBitsToAByte() {
        for value: UInt64 in [0, 1, 127, 128, 16_383, 16_384, UInt64(Int.max), UInt64.max] {
            var bytes: [UInt8] = []
            Varint.append(value, to: &bytes)
            var read = Varint.Reader(bytes)
            XCTAssertEqual(read.next(), value)
            XCTAssertTrue(read.isAtEnd)
        }
        var widest: [UInt8] = []
        Varint.append(UInt64.max, to: &widest)
        XCTAssertEqual(widest.count, 10)
        var past = Varint.Reader(Array(widest.dropLast()) + [2])
        XCTAssertNil(past.next(), "Wider than sixty-four bits")
        var longer = Varint.Reader(Array(repeating: 0x80, count: 10) + [0])
        XCTAssertNil(longer.next())
        var short = Varint.Reader([0x80])
        XCTAssertNil(short.next())
        var none = Varint.Reader([])
        XCTAssertNil(none.byte())
        var huge = Varint.Reader(widest)
        XCTAssertNil(huge.count(), "More than any count")
        for difference in [0, 1, -1, 63, -64, 64, Int.max, Int.min] {
            XCTAssertEqual(Varint.unzigzag(Varint.zigzag(difference)), difference)
        }
        XCTAssertEqual([0, -1, 1, -2, 2].map(Varint.zigzag), [0, 1, 2, 3, 4])
    }
}
