import Foundation
import NullmereCore
@testable import NullmereLive
@testable import NullmereLiveStage
import NullmereModels
import NullmereRealm
@testable import NullmereWorld
import XCTest

/// A window of the rebuilt realm as the renderer takes it: its land as a
/// map, its cities as holds, its armies as companies where they are at a
/// moment. Always made and checked from rows written here; drawn from a
/// real realm, and written out for the browser preview, where
/// NULLMERE_REALM_CHECK names one and NULLMERE_WORLD_PREVIEW a folder.
final class LiveWindowTests: XCTestCase {
    private func n(_ value: Double) -> JSONValue { .number(value) }
    private func n(_ value: UInt64) -> JSONValue { .number(Double(value)) }
    private func n(_ value: Int) -> JSONValue { .number(Double(value)) }

    /// A small world: plain, a wood to the east, deep water in the far
    /// west; Ada's city at 10, -4 with a Farm and a Wall; Bryn's at 14, -4;
    /// a grove at 12, -2; Ada's army half way from her city to it; Bryn's
    /// army at work there.
    private func world() -> LiveWorld {
        func ground(_ hex: LiveHex) -> UInt8 {
            if hex.q <= -10 { return 0 }
            if hex.q >= 16 { return 5 }
            return 4
        }
        var chunks: [[JSONValue]] = []
        for cr in -3...2 {
            for cq in -3...2 {
                let bytes = (0..<256).map { index -> UInt8 in ground(LiveHex(q: cq * 16 + index % 16, r: cr * 16 + index / 16)) }
                chunks.append([n(LiveHex(q: cq, r: cr).packed), .string(bytes.map { String(format: "%02x", $0) }.joined())])
            }
        }
        let (ada, bryn, grove) = (LiveHex(q: 10, r: -4), LiveHex(q: 14, r: -4), LiveHex(q: 12, r: -2))
        let way = [ada, LiveHex(q: 10, r: -3), LiveHex(q: 11, r: -3), LiveHex(q: 11, r: -2), grove]
        let route = way.flatMap { hex -> [UInt8] in
            let (q, r) = (UInt16(bitPattern: Int16(hex.q)), UInt16(bitPattern: Int16(hex.r)))
            return [UInt8(q & 0xFF), UInt8(q >> 8), UInt8(r & 0xFF), UInt8(r >> 8)]
        }.map { String(format: "%02x", $0) }.joined()
        return LiveWorld(snapshot: [
            "realm": [[n(0), n(42), n(1_000), n(1), n(1_000), n(2), n(40)]],
            "land": chunks,
            "player": [[n(1), n(9), .string("Ada"), n(1_000), .bool(true), n(1_000)], [n(2), n(8), .string("Bryn"), n(1_000), .bool(true), n(1_000)]],
            "me": [[n(1), n(9), .string("Ada"), n(1_000), .bool(true), n(1_000)]],
            "city": [[n(7), n(1), n(ada.packed), .string("Ada"), n(3), n(1_000), n(1_000), n(1)],
                     [n(8), n(2), n(bryn.packed), .string("Bryn"), n(8), n(9_000), n(1_000), n(1)]],
            "my_city": [[n(7), n(1), n(ada.packed), .string("Ada"), n(3), n(1_000), n(1_000), n(1)]],
            "my_buildings": [[n(21), n(7), n(1), n(3)], [n(22), n(7), n(2), n(2)], [n(23), n(7), n(12), n(11)]],
            "place": [[n(ada.packed), n(1), n(7)], [n(bryn.packed), n(1), n(8)], [n(grove.packed), n(2), n(5)]],
            "site": [[n(5), n(grove.packed), n(2), n(4), n(80_000), n(4)]],
            "march": [[n(3), n(1), n(7), n(1), n(1), n(ada.packed), n(grove.packed), n(5), n(2_000), n(2_024), n(40), .string(route), n(1)],
                      [n(4), n(2), n(8), n(1), n(2), n(bryn.packed), n(grove.packed), n(5), n(2_000), n(2_600), n(90), .string(route), n(2)]],
            "my_squads": [[n(UInt64(3 << 16 | 1 << 8 | 1)), n(3), n(1), n(1), n(10)], [n(UInt64(3 << 16 | 3 << 8 | 2)), n(3), n(3), n(2), n(30)]],
        ])
    }

