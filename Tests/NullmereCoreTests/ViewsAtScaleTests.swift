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
        XCTAssertEqual(WorldMap.tiles(ground: WorldMap.ground(of: tiles), relief: WorldMap.relief(of: tiles)), tiles)
        XCTAssertEqual(WorldMap.tiles(fromCells: MapGroundTests.cells(of: tiles)), tiles, "As maps were kept before")
        XCTAssertEqual(WorldMap.ground(of: tiles[3..<9]), WorldMap.ground(of: Array(tiles[3..<9])), "A run of tiles as the tiles alone")
        XCTAssertEqual(WorldMap.relief(of: tiles[3..<9]), WorldMap.relief(of: Array(tiles[3..<9])))
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
            XCTAssertEqual(parts.keys.filter { $0.hasPrefix("ground.") }.count, pages)
            XCTAssertEqual(parts["relief"], WorldMap.relief(of: map.tiles), "The relief whole, the world's own")
            XCTAssertNil(parts["ground.\(pages)"])
            XCTAssertTrue(parts.keys.allSatisfy { !$0.hasPrefix("map.") }, "No page kept as cells")
        }
        let parts = try realm.parts(using: encoder)
        let last = (pages - 1) * RealmState.mapPage
        XCTAssertEqual(parts["ground.0"], WorldMap.ground(of: map.tiles[0..<RealmState.mapPage]))
        XCTAssertEqual(parts["ground.\(pages - 1)"], WorldMap.ground(of: map.tiles[last...]))
        XCTAssertEqual(try RealmState(parts: parts), realm)
        let view = try XCTUnwrap(realm.view(for: "id-ama"))
        XCTAssertEqual(try RealmView(parts: view.parts(using: encoder)), view)
    }

    /// A world kept before its map went in pages, its map one part whole,
    /// reads as it did.
    func testAMapKeptWholeStillReads() throws {
        let realm = try played()
        var parts = try realm.parts(using: encoder)
        for key in parts.keys where key.hasPrefix("ground.") || key == "relief" { parts[key] = nil }
        let map = realm.world.map
        parts["map"] = #"{"cells":"\#(MapGroundTests.cells(of: map.tiles))","radius":\#(map.radius)}"#
        XCTAssertEqual(try RealmState(parts: parts), realm)
        parts["map"] = String(decoding: try encoder.encode(map), as: UTF8.self)
        XCTAssertEqual(try RealmState(parts: parts), realm, "And whole as a map is kept now")
    }

    /// A world and a view kept while each page of the map was the cells of
    /// its tiles read as they did.
    func testAMapKeptAsCellsStillReads() throws {
        let realm = try played()
        let view = try XCTUnwrap(realm.view(for: "id-ama"))
        func kept(_ parts: [String: String], _ tiles: [Tile]) -> [String: String] {
            var kept = parts.filter { !$0.key.hasPrefix("ground.") && $0.key != "relief" }
            for start in stride(from: 0, to: tiles.count, by: RealmState.mapPage) {
                kept["map.\(start / RealmState.mapPage)"] = MapGroundTests.cells(of: tiles[start..<min(start + RealmState.mapPage, tiles.count)])
            }
            return kept
        }
        let world = kept(try realm.parts(using: encoder), realm.world.map.tiles)
        XCTAssertEqual(try RealmState(parts: world), realm)
        XCTAssertEqual(try RealmView(parts: kept(try view.parts(using: encoder), view.world.map.tiles)), view)
        var broken = world
        broken["map.1"] = nil
        XCTAssertThrowsError(try RealmState(parts: broken)) { error in
            XCTAssertEqual(error as? RealmPartsError, .missing("map.1"))
        }
        broken["map.1"] = MapGroundTests.cells(of: realm.world.map.tiles[0..<10])
        XCTAssertThrowsError(try RealmState(parts: broken)) { error in
            XCTAssertEqual(error as? RealmPartsError, .unreadable("map.1"))
        }
        // Its pages taken by a world written now are written afresh.
        XCTAssertEqual(try realm.parts(using: encoder, reusing: [(realm.world, world)]), try realm.parts(using: encoder))
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
        refused({ $0["ground.1"] = nil }, as: .missing("ground.1"))
        refused({ $0["relief"] = nil }, as: .missing("relief"))
        refused({ $0["ground.0"] = "not ground" }, as: .unreadable("ground.0"))
        refused({ $0["relief"] = "not relief" }, as: .unreadable("relief"))
        refused({ $0["relief"] = $0["relief"].map { String($0.dropLast(4)) } }, as: .unreadable("relief"))
        // A page's ground, and the relief, that tell of fewer tiles than
        // there are.
        let few = Array(realm.world.map.tiles[0..<10])
        refused({ $0["relief"] = WorldMap.relief(of: few) }, as: .unreadable("relief"))
        refused({ $0["ground.1"] = WorldMap.ground(of: few) }, as: .unreadable("ground.1"))
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
            for page in unseen { XCTAssertEqual(taken["ground.\(page)"], strangerParts["ground.\(page)"]) }
            // The lie of the land is told alike, the world's own.
            XCTAssertEqual(taken["relief"], strangerParts["relief"])
            XCTAssertEqual(taken["relief"], worldParts["relief"])
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
        other.map.set(index: 0, Tile(terrain: .barrow, relief: world.map.tiles[0].relief + 1))
        var otherParts = try other.parts(using: encoder)
        otherParts["houses.0"] = try view.world.parts(using: encoder)["houses.0"].map { $0 + " " }
        otherParts["ground.0"] = "AAAA"
        otherParts["relief"] = "AAAA"
        let taken = try view.parts(using: encoder, reusing: [(other, otherParts)])
        XCTAssertEqual(taken, fresh)
        // The same world, its map head saying pages of another size.
        var resized = try view.world.parts(using: encoder)
        resized["map"] = "{\"page\":1024,\"radius\":\(world.map.radius)}"
        resized["ground.0"] = "AAAA"
        let takenResized = try view.parts(using: encoder, reusing: [(view.world, resized)])
        XCTAssertEqual(takenResized["ground.0"], fresh["ground.0"])
        // Its relief, whole and in no pages, is.
        XCTAssertEqual(takenResized["relief"], fresh["relief"])
        // A list that ran on past a page taken as written is not taken for
        // the shorter list's last page.
        var less = view.world
        less.chronicle.removeLast()
        let shorter = RealmView(keeper: view.keeper, age: view.age, world: less)
        let shorterFresh = try shorter.parts(using: encoder)
        XCTAssertEqual(try shorter.parts(using: encoder, reusing: [(view.world, fresh)]), shorterFresh)
    }

    /// A view's pages of Houses and of holds are those every keeper is told
    /// alike: the keeper's own House and holds, and what allies tell them
    /// of theirs, go apart in its own part, and the view joins whole. The
    /// deeds every House has done go in pages of their own, the same in
    /// every view; and a world kept with its deeds in its head still reads
    /// as it did.
    func testAViewsOwnHousesGoApartAndDeedsInPages() throws {
        var realm = try played()
        let ama = try XCTUnwrap(realm.keeper("id-ama")?.house), bel = try XCTUnwrap(realm.keeper("id-bel")?.house)
        realm.world.deedsDone = (0..<40).map { DeedDone(house: $0 % 12, deed: Deed.allCases[$0 % Deed.allCases.count], watch: $0, told: $0 % 3 == 0) }
        // A granary rising at Ama's seat and spearmen training at Bel's.
        let amasSeat = try XCTUnwrap(realm.world.holds.firstIndex { $0.owner == ama && $0.isSeat })
        realm.world.holds[amasSeat].project = Hold.Project(kind: .granary, targetLevel: 2, watchesLeft: 3)
        let belsSeat = try XCTUnwrap(realm.world.holds.firstIndex { $0.owner == bel && $0.isSeat })
        realm.world.holds[belsSeat].training = Hold.Training(kind: UnitKind.allCases[0], watchesLeft: 2)
        let view = try XCTUnwrap(realm.view(for: "id-ama"))
        let parts = try view.parts(using: encoder)
        let stranger = try realm.world.view(for: -1).parts(using: encoder)
        let pages = parts.keys.filter { $0.hasPrefix("houses.") || $0.hasPrefix("holds.") }
        XCTAssertGreaterThan(pages.count, 1)
        for page in pages { XCTAssertEqual(parts[page], stranger[page], "\(page) as every keeper is told it") }
        let own = try JSONDecoder().decode(RealmView.Own.self, from: Data(try XCTUnwrap(parts[RealmView.ownPart]).utf8))
        XCTAssertEqual(own.houses, [view.world.houses[ama]], "Their own House apart, whole")
        let ownHolds = view.world.holds.filter { $0.toldAlike() != $0 }
        XCTAssertFalse(ownHolds.isEmpty, "Holds with works under way")
        XCTAssertTrue(ownHolds.allSatisfy { $0.owner == ama })
        XCTAssertEqual(own.holds, Array(ownHolds), "Their holds' works apart, whole")
        XCTAssertEqual(try RealmView(parts: parts), view)

        // An ally's study and training under way, told them: apart too.
        var told = view.world
        told.houses[bel].research.pursuit = Pursuit(study: Study.allCases[0], grade: 1, watchesLeft: 3)
        let belsSeatID = realm.world.holds[belsSeat].id
        let belsSeatTold = try XCTUnwrap(told.holds.index(ofID: belsSeatID))
        XCTAssertNil(told.holds[belsSeatTold].training, "Not told a stranger's training")
        told.holds[belsSeatTold].training = realm.world.holds[belsSeat].training
        let allied = RealmView(keeper: view.keeper, age: view.age, world: told)
        let alliedParts = try allied.parts(using: encoder)
        let alliedOwn = try JSONDecoder().decode(RealmView.Own.self, from: Data(try XCTUnwrap(alliedParts[RealmView.ownPart]).utf8))
        XCTAssertEqual(alliedOwn.houses.map(\.id).sorted(), [ama, bel].sorted())
        XCTAssertTrue(alliedOwn.holds.contains { $0.id == belsSeatID && $0.training != nil }, "An ally's training apart")
        for page in pages { XCTAssertEqual(alliedParts[page], stranger[page]) }
        XCTAssertEqual(try RealmView(parts: alliedParts), allied)

        // The deeds in pages, alike in every view and in the world's own.
        XCTAssertEqual(parts.keys.filter { $0.hasPrefix("deeds.") }.sorted(), ["deeds.0", "deeds.1"])
        let worldParts = try realm.world.parts(using: encoder)
        XCTAssertEqual(worldParts["deeds.0"], parts["deeds.0"])
        XCTAssertEqual(worldParts["deeds.1"], stranger["deeds.1"])
        var head = try JSONDecoder().decode(GameState.self, from: Data(try XCTUnwrap(worldParts["head"]).utf8))
        XCTAssertEqual(head.deedsDone, [], "The head says only that there are deeds")
        var joined = head
        try joined.join(worldParts, using: JSONDecoder())
        XCTAssertEqual(joined.deedsDone, realm.world.deedsDone)
        // Kept before deeds had pages: in the head, and read from there.
        head.deedsDone = realm.world.deedsDone
        let before = worldParts.filter { !$0.key.hasPrefix("deeds.") }
        var kept = head
        try kept.join(before, using: JSONDecoder())
        XCTAssertEqual(kept.deedsDone, realm.world.deedsDone)
        // An own House that isn't one of the realm's is refused.
        var stray = parts
        let none = House(id: view.world.houses.count + 3, name: "House Astray", sigil: 0, isPlayer: false,
                         temperament: Temperament.allCases[0], tileCount: view.world.map.count)
        stray[RealmView.ownPart] = String(decoding: try encoder.encode(RealmView.Own(houses: [none])), as: UTF8.self)
        XCTAssertThrowsError(try RealmView(parts: stray))
        var strayHold = view.world.holds[0]
        strayHold = Hold(id: view.world.holds.map(\.id).max()! + 9, name: "Astray", owner: ama, position: strayHold.position, isSeat: false, foundedWatch: 0)
        stray[RealmView.ownPart] = String(decoding: try encoder.encode(RealmView.Own(holds: [strayHold])), as: UTF8.self)
        XCTAssertThrowsError(try RealmView(parts: stray), "A hold not of the realm")
    }

    /// A view read part by part as its publications come, each part decoded
    /// only when its text is new, is the view read afresh every time, and
    /// decodes only the parts that were rewritten.
    func testAViewReadPartByPartIsTheViewReadAfresh() throws {
        var realm = try played()
        let read = PartsRead()
        var last: [String: String] = [:]
        for pace in 1...4 {
            let view = try XCTUnwrap(realm.view(for: "id-ama"))
            let parts = try view.parts(using: encoder)
            let before = read.decoded
            XCTAssertEqual(try RealmView(parts: parts, read: read), view, "Pace \(pace)")
            let rewritten = parts.filter { last[$0.key] != $0.value }.count
            XCTAssertEqual(read.decoded - before, rewritten, "Pace \(pace): only the parts rewritten decoded")
            if !last.isEmpty { XCTAssertLessThan(rewritten, parts.count, "Some of a view stands from one pace to the next") }
            XCTAssertEqual(try RealmView(parts: parts, read: read), try RealmView(parts: parts), "Read again, the same")
            XCTAssertEqual(read.decoded - before, rewritten, "and nothing more decoded")
            XCTAssertEqual(read.count, parts.count)
            last = parts
            _ = realm.world.walk(to: pace)
        }
        // A view of fewer parts: what was read of the rest let go.
        var less = try XCTUnwrap(realm.view(for: "id-ama")).world
        less.chronicle = Array(less.chronicle.prefix(1))
        let fewer = try RealmView(keeper: try XCTUnwrap(realm.keeper("id-ama")), age: realm.age, world: less).parts(using: encoder)
        XCTAssertEqual(try RealmView(parts: fewer, read: read), try RealmView(parts: fewer))
        XCTAssertEqual(read.count, fewer.count)
        // A part not what its name says, read anew: refused as before.
        var broken = fewer
        broken["houses.0"] = "{}"
        XCTAssertThrowsError(try RealmView(parts: broken, read: read))
        broken["houses.0"] = nil
        XCTAssertThrowsError(try RealmView(parts: broken, read: read)) { error in
            XCTAssertEqual(error as? RealmPartsError, .missing("houses.0"))
        }
        broken = fewer
        broken["ground.1"] = "AAAA"
        XCTAssertThrowsError(try RealmView(parts: broken, read: read)) { error in
            XCTAssertEqual(error as? RealmPartsError, .unreadable("ground.1"))
        }
        broken = fewer
        broken["relief"] = "AAAA"
        XCTAssertThrowsError(try RealmView(parts: broken, read: read)) { error in
            XCTAssertEqual(error as? RealmPartsError, .unreadable("relief"))
        }
        read.forget()
        XCTAssertEqual(read.count, 0)
        XCTAssertEqual(try RealmView(parts: fewer, read: read), try RealmView(parts: fewer), "Read anew after forgetting")
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
        XCTAssertEqual(taken["ground.0"], beforeParts["ground.0"], "The ground as it was")
        XCTAssertEqual(taken["relief"], beforeParts["relief"])
    }
}
