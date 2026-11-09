import AppKit
import ImageIO
import Metal
@testable import NullmereCore
@testable import NullmereKit
import NullmereModels
import NullmereRealm
import NullmereWorld
import SwiftUI
import XCTest

/// The world in three dimensions, drawn by its own shaders on this Mac's
/// GPU and looked at: the still black lake holding the stars and the
/// moon, the mist over what the keeper has never seen, the land lit by the
/// moon, and the hex chosen. CI keeps the frames, and prints them small.
final class WorldRenderTests: XCTestCase {
    static let width = 960
    static let height = 600
    static var size: CGSize { CGSize(width: width, height: height) }

    struct Drawn {
        let name: String
        let pixels: [UInt8]
        let camera: Camera

        func luminance(_ x: Int, _ y: Int) -> Double {
            let i = (y * WorldRenderTests.width + x) * 4
            return 0.0722 * Double(pixels[i]) + 0.7152 * Double(pixels[i + 1]) + 0.2126 * Double(pixels[i + 2])
        }
    }

    /// A realm's world, as its keeper first sees it, and whole.
    struct World {
        let state: GameState
        let opening: [UInt8]
        /// What the keeper knows as the age opens, by map index.
        let openingKnown: Explored
        let whole: [UInt8]
        let terrain: TerrainMesh
        let relief: Relief

        init() {
            var state = GameState(settings: GameSettings(seedText: "drawn in the round", houseCount: 12, radius: 24, keepers: 1))
            opening = TileTexture.bytes(for: state, viewer: state.player)
            openingKnown = state.houses[state.player].explored
            state.houses[state.player].explored = Explored(repeating: true, count: state.map.count)
            whole = TileTexture.bytes(for: state, viewer: state.player)
            self.state = state
            terrain = TerrainMesh.shared(for: state.map)
            relief = Relief(map: state.map)
        }
    }

    static let world = World()