    func testAWindowOfTheLandIsAMapOfItsOwn() {
        let world = world()
        let window = LiveWindow(world: world, centre: LiveHex(q: 10, r: -4), radius: 12)
        XCTAssertEqual(window.map.radius, 12)
        XCTAssertEqual(window.map[Hex(0, 0)]?.terrain, .greyfield, "the city's own ground, at the window's heart")
        XCTAssertEqual(window.map[Hex(6, 0)]?.terrain, .blackwood, "the wood to the east, six hexes on")
        XCTAssertEqual(window.map[Hex(2, 2)]?.feature, .elderGrove, "the grove lies on its hex as the land's own")
        XCTAssertNil(window.map[Hex(1, 2)]?.feature)
        XCTAssertEqual(window.local(LiveHex(q: 12, r: -2)), Hex(2, 2))
        XCTAssertNil(window.local(LiveHex(q: 30, r: -4)), "beyond the window")
        let heart = window.local(x: LiveHex(q: 10, r: -4).centre.x, y: LiveHex(q: 10, r: -4).centre.y)
        XCTAssertEqual(heart.x, 0, accuracy: 1e-5)
        XCTAssertEqual(heart.z, 0, accuracy: 1e-5)

        // Deep water in the west; and past the world's rim, or where the
        // land was never told, mountain.
        let west = LiveWindow(world: world, centre: LiveHex(q: -12, r: 0), radius: 6)
        XCTAssertEqual(west.map[Hex(0, 0)]?.terrain, .still)
        let rim = LiveWindow(world: world, centre: LiveHex(q: 38, r: 0), radius: 6)
        XCTAssertEqual(rim.map[Hex(0, 0)]?.terrain, .blackwood)
        XCTAssertEqual(rim.map[Hex(3, 0)]?.terrain, .spine, "forty-one hexes out: past the rim")
        XCTAssertEqual(LiveWindow(world: LiveWorld(), centre: LiveHex(q: 0, r: 0), radius: 3).map[Hex(0, 0)]?.terrain, .spine)
        XCTAssertEqual(LiveWindow.terrains.map(\.code), Array(0...7), "the module's grounds by the renderer's own numbers")
        XCTAssertEqual([1, 2, 3, 4, 9].map { LiveWindow.feature(of: $0) }, [.darkLoam, .elderGrove, .stoneSeam, .moonsaltBed, nil])
    }

    func testCitiesStandAsHoldsAndArmiesAsCompaniesWhereTheyAre() throws {
        let world = world()
        let window = LiveWindow(world: world, centre: LiveHex(q: 10, r: -4), radius: 12)
        let colours = (0..<16).map { Vec4(Float($0) / 16, 0.5, 0.5, 1) }

        // The player's own city by what stands in it; another's by its Keep.
        let holds = window.holds(in: world, colours: colours, at: 2_012)
        XCTAssertEqual(holds.map(\.hold.id), [7, 8])
        let own = holds[0].hold, other = holds[1].hold
        XCTAssertEqual(own.position, Hex(0, 0))
        XCTAssertTrue(own.isSeat)
        XCTAssertEqual(own.level(.granary), 1, "a Farm at level 2 is drawn at the first of five")
        XCTAssertEqual(own.level(.walls), 3, "a Wall at level 11, the third")
        XCTAssertEqual(own.level(.sawpit), 0, "no Sawmill stands")
        XCTAssertEqual(other.position, Hex(4, 0))
        XCTAssertEqual(other.level(.walls), 2, "what a city of Keep 8 has most likely raised")
        XCTAssertEqual(other.level(.beacon), 2)
        XCTAssertEqual(other.level(.archive), 2)
        XCTAssertEqual(holds[0].colour, colours[1])
        XCTAssertEqual(holds[1].colour, colours[2])
        XCTAssertEqual([1, 5, 6, 10, 11, 25, 99].map(LiveWindow.shown), [1, 1, 2, 2, 3, 5, 5])
        XCTAssertTrue(LiveWindow(world: world, centre: LiveHex(q: -20, r: 20), radius: 4).holds(in: world, colours: colours, at: 0).isEmpty)

        // The window's tiles: all of it watched, a hold where each city
        // stands, the grove on its hex, no one's territory.
        let tiles = window.tiles(holds: holds)
        let side = TileTexture.side(for: window.map)
        XCTAssertEqual(tiles.count, side * side * 4)
        func tile(_ hex: Hex) -> [UInt8] {
            let at = ((hex.r + 12) * side + hex.q + 12) * 4
            return Array(tiles[at..<at + 4])
        }
        XCTAssertEqual(tile(Hex(0, 0))[0], Terrain.greyfield.code)
        XCTAssertEqual(tile(Hex(0, 0))[1], TileTexture.holdFlag | 2 * TileTexture.seenStep)
        XCTAssertEqual(tile(Hex(4, 0))[1], TileTexture.holdFlag | 2 * TileTexture.seenStep)
        XCTAssertEqual(tile(Hex(2, 2))[1], 2 * TileTexture.seenStep | (Feature.elderGrove.code + 1))
        XCTAssertEqual(TileTexture.seen(tile(Hex(-7, 3))[1]), 2)
        XCTAssertEqual(tile(Hex(6, 0))[0], Terrain.blackwood.code)
        XCTAssertEqual(TileTexture.owner(tiles, at: ((0 + 12) * side + 12) * 4), 0)

        // Ada's army, fifteen seconds into a way of twenty-four over four
        // steps: half way between its third and fourth hexes, facing the way
        // it goes, marching, drawn as what it has most of.
        let relief = Relief(map: window.map)
        let companies = window.companies(in: world, relief: relief, at: 2_015)
        XCTAssertEqual(companies.map(\.unit), [3, 4])
        let mine = companies[0], theirs = companies[1]
        let from = Relief.centre(of: Hex(1, 1)), to = Relief.centre(of: Hex(1, 2))
        XCTAssertEqual(mine.position.x, (from.x + to.x) / 2, accuracy: 1e-4)
        XCTAssertEqual(mine.position.z, (from.z + to.z) / 2, accuracy: 1e-4)
        XCTAssertEqual(mine.clip, .march)
        XCTAssertTrue(mine.isOwn)
        XCTAssertEqual(mine.key, .figure(.rider, tier: 2), "thirty riders to ten spearmen")
        XCTAssertEqual(mine.sigil, 1)
        // From 11, -3 to 11, -2 is a step south-east: east of south.
        XCTAssertEqual(mine.heading, atan2(Float(to.x - from.x), Float(to.z - from.z)), accuracy: 1e-3)
        XCTAssertGreaterThan(mine.heading, 0)
        XCTAssertGreaterThanOrEqual(mine.position.y, Relief.waterline)

        // Bryn's, at work on the grove: standing there, and drawn as spearmen.
        let grove = Relief.centre(of: Hex(2, 2))
        XCTAssertEqual(theirs.position.x, grove.x, accuracy: 1e-4)
        XCTAssertEqual(theirs.position.z, grove.z, accuracy: 1e-4)
        XCTAssertEqual(theirs.clip, .idle)
        XCTAssertFalse(theirs.isOwn)
        XCTAssertEqual(theirs.key, .figure(.spear, tier: 1), "what it is made of is its owner's alone to know")

        // Arrived, Ada's stands at the grove; before it set out, at her city.
        XCTAssertEqual(window.companies(in: world, relief: relief, at: 9_999)[0].position.x, grove.x, accuracy: 1e-4)
        XCTAssertEqual(window.companies(in: world, relief: relief, at: 0)[0].position.x, 0, accuracy: 1e-4)
        XCTAssertEqual(window.companies(in: world, relief: relief, at: 2_012)[0].position.x, Relief.centre(of: Hex(1, 1)).x, accuracy: 1e-4,
                       "half its time gone, at the third hex of five")
        XCTAssertTrue(LiveWindow(world: world, centre: LiveHex(q: -20, r: 20), radius: 4).companies(in: world, relief: relief, at: 2_012).isEmpty)
    }

    /// The window staged as the app stages a world, with its land's
    /// furniture: written out for the browser preview where a folder is
    /// named, from the rows above or, where a realm is named, from it.
    func testAWindowIsStagedForTheRenderer() async throws {
        var world = world()
        var centre = LiveHex(q: 10, r: -4)
        var seconds = 2_012.0
        let environment = ProcessInfo.processInfo.environment
        if let text = environment["NULLMERE_REALM_CHECK"], let url = URL(string: text), var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            parts.path = ""
            let client = try await LiveClient.open(server: try XCTUnwrap(parts.url), database: url.lastPathComponent)
            world = try await client.read()
            // About the city with the most about it: armies out, then the strongest.
            let busiest = world.cities.values.max { a, b in
                let out = { (city: LiveCity) in world.marches.values.filter { $0.city == city.id }.count }
                return (out(a), a.power, b.id) < (out(b), b.power, a.id)
            }
            centre = try XCTUnwrap(busiest, "A city stands in the realm").hex
            seconds = Date().timeIntervalSince1970
        }
        let window = LiveWindow(world: world, centre: centre, radius: 14)
        let relief = Relief(map: window.map)
        let stage = WorldStage(map: window.map, relief: relief)
        let colours: [Vec4] = (0..<16).map { index in
            let hue = Double(index) / 16 * 6.283
            return Vec4(Float(0.5 + 0.4 * cos(hue)), Float(0.45 + 0.35 * cos(hue + 2.1)), Float(0.45 + 0.35 * cos(hue + 4.2)), 1)
        }
        var frame = SceneFrame()
        let sights = window.holds(in: world, colours: colours, at: seconds)
        let (holds, _) = stage.holds(sights, time: 20, into: &frame)
        let poses = window.companies(in: world, relief: relief, at: seconds)
        let companies = stage.companies(poses, houses: colours, into: &frame)
        frame.fixed = stage.furnish(occupied: Set(poses.map(\.hex)), holds: Set(sights.map(\.hold.position)))
        frame.batches = holds + companies
        XCTAssertFalse(sights.isEmpty)
        XCTAssertGreaterThan(frame.instanceCount, 50, "a keep, its works, an army's figures and the land's furniture")
        XCTAssertTrue(frame.batches.contains { if case .figure = $0.key { return true } else { return false } } || poses.isEmpty)