    func renderer() throws -> WorldRenderer {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("No Metal device available") }
        let library = try device.makeLibrary(source: WorldShaders.source, options: nil)
        let renderer = try WorldRenderer(device: device, library: library, pixelFormat: .bgra8Unorm)
        try renderer.setLand(WorldRenderTests.world.terrain, for: WorldRenderTests.world.state.map)
        return renderer
    }

    func draw(_ renderer: WorldRenderer, _ name: String, camera: Camera, tiles: [UInt8], selected: Hex? = nil,
              scene: SceneFrame = SceneFrame(), time: Float = 20) throws -> Drawn {
        let world = WorldRenderTests.world
        try renderer.updateTiles(tiles, side: TileTexture.side(for: world.state.map))
        let target = try renderer.makeTarget(width: WorldRenderTests.width, height: WorldRenderTests.height)
        var frame = FrameUniforms.make(camera: camera, size: WorldRenderTests.size, pixelsPerPoint: 1, time: time, motion: 1,
                                       radius: world.state.map.radius, terrain: world.terrain, hovered: nil, selected: selected)
        frame.light(with: PointLight.strongest(scene.lights, near: camera.focus))
        let pixels = try XCTUnwrap(renderer.pixels(frame, scene: scene, into: target), "\(name) drawn")
        return Drawn(name: name, pixels: pixels, camera: camera)
    }

    /// The keeper's seat and a company close in, with every model the
    /// session stages: the keep and its walls and works, the figures in
    /// formation, the land's furniture.
    @MainActor
    func testTheWorldsModelsStandOnTheLand() throws {
        let renderer = try renderer()
        renderer.meshSource = { Library.model($0).mesh }
        let world = WorldRenderTests.world
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = GameSession(state: world.state, store: LocalStore(directory: directory))
        let scene = session.sceneFrame(at: 20)
        print("RENDER models: \(scene.instanceCount) instances in \(scene.batches.count) kinds, \(scene.palette.count) poses")
        XCTAssertGreaterThan(scene.instanceCount, 500)
        let seat = try XCTUnwrap(world.state.seat(of: world.state.player))
        var close = Camera(scale: 70, tilt: 0.95)
        close.focus(on: seat.position)
        let bare = try draw(renderer, "bare", camera: close, tiles: session.tileBytes)
        let stood = try draw(renderer, "seat", camera: close, tiles: session.tileBytes, scene: scene)
        // Where the seat stands, its keep and walls change the picture.
        let centre = close.viewPoint(of: seat.position, height: Double(world.relief.height(of: seat.position)), in: WorldRenderTests.size)
        var changed = 0
        for dy in -90...30 {
            for dx in -90...90 {
                let x = Int(centre.x) + dx, y = Int(centre.y) + dy
                guard x >= 0, y >= 0, x < WorldRenderTests.width, y < WorldRenderTests.height else { continue }
                if abs(stood.luminance(x, y) - bare.luminance(x, y)) > 10 { changed += 1 }
            }
        }
        XCTAssertGreaterThan(changed, 1500, "the seat's keep and walls stand on the land")
        let company = try XCTUnwrap(world.state.units(of: world.state.player).first { $0.kind.isMilitary })
        var near = Camera(scale: 150, tilt: 0.85, heading: 0.5)
        near.focus(on: company.position)
        let figures = try draw(renderer, "company", camera: near, tiles: session.tileBytes, scene: scene)

        // The seat burning: its fire lights the keep and the ground, and
        // embers and smoke rise from it, all drawn by the GPU.
        let ground = Relief.centre(of: seat.position)
        let heart = Vec3(ground.x, world.relief.height(of: seat.position), ground.z)
        var burning = Happenings()
        burning.blazes = [Happenings.Spot(at: heart, strength: 1, seed: 1)]
        var fired = scene
        (fired.motes, fired.lights) = burning.effects(at: 20)
        XCTAssertFalse(fired.motes.isEmpty)
        XCTAssertFalse(fired.lights.isEmpty)
        let ablaze = try draw(renderer, "ablaze", camera: close, tiles: session.tileBytes, scene: fired)
        var warmer = 0
        for dy in -110...20 {
            for dx in -80...80 {
                let x = Int(centre.x) + dx, y = Int(centre.y) + dy
                guard x >= 0, y >= 0, x < WorldRenderTests.width, y < WorldRenderTests.height else { continue }
                let i = (y * WorldRenderTests.width + x) * 4
                // Redder than it stood: firelight on stone, and embers.
                if Int(ablaze.pixels[i + 2]) > Int(stood.pixels[i + 2]) + 12 { warmer += 1 }
            }
        }
        print("RENDER fire: \(fired.motes.count) motes, \(warmer) pixels warmed about the keep")
        XCTAssertGreaterThan(warmer, 400, "the fire lights the keep and its ground")
        try keep([stood, ablaze, figures], as: "world-models")
    }

    /// A grown seat close in, at three moments of a work going up: its
    /// walls and works, a forge at work lighting its yard, its banners, its
    /// townsfolk about its lanes, and the granary rising in its scaffold,
    /// its builders at their stores and the stores drawn on stage by stage.
    @MainActor
    func testACityAtWorkRaisesAWorkStageByStage() throws {
        let renderer = try renderer()
        renderer.meshSource = { Library.model($0).mesh }
        var state = WorldRenderTests.world.state
        let index = try XCTUnwrap(state.holds.firstIndex { $0.isSeat && $0.owner == state.player })
        for (kind, level) in [(BuildingKind.walls, 3), (.forge, 3), (.sawpit, 3), (.quarry, 2), (.musterHall, 2), (.archive, 2), (.beacon, 2)] {
            state.holds[index].levels[kind] = level
        }
        state.holds[index].levels[.granary] = 2
        let seat = state.holds[index]
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var frames: [Drawn] = []
        var stores: [Float] = []
        for (moment, left) in [(0, 9), (1, 5), (2, 2)] {
            var rising = state
            rising.holds[index].project = Hold.Project(kind: .granary, targetLevel: 3, watchesLeft: left)
            let session = GameSession(state: rising, store: LocalStore(directory: directory.appendingPathComponent("\(moment)")))
            let scene = session.sceneFrame(at: 20 + Double(moment) * 1.3)
            let pile = scene.batches.first { $0.key == .prop(.materials) }?.instances.first
            stores.append(pile.map { $0.model.c1.y } ?? 0)
            XCTAssertTrue(scene.batches.contains { $0.key == .scaffold }, "the work rises in its scaffold")
            XCTAssertGreaterThanOrEqual(scene.batches.filter { if case .folk = $0.key { return true } else { return false } }
                                            .flatMap(\.instances).count, 2, "builders and townsfolk at work")
            var near = Camera(scale: 150, tilt: 0.9, heading: 0.6 + Double(moment) * 0.25)
            near.focus(on: seat.position)
            frames.append(try draw(renderer, "city \(moment)", camera: near, tiles: session.tileBytes, scene: scene))
            XCTAssertTrue(scene.lights.contains { $0.colour.x > $0.colour.z * 3 }, "the forge's fire lighting its yard")
        }
        XCTAssertGreaterThan(stores[0], stores[2], "the builders' stores drawn on as it rises: \(stores)")
        try keep(frames, as: "world-city")
    }

    /// A great battle close in: two armies of eight drilled companies,
    /// 400,000 troops, met in one field before the keeper's seat. Each
    /// company shows its throng; the front flashes and sparks; dust hangs
    /// over the field. CI keeps the frame as world-battle.
    @MainActor
    func testAGreatBattleFillsItsFieldWithItsThrongs() throws {
        let renderer = try renderer()
        renderer.meshSource = { Library.model($0).mesh }
        let made = try greatBattle()
        var state = made.state
        let ground = made.ground, me = made.me, foe = made.foe
        let field = try XCTUnwrap(state.fieldsOfBattle.first)
        XCTAssertEqual(field.fighters.count, 16)
        let told = try XCTUnwrap(MoonBand.battleLine(in: state, for: me), "the battle told in the moon band")
        XCTAssertTrue(told.hasPrefix("Battle ") && told.contains("your side") && told.contains("the foe"), told)
        state.houses[me].explored = Explored(repeating: true, count: state.map.count)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = GameSession(state: state, store: LocalStore(directory: directory))
        let scene = session.sceneFrame(at: 20)
        let throngs = session.companyPoses(at: Date(), animated: true, time: 20).filter { $0.throng > 0 }
        XCTAssertEqual(throngs.count, 16, "every company in the field shows its throng")
        XCTAssertTrue(throngs.allSatisfy(\.struck), "every rank in the field takes blows as it gives them")
        XCTAssertEqual(session.happenings(poses: throngs, sights: [], stage: WorldStage(map: state.map, relief: Relief(map: state.map)),
                                          at: Date(), time: 20).impacts.count, 16 * WorldStage.struckSteps.count,
                       "and the blows land on each struck rank")
        XCTAssertGreaterThan(throngs.map(\.throng).reduce(0, +), 16 * 24, "the host in its hundreds of figures")
        print("RENDER battle: \(scene.instanceCount) instances, \(scene.motes.count) motes, \(scene.lights.count) lights")
        XCTAssertGreaterThan(scene.motes.count, 40, "clash and dust over the field")
        var close = Camera(scale: 95, tilt: 0.9, heading: 0.35)
        close.focus(on: ground)
        let bare = try draw(renderer, "bare field", camera: close, tiles: session.tileBytes)
        let fought = try draw(renderer, "battle", camera: close, tiles: session.tileBytes, scene: scene)
        let changed = WorldRenderTests.changed(fought, bare)
        print("RENDER battle: \(changed) of \(WorldRenderTests.width * WorldRenderTests.height / 4) sampled pixels changed by the host")
        XCTAssertGreaterThan(changed, 6_000, "the host fills the field")
        try keep([fought], as: "world-battle")
        // And told on the map, in the band under the bar, while it is fought.
        let app = GameApp(store: LocalStore(directory: directory), readiness: { .ready }, sound: false, address: .hosted(seed: "battle band"),
                          identity: FileIdentityStore(url: directory.appendingPathComponent("identity")))
        let play = ImageRenderer(content: PlayView(app: app, session: session).frame(width: 1100, height: 760).background(Color.black))
        play.scale = 1
        XCTAssertNotNil(play.cgImage)

        // The foe's side broken, three in four of its troops lost: its
        // companies turn their backs and run, ranks gone; the keeper's own
        // stand and fight on.
        let foeSide = try XCTUnwrap(field.side(of: foe))
        var broken = state
        for index in field.fighters.indices where field.fighters[index].side == foeSide {
            broken.fields?[0].fighters[index].lost = field.fighters[index].troops * 3 / 4
        }
        let routed = GameSession(state: broken, store: LocalStore(directory: directory))
            .companyPoses(at: Date(), animated: true, time: 20).filter { $0.throng > 0 }
        let fleeing = routed.filter { broken.unit($0.unit)?.owner == foe }
        XCTAssertEqual(fleeing.count, 8)
        XCTAssertTrue(fleeing.allSatisfy { $0.clip == .march && $0.spread == WorldStage.routSpread }, "a broken side runs")
        XCTAssertTrue(routed.filter { broken.unit($0.unit)?.owner == me }.allSatisfy { $0.spread != WorldStage.routSpread },
                      "the side that holds does not")
    }

    /// Two armies of eight drilled companies, 400,000 troops, met in one
    /// field a few hexes from the keeper's seat: the realm, the field's
    /// heart, and the two Houses.
    func greatBattle() throws -> (state: GameState, ground: Hex, me: Int, foe: Int) {
        var state = WorldRenderTests.world.state
        let me = state.player, foe = (me + 1) % state.houses.count
        _ = try state.declareWar(by: me, on: foe)
        // Paced, as a realm's world is: there blows join in fields of battle.
        state.pacing = Pacing()
        let seat = try XCTUnwrap(state.seat(of: me))
        let east = Hex.directions[0], along = Hex.directions[5]
        func open(_ hex: Hex) -> Bool {
            state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        }
        let steps = [0, -1, 1, -2, 2], bows = [0, -1, 1]
        let ground = try XCTUnwrap(seat.position.spiral(8).first { g in
            g.distance(to: seat.position) >= 3 && steps.allSatisfy { open(g + along * $0) && open(g + along * $0 + east) }
                && bows.allSatisfy { open(g + along * $0 - east) && open(g + along * $0 + east * 2) }
        })
        func raise(_ kind: UnitKind, of house: Int, at hex: Hex) -> Int {
            var unit = Unit(id: state.takeID(), kind: kind, owner: house, position: hex, tier: 5)
            unit.drilled = 25_000 - state.firstMuster(of: unit)
            state.units.append(unit)
            return unit.id
        }
        var orders: [(Int, Int, Hex)] = []
        for step in steps {
            let front = ground + along * step
            orders.append((me, raise(.spear, of: me, at: front), front + east))
            orders.append((foe, raise(.spear, of: foe, at: front + east), front))
        }
        for step in bows {
            let front = ground + along * step
            orders.append((me, raise(.bow, of: me, at: front - east), front + east))
            orders.append((foe, raise(.bow, of: foe, at: front + east * 2), front))
        }
        for (house, unit, target) in orders { _ = try state.perform(.attack(unit: unit, target: target), as: house) }
        return (state, ground, me, foe)
    }

    /// How many pixels of a grid over the frame, every other one each
    /// way, differ between two frames by more than a just-seen step of
    /// brightness.
    static func changed(_ a: Drawn, _ b: Drawn) -> Int {
        var count = 0
        for y in stride(from: 0, to: height, by: 2) {
            for x in stride(from: 0, to: width, by: 2) where abs(a.luminance(x, y) - b.luminance(x, y)) > 8 {
                count += 1
            }
        }
        return count
    }

    /// Frames of a moving picture: two seconds of them, a tenth of a
    /// second apart.
    static let motionFrames = 20
    static let motionStep = 0.1

    /// A scene in motion as the game draws it, frame by frame.
    struct Moving {
        let frames: [Drawn]
        /// Of the sampled pixels, how many change from one frame to the
        /// next, on average: the scene's, and the bare land's under the
        /// same camera at the same moments.
        let pixels: Double
        let bare: Double
        /// How many of the bones posed in a frame, every figure standing
        /// alike at a moment sharing one pose, stand otherwise than any
        /// did a frame before, on average; and how many are posed.
        let bones: Double
        let boneCount: Double
    }

    /// Stages a session's world and draws it at moment after moment, as
    /// the game does, its clock and its hours going on together; and the
    /// bare land under the same camera at the same moments, beside it.
    @MainActor
    func motion(of session: GameSession, camera: Camera, renderer: WorldRenderer, name: String) throws -> Moving {
        session.camera = camera
        let start = Date()
        var frames: [Drawn] = [], bares: [Drawn] = [], palettes: [[Mat4]] = []
        for step in 0..<WorldRenderTests.motionFrames {
            let time = 20 + Double(step) * WorldRenderTests.motionStep
            let scene = session.sceneFrame(at: time, now: start.addingTimeInterval(time - 20))
            palettes.append(scene.palette)
            frames.append(try draw(renderer, "\(name) \(step)", camera: camera, tiles: session.tileBytes, scene: scene, time: Float(time)))
            bares.append(try draw(renderer, "\(name) bare \(step)", camera: camera, tiles: session.tileBytes, time: Float(time)))
        }
        let steps = Double(frames.count - 1)
        let pixels = Double(zip(frames, frames.dropFirst()).map { WorldRenderTests.changed($0, $1) }.reduce(0, +)) / steps
        let bare = Double(zip(bares, bares.dropFirst()).map { WorldRenderTests.changed($0, $1) }.reduce(0, +)) / steps
        // The palette's first transform is the still one, shared by all
        // that stands; after it, each pose's bones, once for every figure
        // that stands so at that moment.
        func transforms(_ palette: [Mat4]) -> [[Float]] {
            palette.dropFirst().map { [$0.c0, $0.c1, $0.c2, $0.c3].flatMap { [$0.x, $0.y, $0.z, $0.w] } }
        }
        var moved = 0
        for (a, b) in zip(palettes, palettes.dropFirst()) {
            let before = Set(transforms(a))
            moved += transforms(b).filter { !before.contains($0) }.count
        }
        let posed = Double(palettes.dropFirst().map { $0.count - 1 }.reduce(0, +)) / steps
        print("RENDER motion \(name): \(Int(pixels)) of \(WorldRenderTests.width * WorldRenderTests.height / 4) sampled pixels change a frame,"
            + " the bare land's \(Int(bare)); \(Int(Double(moved) / steps)) of \(Int(posed)) posed bones new a frame")
        return Moving(frames: frames, pixels: pixels, bare: bare, bones: Double(moved) / steps, boneCount: posed)
    }

    /// The great battle and the seat's town in motion, staged and drawn a
    /// tenth of a second apart for two seconds, as the game draws them:
    /// from frame to frame the figures' skeletons move, the ranks striking
    /// and reeling, the townsfolk walking their lanes and working, and the
    /// picture moves with them, far more than the bare land under them
    /// does. CI keeps each as a moving picture, world-battle-motion.gif
    /// and world-town-motion.gif.
    @MainActor
    func testTheBattleAndTheTownMoveFrameByFrame() throws {
        let renderer = try renderer()
        renderer.meshSource = { Library.model($0).mesh }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let made = try greatBattle()
        var state = made.state
        state.houses[made.me].explored = Explored(repeating: true, count: state.map.count)
        var close = Camera(scale: 95, tilt: 0.9, heading: 0.35)
        close.focus(on: made.ground)
        let battle = try motion(of: GameSession(state: state, store: LocalStore(directory: directory.appendingPathComponent("battle"))),
                                camera: close, renderer: renderer, name: "battle")

        var town = WorldRenderTests.world.state
        let index = try XCTUnwrap(town.holds.firstIndex { $0.isSeat && $0.owner == town.player })
        for (kind, level) in [(BuildingKind.walls, 3), (.forge, 3), (.sawpit, 3), (.quarry, 2), (.granary, 3), (.musterHall, 2), (.archive, 2)] {
            town.holds[index].levels[kind] = level
        }
        var near = Camera(scale: 150, tilt: 0.9, heading: 0.6)
        near.focus(on: town.holds[index].position)
        let streets = try motion(of: GameSession(state: town, store: LocalStore(directory: directory.appendingPathComponent("town"))),
                                 camera: near, renderer: renderer, name: "town")

        for (name, moving) in [("the battle", battle), ("the town", streets)] {
            XCTAssertGreaterThan(moving.boneCount, 20, "\(name): figures posed by their skeletons")
            XCTAssertGreaterThan(moving.bones, moving.boneCount / 10, "\(name): the figures' skeletons move from frame to frame")
            XCTAssertGreaterThan(moving.pixels, moving.bare + 50, "\(name): the picture moves where its figures are, more than its bare land")
        }
        try keepMoving(battle.frames, as: "world-battle-motion")
        try keepMoving(streets.frames, as: "world-town-motion")
    }

    /// Where the view's ray through a pixel meets the world, and what is there.
    func ground(at x: Int, _ y: Int, in drawn: Drawn) -> (hex: Hex, terrain: Terrain?)? {
        let world = WorldRenderTests.world
        let (origin, direction) = drawn.camera.ray(through: CGPoint(x: x, y: y), in: WorldRenderTests.size)
        guard let hit = world.relief.intersect(origin: origin, direction: direction) else { return nil }
        let hex = HexLayout(size: 1).hex(atX: Double(hit.x), y: Double(hit.z))
        return (hex, world.state.map[hex]?.terrain)
    }

    func testTheStillWaterHoldsTheMoonAndTheStars() throws {
        let renderer = try renderer()
        let world = WorldRenderTests.world
        // Looking down on the deepest water from where it holds the moon:
        // the eye set opposite the moon, as high as the moon is.
        let lake = try XCTUnwrap(world.state.moonWater).hex
        var camera = Camera(scale: 16, tilt: acos(Double(Sky.moon.y)), heading: atan2(-Double(Sky.moon.x), -Double(Sky.moon.z)))
        camera.focus(on: lake)
        let drawn = try draw(renderer, "lake", camera: camera, tiles: world.whole)
        // The moon's image lies at the middle of the view, round and bright.
        var middle = 0.0
        for dy in -4...4 {
            for dx in -4...4 { middle = max(middle, drawn.luminance(WorldRenderTests.width / 2 + dx, WorldRenderTests.height / 2 + dy)) }
        }
        XCTAssertGreaterThan(middle, 170, "the moon lies in the water where the eye sees it")
        try keep([drawn], as: "world-lake")

        // Over the open water, deep from any shore: black, but for the
        // moon and the stars it gives back.
        var water: [Double] = []
        var brightest = (value: 0.0, x: 0, y: 0)
        for y in stride(from: 0, to: WorldRenderTests.height, by: 3) {
            for x in stride(from: 0, to: WorldRenderTests.width, by: 3) {
                guard let found = ground(at: x, y, in: drawn), found.terrain == .still,
                      found.hex.neighbors.allSatisfy({ world.state.map[$0]?.terrain == .still }) else { continue }
                let value = drawn.luminance(x, y)
                water.append(value)
                if value > brightest.value { brightest = (value, x, y) }
            }
        }
        XCTAssertGreaterThan(water.count, 2000, "the view holds open water")
        let sorted = water.sorted()
        XCTAssertLessThan(sorted[sorted.count / 2], 26, "the still water is black")
        XCTAssertGreaterThan(brightest.value, 170, "the moon lies in it")
        // And the stars, small bright points in the black away from it.
        var stars = 0
        for y in stride(from: 2, to: WorldRenderTests.height - 2, by: 2) {
            for x in stride(from: 2, to: WorldRenderTests.width - 2, by: 2) {
                let dx = x - WorldRenderTests.width / 2, dy = y - WorldRenderTests.height / 2
                guard dx * dx + dy * dy > 120 * 120, drawn.luminance(x, y) > 40 else { continue }
                guard let found = ground(at: x, y, in: drawn), found.terrain == .still else { continue }
                // A point: brighter than what lies three pixels round it.
                if [(3, 0), (-3, 0), (0, 3), (0, -3)].allSatisfy({ drawn.luminance(x + $0.0, y + $0.1) < drawn.luminance(x, y) - 12 }) {
                    stars += 1
                }
            }
        }
        XCTAssertGreaterThan(stars, 6, "and the stars")
    }

    /// Where the lake meets the land the small waves wash up pale with the
    /// moon and draw back, so the water's edge shows in the dark: the
    /// shore nearest the keeper's seat drawn with its froth and without
    /// it (the same shaders, NM_NO_WASH), and again three seconds on.
    func testTheStrandWashesPaleWithTheMoon() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("No Metal device available") }
        let world = WorldRenderTests.world
        let washed = try renderer()
        let options = MTLCompileOptions()
        options.preprocessorMacros = ["NM_NO_WASH": NSNumber(value: 1)]
        let bare = try WorldRenderer(device: device, library: device.makeLibrary(source: WorldShaders.source, options: options),
                                     pixelFormat: .bgra8Unorm)
        try bare.setLand(world.terrain, for: world.state.map)
        let map = world.state.map
        let isLand = { (hex: Hex) -> Bool in !(map[hex]?.terrain.isWater ?? true) }
        let seat = try XCTUnwrap(world.state.seat(of: world.state.player)).position
        // The lake's own water, the still and the shallows that rim it, where
        // it meets the land.
        let lakeWater: Set<Terrain> = [.still, .shallows]
        let shore = try XCTUnwrap(map.hexes.filter { hex in
            map[hex].map { lakeWater.contains($0.terrain) } == true && hex.neighbors.contains(where: isLand)
        }.min { $0.distance(to: seat) < $1.distance(to: seat) }, "The lake has a shore")
        var camera = Camera(scale: 40)
        camera.focus(on: shore)
        let drawn = try draw(washed, "strand", camera: camera, tiles: world.whole)
        let unwashed = try draw(bare, "strand unwashed", camera: camera, tiles: world.whole)
        let later = try draw(washed, "strand later", camera: camera, tiles: world.whole, time: 23)
        try keep([drawn, later], as: "world-strand")
        var paler: [Double] = [], byTheEdge = 0, moved = 0, darker = 0
        for y in stride(from: 0, to: WorldRenderTests.height, by: 2) {
            for x in stride(from: 0, to: WorldRenderTests.width, by: 2) {
                let gain = drawn.luminance(x, y) - unwashed.luminance(x, y)
                if gain < -2 { darker += 1 }
                guard gain >= 2 else { continue }
                paler.append(gain)
                // Within two hexes of both land and water, never out on the
                // open Still nor up on dry ground.
                if let found = ground(at: x, y, in: drawn) {
                    let near = [found.hex] + found.hex.neighbors + found.hex.neighbors.flatMap(\.neighbors)
                    if near.contains(where: isLand), near.contains(where: { map[$0]?.terrain.isWater ?? false }) { byTheEdge += 1 }
                }
                if abs(later.luminance(x, y) - drawn.luminance(x, y)) >= 2 { moved += 1 }
            }
        }
        let mean = paler.isEmpty ? 0 : paler.reduce(0, +) / Double(paler.count)
        print("RENDER wash: \(paler.count) points paler at the strand by a mean of \(String(format: "%.1f", mean)) levels, "
            + "\(byTheEdge) of them by the water's edge, \(moved) changed three seconds on; \(darker) darker")
        XCTAssertGreaterThan(paler.count, 150, "the strand shows pale where the water meets the land")
        XCTAssertGreaterThan(Double(byTheEdge), 0.9 * Double(paler.count), "and only there")
        XCTAssertGreaterThan(mean, 4, "pale enough to be seen at night")
        XCTAssertEqual(darker, 0, "the froth never darkens what it lies on")
        XCTAssertGreaterThan(Double(moved), 0.3 * Double(paler.count), "the waves wash up and draw back")
    }

    /// A light by the water lies on it as the moon does: a lantern held a
    /// little above the open water, drawn with it and without it, brightens
    /// the water by it with its own warm light, from under it toward the
    /// eye, and darkens nothing.
    func testALanternLiesOnTheWater() throws {
        let renderer = try renderer()
        let world = WorldRenderTests.world
        let lake = try XCTUnwrap(world.state.moonWater).hex
        var camera = Camera(scale: 60)
        camera.focus(on: lake)
        // As high over the water as a fisher's at a boat's bow, and as bright.
        let centre = Relief.centre(of: lake)
        let lantern = PointLight(at: Vec3(centre.x, Relief.waterline + 0.3, centre.z), reach: 1.5, colour: Vec3(1.9, 1.15, 0.45))
        let lit = try draw(renderer, "lantern", camera: camera, tiles: world.whole, scene: SceneFrame(lights: [lantern]))
        let unlit = try draw(renderer, "no lantern", camera: camera, tiles: world.whole)
        try keep([lit], as: "world-lantern")
        let under = camera.viewPoint(of: lake, height: Double(Relief.waterline), in: WorldRenderTests.size)
        var brighter: [Double] = [], towardEye = 0, warm = 0, darker = 0
        for y in stride(from: 0, to: WorldRenderTests.height, by: 2) {
            for x in stride(from: 0, to: WorldRenderTests.width, by: 2) {
                let gain = lit.luminance(x, y) - unlit.luminance(x, y)
                if gain < -1 { darker += 1 }
                guard gain >= 3 else { continue }
                brighter.append(gain)
                if Double(y) > under.y { towardEye += 1 }
                // Its red against its blue, the pixels being BGRA.
                let i = (y * WorldRenderTests.width + x) * 4
                let red = Double(lit.pixels[i + 2]) - Double(unlit.pixels[i + 2])
                let blue = Double(lit.pixels[i]) - Double(unlit.pixels[i])
                if red > 1.5 * blue { warm += 1 }
            }
        }
        let mean = brighter.isEmpty ? 0 : brighter.reduce(0, +) / Double(brighter.count)
        print("RENDER lantern: \(brighter.count) points of the water brighter by a mean of \(String(format: "%.1f", mean)) levels, "
            + "\(warm) of them warm, \(towardEye) toward the eye; \(darker) darker")
        XCTAssertGreaterThan(brighter.count, 20, "The lantern's light lies on the water")
        XCTAssertGreaterThan(Double(warm), 0.8 * Double(brighter.count), "in its own warm colour")
        XCTAssertGreaterThan(Double(towardEye), 0.6 * Double(brighter.count), "from under it toward the eye")
        XCTAssertEqual(darker, 0, "darkening nothing")
    }

    /// Vigils' lights for the fallen carried round the lake on its
    /// current, as the session stages them, drawn low over the water: each
    /// a warm flame in its glow, the nearest laying their light on the water
    /// toward the eye, and nothing darker for them.
    func testVigilsBurnOnTheWater() throws {
        let renderer = try renderer()
        let world = WorldRenderTests.world
        let heart = try XCTUnwrap(world.state.moonWater).hex
        var at = try XCTUnwrap(world.state.map.hexes.filter { $0.distance(to: heart) == 6 && world.state.map[$0]?.terrain == .still }.min())
        var sights: [VigilSight] = []
        for index in 0..<6 {
            let next = world.state.downstream(of: at)
            sights.append(VigilSight(at: at, next: next, id: 40 + index, burned: 0))
            guard let next else { break }
            at = next
        }
        XCTAssertEqual(sights.count, 6)
        var camera = Camera(scale: 130, tilt: 1.2, heading: 0.4)
        camera.focus(on: sights[3].at)
        let lit = WorldStage.vigils(sights, progress: 0.5, scale: camera.scale, time: 20)
        let burning = try draw(renderer, "vigils", camera: camera, tiles: world.whole, scene: SceneFrame(motes: lit.motes, lights: lit.lights))
        let dark = try draw(renderer, "no vigils", camera: camera, tiles: world.whole)
        try keep([burning], as: "world-vigils")
        // Where each flame stands on the screen, and how far its glow
        // reaches about it: the light within that is its own, the rest of
        // what brightens lies on the water.
        let flames = stride(from: 0, to: lit.motes.count, by: 2).map { index -> (at: CGPoint, reach: Double) in
            let place = lit.motes[index].place, glow = lit.motes[index + 1].place.w
            let at = camera.viewPoint(worldX: Double(place.x), worldY: Double(place.z), height: Double(place.y), in: WorldRenderTests.size)
            let edge = camera.viewPoint(worldX: Double(place.x + glow), worldY: Double(place.z), height: Double(place.y), in: WorldRenderTests.size)
            return (at, hypot(Double(edge.x - at.x), Double(edge.y - at.y)) + 3)
        }
        var atFlames = 0, onWater = 0, towardEye = 0, warm = 0, darker = 0
        for y in stride(from: 0, to: WorldRenderTests.height, by: 2) {
            for x in stride(from: 0, to: WorldRenderTests.width, by: 2) {
                let gain = burning.luminance(x, y) - dark.luminance(x, y)
                if gain < -1 { darker += 1 }
                guard gain >= 3 else { continue }
                let i = (y * WorldRenderTests.width + x) * 4
                if Double(burning.pixels[i + 2]) - Double(dark.pixels[i + 2]) > 1.5 * (Double(burning.pixels[i]) - Double(dark.pixels[i])) { warm += 1 }
                func away(_ point: CGPoint) -> Double { hypot(Double(point.x) - Double(x), Double(point.y) - Double(y)) }
                let nearest = flames.min { away($0.at) < away($1.at) }!
                if away(nearest.at) <= nearest.reach {
                    atFlames += 1
                } else {
                    onWater += 1
                    // On the water under one of them, toward the eye.
                    if flames.contains(where: { Double(y) > Double($0.at.y) && abs(Double(x) - Double($0.at.x)) <= 40 }) { towardEye += 1 }
                }
            }
        }
        print("RENDER vigils: \(flames.count) flames, \(atFlames) points lit about them and \(onWater) on the water, "
            + "\(towardEye) of those toward the eye; \(warm) warm in all, \(darker) darker")
        XCTAssertGreaterThan(atFlames, 6 * 4, "Each flame burns in its glow")
        XCTAssertGreaterThan(onWater, 20, "The nearest lay their light on the water")
        XCTAssertGreaterThan(Double(towardEye), 0.8 * Double(onWater), "from under them toward the eye")
        XCTAssertGreaterThan(Double(warm), 0.8 * Double(atFlames + onWater), "in a candle's warm colour")
        XCTAssertEqual(darker, 0, "darkening nothing")
    }

    /// A plea at the gate stands in the world: the seat's ward broken, one
    /// of its folk waits just beyond its gate as the seat is drawn, facing
    /// in, a lantern in hand, in the House's colour, while the plea waits on
    /// its keeper. Drawn with the plea and without it, the petitioner and
    /// their light change the ground at the gate and nothing else.
    @MainActor
    func testAPetitionerWaitsAtTheGate() throws {
        let renderer = try renderer()
        renderer.meshSource = { Library.model($0).mesh }
        var state = WorldRenderTests.world.state
        let me = state.player
        let index = try XCTUnwrap(state.holds.firstIndex { $0.isSeat && $0.owner == me })
        state.holds[index].ward = 1
        state.watch = max(state.watch, Petition.from)
        _ = state.bringPetitions()
        let petition = try XCTUnwrap(state.petition(of: me), "the seat's masons come to its gate")
        XCTAssertEqual(petition.plea, .mend)
        XCTAssertEqual(petition.hold, state.holds[index].id)
        var answered = state
        answered.petitions = nil
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let pleading = GameSession(state: state, store: LocalStore(directory: directory.appendingPathComponent("plea")))
        let quiet = GameSession(state: answered, store: LocalStore(directory: directory.appendingPathComponent("none")))
        let scene = pleading.sceneFrame(at: 20), still = quiet.sceneFrame(at: 20)
        let key = ModelKey.folk(variant: petition.plea.folk)
        func standing(_ scene: SceneFrame) -> [ModelInstance] { scene.batches.first { $0.key == key }?.instances ?? [] }
        let petitioner = standing(scene).filter { one in !standing(still).contains { $0.model == one.model } }
        XCTAssertEqual(petitioner.count, 1, "one of the hold's folk stands at its gate while the plea waits")
        let foot = try XCTUnwrap(petitioner.first).model.c3
        let centre = Relief.centre(of: state.holds[index].position)
        let outward = atan2(Double(foot.x - centre.x), Double(foot.z - centre.z))
        // Seen from without the gate and to one side, the seat beyond.
        let camera = Camera(centerX: Double(foot.x), centerY: Double(foot.z), scale: 240, tilt: 0.8, heading: outward + 0.7)
        let pleaded = try draw(renderer, "petitioner", camera: camera, tiles: pleading.tileBytes, scene: scene)
        let bare = try draw(renderer, "no petitioner", camera: camera, tiles: quiet.tileBytes, scene: still)
        try keep([pleaded], as: "world-petition")
        let at = camera.viewPoint(worldX: Double(foot.x), worldY: Double(foot.z), height: Double(foot.y), in: WorldRenderTests.size)
        var near = 0, far = 0, warm = 0
        for y in stride(from: 0, to: WorldRenderTests.height, by: 2) {
            for x in stride(from: 0, to: WorldRenderTests.width, by: 2) {
                guard abs(pleaded.luminance(x, y) - bare.luminance(x, y)) > 4 else { continue }
                if hypot(Double(x) - Double(at.x), Double(y) - Double(at.y)) < 100 { near += 1 } else { far += 1 }
                // Its red against its blue, the pixels being BGRA.
                let i = (y * WorldRenderTests.width + x) * 4
                if Double(pleaded.pixels[i + 2]) - Double(bare.pixels[i + 2]) > 1.5 * (Double(pleaded.pixels[i]) - Double(bare.pixels[i])) { warm += 1 }
            }
        }
        print("RENDER petitioner: \(near) points changed at the gate, \(far) beyond it; \(warm) of them warm")
        XCTAssertGreaterThan(near, 30, "the petitioner and their light stand at the gate")
        XCTAssertLessThan(far, near / 4 + 10, "and nothing else in the view changes for them")
        XCTAssertGreaterThan(warm, 8, "a lantern lit in their hand")
    }

    /// The envoys waiting on the keeper's answer stand in the world: two
    /// Houses' envoys mounted at the keeper's seat's gate, each in its own
    /// House's colours. Drawn with them waiting and without, they change
    /// the ground at the gate and nothing else.
    @MainActor
    func testEnvoysWaitMountedAtTheSeatsGate() throws {
        let renderer = try renderer()
        renderer.meshSource = { Library.model($0).mesh }
        var state = WorldRenderTests.world.state
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        let senders = state.houses.indices.filter { $0 != me }.prefix(2)
        for (index, from) in senders.enumerated() {
            state.envoys.append(Envoy(id: state.takeID(), from: from, to: me, proposal: index == 0 ? .pact : .peace, arrived: state.watch))
        }
        var answered = state
        answered.envoys.removeAll { $0.to == me }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let waiting = GameSession(state: state, store: LocalStore(directory: directory.appendingPathComponent("envoys")))
        let quiet = GameSession(state: answered, store: LocalStore(directory: directory.appendingPathComponent("none")))
        let scene = waiting.sceneFrame(at: 20), still = quiet.sceneFrame(at: 20)
        let riders = scene.batches.first { $0.key == WorldStage.envoyMount }?.instances ?? []
        let none = still.batches.first { $0.key == WorldStage.envoyMount }?.instances ?? []
        let mounted = riders.filter { one in !none.contains { $0.model == one.model } }
        XCTAssertEqual(mounted.count, senders.count, "Each envoy waits at the seat's gate")
        XCTAssertEqual(mounted.map(\.colour), senders.map { WorldStage.colour(WorldView.houseColours, sigil: state.houses[$0].sigil) },
                       "Each in the colours of the House that sent it")
        let first = try XCTUnwrap(mounted.first).model.c3
        let centre = Relief.centre(of: seat.position)
        let outward = atan2(Double(first.x - centre.x), Double(first.z - centre.z))
        let camera = Camera(centerX: Double(first.x), centerY: Double(first.z), scale: 220, tilt: 0.8, heading: outward + 0.7)
        let drawn = try draw(renderer, "envoys", camera: camera, tiles: waiting.tileBytes, scene: scene)
        let bare = try draw(renderer, "no envoys", camera: camera, tiles: quiet.tileBytes, scene: still)
        try keep([drawn], as: "world-envoys")
        let at = camera.viewPoint(worldX: Double(first.x), worldY: Double(first.z), height: Double(first.y), in: WorldRenderTests.size)
        var near = 0, far = 0
        for y in stride(from: 0, to: WorldRenderTests.height, by: 2) {
            for x in stride(from: 0, to: WorldRenderTests.width, by: 2) where abs(drawn.luminance(x, y) - bare.luminance(x, y)) > 4 {
                if hypot(Double(x) - Double(at.x), Double(y) - Double(at.y)) < 160 { near += 1 } else { far += 1 }
            }
        }
        print("RENDER envoys: \(mounted.count) mounted at the gate, \(near) points changed by them, \(far) beyond")
        XCTAssertGreaterThan(near, 30, "The envoys stand at the gate")
        XCTAssertLessThan(far, near / 4 + 10, "and nothing else in the view changes for them")
    }

    /// The ground the keeper's alliance has marked, drawn as the world
    /// draws it: the alliance's banner planted on each mark, a ring of
    /// light turning about it and light rising from it in its hue, gold to
    /// gather, red to strike, blue to hold; and from afar each a glow that
    /// keeps its size on the screen. Drawn marked and unmarked, close and
    /// far, they change the ground at the marks and nothing else.
    @MainActor
    func testTheAlliancesMarksStandLitOnTheirGround() throws {
        let renderer = try renderer()
        renderer.meshSource = { Library.model($0).mesh }
        var state = WorldRenderTests.world.state
        let me = state.player
        _ = try state.perform(.foundAlliance(name: "Lantern Oath"), as: me)
        let seat = try XCTUnwrap(state.seat(of: me))
        let ring = seat.position.spiral(2).filter { hex in
            hex.distance(to: seat.position) == 2 && state.map[hex]?.terrain.isPassable == true && state.hold(at: hex) == nil
                && state.map.index(of: hex).map { state.houses[me].explored[$0] } == true
        }
        let grounds = stride(from: 0, to: ring.count, by: max(ring.count / 3, 1)).prefix(3).map { ring[$0] }
        XCTAssertEqual(grounds.count, 3)
        for (hex, kind) in zip(grounds, [AllianceMark.Kind.gather, .strike, .hold]) {
            _ = try state.perform(.markGround(hex, kind, words: nil), as: me)
        }
        XCTAssertEqual(state.marksSeen(by: me).map(\.at), grounds)
        var unmarked = state
        unmarked.allianceMarks = nil
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let marked = GameSession(state: state, store: LocalStore(directory: directory.appendingPathComponent("marked")))
        let bare = GameSession(state: unmarked, store: LocalStore(directory: directory.appendingPathComponent("bare")))
        var close = Camera(scale: 110, tilt: 0.85, heading: 0.4)
        close.focus(on: seat.position)
        var far = Camera(scale: 9)
        far.focus(on: seat.position)
        var near = 0, beyond = 0, afar = 0, elsewhere = 0
        var kept: [Drawn] = []
        for (camera, reach) in [(close, 90.0), (far, 16.0)] {
            let drawn = try draw(renderer, "marks", camera: camera, tiles: marked.tileBytes, scene: marked.sceneFrame(at: 20))
            let none = try draw(renderer, "no marks", camera: camera, tiles: bare.tileBytes, scene: bare.sceneFrame(at: 20))
            kept.append(drawn)
            let points = grounds.map { camera.viewPoint(of: $0, height: Double(WorldRenderTests.world.relief.height(of: $0)), in: WorldRenderTests.size) }
            for y in stride(from: 0, to: WorldRenderTests.height, by: 2) {
                for x in stride(from: 0, to: WorldRenderTests.width, by: 2) where abs(drawn.luminance(x, y) - none.luminance(x, y)) > 4 {
                    let marking = points.contains { hypot(Double(x) - Double($0.x), Double(y) - Double($0.y)) < reach }
                    if camera.scale == close.scale {
                        if marking { near += 1 } else { beyond += 1 }
                    } else {
                        if marking { afar += 1 } else { elsewhere += 1 }
                    }
                }
            }
        }
        try keep(kept, as: "world-marks")
        print("RENDER marks: close \(near) points changed at the marks, \(beyond) beyond; afar \(afar) at them, \(elsewhere) beyond")
        XCTAssertGreaterThan(near, 150, "Each mark stands lit on its ground")
        XCTAssertLessThan(beyond, near / 4 + 10, "and nothing else in the view changes for them")
        XCTAssertGreaterThan(afar, 12, "From afar each glows where it lies")
        XCTAssertLessThan(elsewhere, afar / 2 + 10)
    }

    /// A march's way lit on the land, as Rise of Kingdoms draws its marches:
    /// one of the keeper's companies bound for ground six tiles off, the
    /// lights of its way flowing from its feet to a ring where it is bound,
    /// drawn with the world's own shaders. Drawn with the march and
    /// without, they change the ground along the way and nothing else.
    @MainActor
    func testAMarchsWayIsLitOnTheLand() throws {
        let renderer = try renderer()
        renderer.meshSource = { Library.model($0).mesh }
        var state = WorldRenderTests.world.state
        let me = state.player
        let company = try XCTUnwrap(state.units(of: me).first { $0.kind.isMilitary })
        let bound = try XCTUnwrap(company.position.spiral(6).filter { hex in
            hex.distance(to: company.position) == 6 && state.map[hex]?.terrain.isPassable == true && state.hold(at: hex) == nil
                && state.unit(at: hex) == nil && state.path(for: company, to: hex) != nil
        }.first)
        let resting = state
        state.units[try XCTUnwrap(state.unitIndex(company.id))].destination = bound
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let marching = GameSession(state: state, store: LocalStore(directory: directory.appendingPathComponent("marching")))
        let still = GameSession(state: resting, store: LocalStore(directory: directory.appendingPathComponent("still")))
        let march = try XCTUnwrap(marching.state.marches?.first { $0.unit == company.id }, "The keeper's view holds its own march")
        XCTAssertEqual(march.destination, bound)
        XCTAssertNil(still.state.marches?.first { $0.unit == company.id })
        let middle = Relief.centre(of: march.route[march.route.count / 2])
        let camera = Camera(centerX: Double(middle.x), centerY: Double(middle.z), scale: 70, tilt: 0.9, heading: 0.3)
        let drawn = try draw(renderer, "march", camera: camera, tiles: marching.tileBytes, scene: marching.sceneFrame(at: 20))
        let bare = try draw(renderer, "no march", camera: camera, tiles: still.tileBytes, scene: still.sceneFrame(at: 20))
        try keep([drawn], as: "world-march")
        let way = ([company.position] + march.route).map { camera.viewPoint(of: $0, height: Double(WorldRenderTests.world.relief.height(of: $0)), in: WorldRenderTests.size) }
        var along = 0, beyond = 0
        for y in stride(from: 0, to: WorldRenderTests.height, by: 2) {
            for x in stride(from: 0, to: WorldRenderTests.width, by: 2) where abs(drawn.luminance(x, y) - bare.luminance(x, y)) > 4 {
                if way.contains(where: { hypot(Double(x) - Double($0.x), Double(y) - Double($0.y)) < 70 }) { along += 1 } else { beyond += 1 }
            }
        }
        print("RENDER march: \(march.route.count) hexes of the way lit, \(along) points changed along it, \(beyond) beyond")
        XCTAssertGreaterThan(along, 40, "Its way lit on the land")
        XCTAssertLessThan(beyond, along / 3 + 10, "and nothing else in the view changes for it")
    }

    /// A stretch of blackwood the keeper knows, near their seat: its heart
    /// and the wood about it burning, and the ring beyond lying as ash; and
    /// the same world unburnt.
    func blackwoodAlight() throws -> (state: GameState, unburnt: GameState, heart: Hex, burning: [Hex], ash: [Hex]) {
        var state = WorldRenderTests.world.state
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me)).position
        let explored = state.houses[me].explored
        func known(_ hex: Hex) -> Bool { state.map.index(of: hex).map { explored[$0] } ?? false }
        let heart = try XCTUnwrap(state.map.hexes.filter { hex in
            state.isBlackwood(hex) && state.hold(at: hex) == nil && hex.neighbors.filter(state.isBlackwood).count >= 5
                && hex.ring(2).filter(state.isBlackwood).count >= 8 && hex.spiral(2).allSatisfy(known)
        }.min { ($0.distance(to: seat), $0.q, $0.r) < ($1.distance(to: seat), $1.q, $1.r) })
        let burning = [heart] + heart.neighbors.filter { state.isBlackwood($0) && state.hold(at: $0) == nil }
        let ash = heart.ring(2).filter { state.isBlackwood($0) && state.hold(at: $0) == nil }
        let unburnt = state
        state.wildfires = burning.map { Wildfire(at: $0, by: me, caught: state.watch, out: state.watch + Wildfire.burns) }
            + ash.map { Wildfire(at: $0, by: me, caught: state.watch - 4, out: state.watch - 1) }
        XCTAssertEqual(state.problems(), [])
        return (state, unburnt, heart, burning, ash)
    }

    /// The blackwood burning in motion, drawn a tenth of a second apart for
    /// two seconds as the game draws it, the watch's wind blowing east: its
    /// flames, embers and smoke move from frame to frame where the bare
    /// land under them is still, the smoke borne off downwind. CI keeps it
    /// as a moving picture, world-wildfire-motion.gif.
    @MainActor
    func testTheBlackwoodBurnsInMotion() throws {
        let renderer = try renderer()
        renderer.meshSource = { Library.model($0).mesh }
        let alight = try blackwoodAlight()
        var state = alight.state
        let heart = alight.heart
        state.windOfWatch = 0
        XCTAssertEqual(state.wind, 0, "the wind blowing east")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let centre = Relief.centre(of: heart)
        let camera = Camera(centerX: Double(centre.x), centerY: Double(centre.z), scale: 64, tilt: 0.95, heading: 0)
        let moving = try motion(of: GameSession(state: state, store: LocalStore(directory: directory.appendingPathComponent("afire"))),
                                camera: camera, renderer: renderer, name: "wildfire")
        XCTAssertGreaterThan(moving.pixels, moving.bare + 50, "the fire moves where it burns, more than its bare land")
        try keepMoving(moving.frames, as: "world-wildfire-motion")
    }

    @MainActor
    func testTheBlackwoodBurnsAndLiesAsAsh() throws {
        let renderer = try renderer()
        renderer.meshSource = { Library.model($0).mesh }
        let (state, unburnt, heart, burning, ash) = try blackwoodAlight()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let afire = GameSession(state: state, store: LocalStore(directory: directory.appendingPathComponent("afire")))
        let still = GameSession(state: unburnt, store: LocalStore(directory: directory.appendingPathComponent("still")))
        XCTAssertEqual(afire.state.burning.count, burning.count, "The keeper sees the fire")
        XCTAssertEqual(afire.state.ash, Set(ash))
        let centre = Relief.centre(of: heart)
        let camera = Camera(centerX: Double(centre.x), centerY: Double(centre.z), scale: 64, tilt: 0.95, heading: 0.4)
        afire.camera = camera
        still.camera = camera
        let drawn = try draw(renderer, "wildfire", camera: camera, tiles: afire.tileBytes, scene: afire.sceneFrame(at: 20))
        let bare = try draw(renderer, "no wildfire", camera: camera, tiles: still.tileBytes, scene: still.sceneFrame(at: 20))
        // And from afar, where the fires among the trees are too small to
        // see: a warm glow over each tile alight.
        var afar = Camera(scale: Camera.minimumScale)
        afar.focus(on: heart)
        afire.camera = afar
        still.camera = afar
        let far = try draw(renderer, "wildfire afar", camera: afar, tiles: afire.tileBytes, scene: afire.sceneFrame(at: 20))
        let farBare = try draw(renderer, "no wildfire afar", camera: afar, tiles: still.tileBytes, scene: still.sceneFrame(at: 20))
        try keep([drawn, far], as: "world-wildfire")
        func seen(_ hex: Hex) -> CGPoint { afar.viewPoint(of: hex, height: Double(WorldRenderTests.world.relief.height(of: hex)), in: WorldRenderTests.size) }
        let alight = burning.map(seen), touched = (burning + ash).map(seen)
        var glowing = 0, elsewhere = 0, warmAfar = 0
        let ground = (burning + ash).map { camera.viewPoint(of: $0, height: Double(WorldRenderTests.world.relief.height(of: $0)), in: WorldRenderTests.size) }
        var near = 0, beyond = 0, fiery = 0
        // Warmed, as the lanterns' and the vigils' light is judged: its red
        // risen well above what it was, and by half as much again as its
        // blue, the pixels being BGRA. Fire's flames are gold as much as
        // orange, so neither is held to a hue of its own.
        func warmed(_ lit: [UInt8], over dark: [UInt8], at i: Int) -> Bool {
            let red = Int(lit[i + 2]) - Int(dark[i + 2]), blue = Int(lit[i]) - Int(dark[i])
            return red >= 24 && Double(red) > 1.5 * Double(blue)
        }
        for y in stride(from: 0, to: WorldRenderTests.height, by: 2) {
            for x in stride(from: 0, to: WorldRenderTests.width, by: 2) {
                let i = (y * WorldRenderTests.width + x) * 4
                if warmed(drawn.pixels, over: bare.pixels, at: i) { fiery += 1 }
                guard abs(drawn.luminance(x, y) - bare.luminance(x, y)) > 4 else { continue }
                if ground.contains(where: { hypot(Double(x) - Double($0.x), Double(y) - Double($0.y)) < 120 }) { near += 1 } else { beyond += 1 }
            }
        }
        for y in stride(from: 0, to: WorldRenderTests.height, by: 2) {
            for x in stride(from: 0, to: WorldRenderTests.width, by: 2) {
                let i = (y * WorldRenderTests.width + x) * 4
                let there = alight.contains { hypot(Double(x) - Double($0.x), Double(y) - Double($0.y)) < 12 }
                // Its smoke and its light reach as far from afar as near: the
                // same 120 points about the wood it touched.
                let about = touched.contains { hypot(Double(x) - Double($0.x), Double(y) - Double($0.y)) < 120 }
                if there, warmed(far.pixels, over: farBare.pixels, at: i) { warmAfar += 1 }
                guard abs(far.luminance(x, y) - farBare.luminance(x, y)) > 4 else { continue }
                if there { glowing += 1 } else if !about { elsewhere += 1 }
            }
        }
        print("RENDER wildfire: \(burning.count) tiles burning, \(ash.count) as ash; \(near) points changed by it, \(beyond) beyond; \(fiery) points warmed by its light; "
            + "afar \(glowing) points changed where it burns, \(elsewhere) beyond the wood it touched, \(warmAfar) warmed where it burns")
        XCTAssertGreaterThan(near, 150, "The wood burning and burnt")
        XCTAssertLessThan(beyond, near / 2 + 20, "and the world beyond it as it was, but for its smoke")
        XCTAssertGreaterThan(fiery, 40, "Fire's own light, warm in the night")
        XCTAssertGreaterThan(glowing, 12, "From afar the fire glows where it burns")
        XCTAssertLessThan(elsewhere, glowing / 2 + 10, "and nowhere else")
        XCTAssertGreaterThan(warmAfar, 12, "warm, as fire is")
    }

    func testTheUnknownLiesUnderMistAndTheKnownIsLit() throws {
        let renderer = try renderer()
        let world = WorldRenderTests.world
        let seat = try XCTUnwrap(world.state.seat(of: world.state.player)).position
        var camera = Camera(scale: 30)
        camera.focus(on: seat)
        let opening = try draw(renderer, "opening", camera: camera, tiles: world.opening, selected: seat)
        try keep([opening], as: "world-opening")
        let explored = world.openingKnown
        // As the keeper first sees it: their own land lit, the rest unknown.
        var mistPoints: [(x: Int, y: Int)] = [], land: [Double] = []
        for y in stride(from: 0, to: WorldRenderTests.height, by: 4) {
            for x in stride(from: 0, to: WorldRenderTests.width, by: 4) {
                let point = CGPoint(x: x, y: y)
                let flat = camera.hex(at: point, in: WorldRenderTests.size)
                guard let index = world.state.map.index(of: flat) else { continue }
                let around = flat.neighbors.compactMap { world.state.map.index(of: $0) }
                if !explored[index], around.allSatisfy({ !explored[$0] }) {
                    mistPoints.append((x, y))
                } else if explored[index], around.allSatisfy({ explored[$0] }), !(world.state.map[flat]?.terrain.isWater ?? true) {
                    land.append(opening.luminance(x, y))
                }
            }
        }
        let mist = mistPoints.map { opening.luminance($0.x, $0.y) }
        XCTAssertGreaterThan(mist.count, 200)
        XCTAssertGreaterThan(land.count, 50)
        let mistMean = mist.reduce(0, +) / Double(mist.count), landMean = land.reduce(0, +) / Double(land.count)
        let spread = (mist.map { ($0 - mistMean) * ($0 - mistMean) }.reduce(0, +) / Double(mist.count)).squareRoot()
        // And the mist drifts: the same view half a minute on.
        let later = try draw(renderer, "later", camera: camera, tiles: world.opening, selected: seat, time: 50)
        let drifted = mistPoints.filter { abs(later.luminance($0.x, $0.y) - opening.luminance($0.x, $0.y)) >= 1 }.count
        print("RENDER mist: mean \(String(format: "%.1f", mistMean)) beside the known land's \(String(format: "%.1f", landMean)), "
            + "spread \(String(format: "%.2f", spread)); \(drifted) of \(mist.count) points changed half a minute on")
        XCTAssertLessThan(mistMean, 40, "the mist is night-dark")
        XCTAssertGreaterThan(landMean, mistMean + 6, "the known land is lit well above the mist")
        XCTAssertGreaterThan(spread, 1, "the mist lies in banks, never one flat grey")
        XCTAssertGreaterThan(Double(drifted) / Double(mist.count), 0.2, "the mist drifts")

        // The hex chosen is ringed.
        let plain = try draw(renderer, "unchosen", camera: camera, tiles: world.opening)
        let centre = camera.viewPoint(of: seat, height: Double(world.relief.height(of: seat)), in: WorldRenderTests.size)
        var brighter = 0
        for dy in -40...40 {
            for dx in -60...60 {
                let x = Int(centre.x) + dx, y = Int(centre.y) + dy
                guard x >= 0, y >= 0, x < WorldRenderTests.width, y < WorldRenderTests.height else { continue }
                if opening.luminance(x, y) > plain.luminance(x, y) + 8 { brighter += 1 }
            }
        }
        XCTAssertGreaterThan(brighter, 40, "a light rings the chosen hex")
    }

    func testTheWholeWorldFromAfarAndTurned() throws {
        let renderer = try renderer()
        let world = WorldRenderTests.world
        let far = try draw(renderer, "whole", camera: Camera(scale: 9, tilt: 0.6), tiles: world.whole)
        var turned = Camera(scale: 24, heading: 0.9)
        turned.focus(on: try XCTUnwrap(world.state.seat(of: world.state.player)).position)
        let side = try draw(renderer, "turned", camera: turned, tiles: world.whole)
        try keep([far, side], as: "world-afar")
        for drawn in [far, side] {
            var values: [Double] = []
            for y in stride(from: 0, to: WorldRenderTests.height, by: 5) {
                for x in stride(from: 0, to: WorldRenderTests.width, by: 5) { values.append(drawn.luminance(x, y)) }
            }
            let lit = Double(values.filter { $0 > 14 }.count) / Double(values.count)
            let mean = values.reduce(0, +) / Double(values.count)
            let spread = (values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)).squareRoot()
            XCTAssertGreaterThan(lit, 0.15, "\(drawn.name): the world is drawn")
            XCTAssertGreaterThan(spread, 6, "\(drawn.name): land, water and mist told apart, never one flat field")
            XCTAssertLessThan(mean, 140, "\(drawn.name): a night scene")
        }
    }

    /// The Moonford at the full: the lake's bed laid bare along the moon's
    /// road, shingle under a skin of water from shore to shore, pale across
    /// the black of the still water about it.
    func testTheMoonfordLiesPaleAcrossTheBlackWater() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("No Metal device available") }
        var state = WorldRenderTests.world.state
        state.watch = Sundering.first
        _ = state.turnTide()
        let course = try XCTUnwrap(state.ford, "The ford lies open")
        let terrain = TerrainMesh.shared(for: state.map)
        let relief = Relief(map: state.map)
        let library = try device.makeLibrary(source: WorldShaders.source, options: nil)
        let renderer = try WorldRenderer(device: device, library: library, pixelFormat: .bgra8Unorm)
        try renderer.setLand(terrain, for: state.map)
        try renderer.updateTiles(TileTexture.bytes(for: state, viewer: state.player), side: TileTexture.side(for: state.map))
        var camera = Camera(scale: 14, tilt: 0.75)
        camera.focus(on: course[course.count / 2])
        let target = try renderer.makeTarget(width: WorldRenderTests.width, height: WorldRenderTests.height)
        let frame = FrameUniforms.make(camera: camera, size: WorldRenderTests.size, pixelsPerPoint: 1, time: 20, motion: 1,
                                       radius: state.map.radius, terrain: terrain, hovered: nil, selected: nil)
        let drawn = Drawn(name: "moonford", pixels: try XCTUnwrap(renderer.pixels(frame, scene: SceneFrame(), into: target)), camera: camera)
        try keep([drawn], as: "world-moonford")

        var ford: [Double] = [], still: [Double] = []
        for y in stride(from: 0, to: WorldRenderTests.height, by: 3) {
            for x in stride(from: 0, to: WorldRenderTests.width, by: 3) {
                let (origin, direction) = camera.ray(through: CGPoint(x: x, y: y), in: WorldRenderTests.size)
                guard let hit = relief.intersect(origin: origin, direction: direction) else { continue }
                let hex = HexLayout(size: 1).hex(atX: Double(hit.x), y: Double(hit.z))
                switch state.map[hex]?.terrain {
                case .ford?: ford.append(drawn.luminance(x, y))
                case .still? where hex.neighbors.allSatisfy({ state.map[$0]?.terrain == .still }): still.append(drawn.luminance(x, y))
                default: break
                }
            }
        }
        XCTAssertGreaterThan(ford.count, 200, "The view holds the ford")
        XCTAssertGreaterThan(still.count, 200, "and the still water beside it")
        guard !ford.isEmpty, !still.isEmpty else { return }
        let median = { (values: [Double]) -> Double in values.sorted()[values.count / 2] }
        XCTAssertGreaterThan(median(ford), median(still) + 10, "Pale shingle across the black water: \(median(ford)) against \(median(still))")
    }

    /// A frame as an image, its pixels as the renderer gives them.
    static func image(_ drawn: Drawn) throws -> CGImage {
        let provider = try XCTUnwrap(CGDataProvider(data: Data(drawn.pixels) as CFData))
        return try XCTUnwrap(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                                     space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                                     provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    }

    /// Keeps frames in motion as a moving picture, looping, when
    /// NULLMERE_KEEP_RENDERS names a folder: the middle two thirds of
    /// each frame each way, where the scene is, at the pixels drawn.
    func keepMoving(_ frames: [Drawn], as name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["NULLMERE_KEEP_RENDERS"] else { return }
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: path), withIntermediateDirectories: true)
        let url = URL(fileURLWithPath: path).appendingPathComponent("\(name).gif")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, frames.count, nil))
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]] as CFDictionary)
        let middle = CGRect(x: WorldRenderTests.width / 6, y: WorldRenderTests.height / 6,
                            width: WorldRenderTests.width * 2 / 3, height: WorldRenderTests.height * 2 / 3)
        for drawn in frames {
            let image = try XCTUnwrap(try WorldRenderTests.image(drawn).cropping(to: middle))
            CGImageDestinationAddImage(destination, image,
                                       [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: WorldRenderTests.motionStep]] as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination), "\(name) kept as a moving picture")
    }

    /// Keeps the frames as one sheet when NULLMERE_KEEP_RENDERS names a
    /// folder, and prints it small for CI's log.
    func keep(_ frames: [Drawn], as name: String) throws {
        let width = WorldRenderTests.width, height = WorldRenderTests.height
        let images: [CGImage] = try frames.map(WorldRenderTests.image)
        let sheet = NSImage(size: NSSize(width: width * images.count, height: height))
        sheet.lockFocus()
        for (index, image) in images.enumerated() {
            NSImage(cgImage: image, size: NSSize(width: width, height: height)).draw(in: NSRect(x: index * width, y: 0, width: width, height: height))
        }
        sheet.unlockFocus()
        let tiff = try XCTUnwrap(sheet.tiffRepresentation)
        let rep = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        if let path = ProcessInfo.processInfo.environment["NULLMERE_KEEP_RENDERS"] {
            let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
            try FileManager.default.createDirectory(at: URL(fileURLWithPath: path), withIntermediateDirectories: true)
            try png.write(to: URL(fileURLWithPath: path).appendingPathComponent("\(name).png"))
        }
        // Small enough to print at the foot of CI's log: a thumbnail of
        // each frame, as a JPEG, kept beside the full sheet.
        guard let path = ProcessInfo.processInfo.environment["NULLMERE_KEEP_RENDERS"] else { return }
        let thumbWidth = 288 * images.count, thumbHeight = 180
        let small = NSImage(size: NSSize(width: thumbWidth, height: thumbHeight))
        small.lockFocus()
        sheet.draw(in: NSRect(x: 0, y: 0, width: thumbWidth, height: thumbHeight))
        small.unlockFocus()
        if let smallTIFF = small.tiffRepresentation, let smallRep = NSBitmapImageRep(data: smallTIFF),
           let jpeg = smallRep.representation(using: .jpeg, properties: [.compressionFactor: 0.55]) {
            try jpeg.base64EncodedString().write(to: URL(fileURLWithPath: path).appendingPathComponent("\(name).thumb.b64"),
                                                 atomically: true, encoding: .utf8)
        }
    }
}