        print("LIVE a window about \(centre.q), \(centre.r): \(sights.count) cities, \(poses.count) armies, \(frame.instanceCount) models")

        guard let folder = environment["NULLMERE_WORLD_PREVIEW"] else { return }
        // As Tools/world3d-preview reads a world: the land's mesh, the
        // tiles, and each view's uniforms, by day and by night.
        let terrain = TerrainMesh(relief: relief, spacing: 0.3)
        let size = CGSize(width: 1280, height: 800)
        func bytes<T>(_ values: [T]) -> String { values.withUnsafeBytes { Data($0) }.base64EncodedString() }
        func m(_ x: Mat4) -> [Float] { [x.c0, x.c1, x.c2, x.c3].flatMap { [$0.x, $0.y, $0.z, $0.w] } }
        func v(_ x: Vec4) -> [Float] { [x.x, x.y, x.z, x.w] }
        let names = ["keyColour", "skyLight", "groundLight", "fillColour", "hazeColour", "mistColour", "mist", "zenith", "horizon", "sun",
                     "moonFace", "water", "land", "glow"]
        func hour(_ uniforms: FrameUniforms) -> [String: Any] {
            var all: [String: Any] = ["key": v(uniforms.key), "haze": v(uniforms.haze), "shadow": m(uniforms.shadow), "still": v(uniforms.still)]
            for (name, value) in zip(names, uniforms.hourValues) { all[name] = v(value) }
            return all
        }
        let side = TileTexture.side(for: window.map)
        let tileBytes = window.tiles(holds: sights)
        var views: [(String, Camera)] = [("seat", Camera(scale: 44)), ("close", Camera(scale: 80, tilt: 0.95)), ("whole", Camera(scale: 20, tilt: 0.6))]
        if let first = poses.first {
            var near = Camera(scale: 150, tilt: 0.85, heading: 0.5)
            near.focus(on: first.hex)
            views.append(("company", near))
        }
        var frames: [[String: Any]] = []
        for (name, camera) in views {
            func uniforms(_ daylight: Daylight) -> FrameUniforms {
                FrameUniforms.make(camera: camera, size: size, pixelsPerPoint: 1, time: 20, motion: 1, radius: window.map.radius,
                                   terrain: terrain, hovered: nil, selected: nil, daylight: daylight)
            }
            let night = uniforms(.night)
            var entry: [String: Any] = [
                "name": name, "viewProjection": m(night.viewProjection), "eye": v(night.eye), "viewport": v(night.viewport),
                "world": v(night.world), "highlight": v(night.highlight), "extent": v(night.extent), "heights": v(night.heights),
                "houses": Array(HousePalette.texels(colours).prefix(128 * 4)), "lights": night.lightValues.flatMap(v),
                "tiles": Data(tileBytes).base64EncodedString(),
                "scene": ["batches": (frame.fixed + frame.batches).map { ["key": $0.key.description, "instances": bytes($0.instances), "count": $0.instances.count] },
                          "palette": bytes(frame.palette), "poses": frame.palette.count, "motes": bytes(frame.motes), "moteCount": frame.motes.count],
            ]
            entry.merge(hour(night)) { _, new in new }
            entry["lit"] = ["day": hour(uniforms(.day)), "dusk": hour(uniforms(.dusk)), "dawn": hour(uniforms(.dawn))]
            frames.append(entry)
        }
        var models: [String: Any] = [:]
        for batch in frame.fixed + frame.batches where models[batch.key.description] == nil {
            let mesh = Library.model(batch.key).mesh
            models[batch.key.description] = ["vertices": bytes(mesh.packed), "indices": bytes(mesh.indices), "count": mesh.indices.count]
        }
        let mesh = terrain.mesh
        let json: [String: Any] = [
            "positions": bytes(mesh.vertices.flatMap { [$0.position.x, $0.position.y, $0.position.z] }),
            "normals": bytes(mesh.vertices.flatMap { [$0.normal.x, $0.normal.y, $0.normal.z] }),
            "colors": bytes(mesh.vertices.flatMap { [$0.color.x, $0.color.y, $0.color.z] }),
            "indices": bytes(mesh.indices), "heights": bytes(terrain.heights), "columns": terrain.columns, "rows": terrain.rows,
            "side": side, "frames": frames, "models": models, "viewport": [1280.0, 800.0],
        ]
        let url = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: json).write(to: url.appendingPathComponent("live.json"))
    }
}
