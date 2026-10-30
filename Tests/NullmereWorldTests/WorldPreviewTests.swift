import Foundation
@testable import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

/// A world as Tools/world3d-preview draws it with the same shaders in a
/// browser: always made and checked; written out when NULLMERE_WORLD_PREVIEW
/// names a folder.
final class WorldPreviewTests: XCTestCase {
    static let viewport = CGSize(width: 1280, height: 800)

    static func frame(_ camera: Camera, terrain: TerrainMesh, radius: Int, time: Float) -> FrameUniforms {
        let size = viewport
        let eye = camera.eye(in: size)
        let low = terrain.low, high = terrain.high
        return FrameUniforms(
            viewProjection: camera.viewProjection(in: size),
            eye: Vec4(eye.x, eye.y, eye.z, time),
            moon: Vec4(Sky.moon.x, Sky.moon.y, Sky.moon.z, Sky.moonStrength),
            viewport: Vec4(Float(size.width), Float(size.height), 1 / Float(size.width), 1 / Float(size.height)),
            world: Vec4(Float(radius), Float(2 * radius + 1), Float(camera.scale), 1),
            highlight: Vec4(999, 999, 999, 999),
            extent: Vec4(low.x, low.z, high.x, high.z),
            haze: Sky.haze(eyeDistance: (eye - camera.focus).length, spacing: terrain.spacing),
            heights: Vec4(terrain.originX, terrain.originZ, Float(terrain.columns), Float(terrain.rows)),
            houses: (0..<16).map { index in
                let hue = Double(index) / 16 * 6.283
                return Vec4(Float(0.35 + 0.3 * cos(hue)), Float(0.3 + 0.25 * cos(hue + 2.1)), Float(0.3 + 0.25 * cos(hue + 4.2)), 1)
            })
    }

    static func uniforms(_ frame: FrameUniforms) -> [String: Any] {
        func m(_ x: Mat4) -> [Float] { [x.c0, x.c1, x.c2, x.c3].flatMap { [$0.x, $0.y, $0.z, $0.w] } }
        func v(_ x: Vec4) -> [Float] { [x.x, x.y, x.z, x.w] }
        return ["viewProjection": m(frame.viewProjection), "eye": v(frame.eye), "moon": v(frame.moon), "viewport": v(frame.viewport),
                "world": v(frame.world), "highlight": v(frame.highlight), "extent": v(frame.extent), "haze": v(frame.haze),
                "heights": v(frame.heights), "houses": frame.houseColours.flatMap(v)]
    }

    /// Every model a world's keeper sees, staged as the app stages them:
    /// the land's furniture, the holds with their works, the companies in
    /// formation, the birds over the water.
    static func stage(_ state: GameState) -> SceneFrame {
        let relief = Relief(map: state.map)
        let stage = WorldStage(map: state.map, relief: relief)
        let houses = (0..<16).map { index -> Vec4 in
            let hue = Double(index) / 16 * 6.283
            return Vec4(Float(0.35 + 0.3 * cos(hue)), Float(0.3 + 0.25 * cos(hue + 2.1)), Float(0.3 + 0.25 * cos(hue + 4.2)), 1)
        }
        var frame = SceneFrame()
        let sights = state.holds.map { HoldSight(hold: $0, colour: WorldStage.colour(houses, sigil: state.houses[$0.owner].sigil)) }
        let (holds, hearths) = stage.holds(sights, time: 20, into: &frame)
        let visible = state.visibility(for: state.player)
        let poses = state.units.filter { $0.owner == state.player || (state.map.index(of: $0.position).map { visible[$0] } ?? false) }
            .enumerated().map { index, unit -> CompanyPose in
                let centre = Relief.centre(of: unit.position)
                return CompanyPose(unit: unit.id, key: .figure(unit.kind, tier: 1 + index % ModelKey.tiers(of: unit.kind)),
                                   sigil: state.houses[unit.owner].sigil, health: unit.health, hex: unit.position,
                                   position: Vec3(centre.x, max(relief.height(of: unit.position), Relief.waterline), centre.z),
                                   heading: Float(index) * 0.7, clipTime: Float(index) * 0.4, isOwn: unit.owner == state.player,
                                   commander: index % 3 == 0 ? index % ModelKey.commanderVariants : nil,
                                   spread: state.hold(at: unit.position) == nil ? 1 : 0.3)
            }
        let companies = stage.companies(poses, houses: houses, into: &frame)
        let lake = Relief.centre(of: Hex(0, 0))
        let flights = WorldStage.flights(arrows: [], birdsOver: Vec3(lake.x, 0, lake.z), hearths: hearths, time: 20, into: &frame)
        frame.fixed = stage.furnish(occupied: Set(poses.map(\.hex)), holds: Set(state.holds.map(\.position)))
        frame.batches = holds + companies + flights
        return frame
    }

    /// A frame's models as the preview reads them: each kind's instances,
    /// as the GPU takes them, and the poses.
    static func export(_ scene: SceneFrame) -> [String: Any] {
        func bytes<T>(_ values: [T]) -> String { values.withUnsafeBytes { Data($0) }.base64EncodedString() }
        return [
            "batches": (scene.fixed + scene.batches).map { ["key": $0.key.description, "instances": bytes($0.instances), "count": $0.instances.count] },
            "palette": bytes(scene.palette), "poses": scene.palette.count,
        ]
    }

    /// Each kind of model the scene draws, as the GPU takes it.
    static func meshes(for scene: SceneFrame) -> [String: Any] {
        var models: [String: Any] = [:]
        for batch in scene.fixed + scene.batches where models[batch.key.description] == nil {
            let mesh = Library.model(batch.key).mesh
            models[batch.key.description] = ["vertices": mesh.packed.withUnsafeBytes { Data($0) }.base64EncodedString(),
                                             "indices": mesh.indices.withUnsafeBytes { Data($0) }.base64EncodedString(),
                                             "count": mesh.indices.count]
        }
        return models
    }

    func testAWorldExportsForThePreview() throws {
        var state = GameState(settings: GameSettings(seedText: "preview", houseCount: 12, radius: 24, keepers: 1))
        let opening = TileTexture.bytes(for: state, viewer: state.player)
        state.houses[state.player].explored = Array(repeating: true, count: state.map.count)
        let whole = TileTexture.bytes(for: state, viewer: state.player)
        let terrain = TerrainMesh(relief: Relief(map: state.map), spacing: 0.3)
        let seat = try XCTUnwrap(state.seat(of: state.player)).position
        let lake = try XCTUnwrap(state.moonWater).hex

        var near = Camera(scale: 34)
        near.focus(on: seat)
        var lakeView = Camera(scale: 16)
        lakeView.focus(on: lake)
        lakeView.centerY += 6
        let far = Camera(scale: 9, tilt: 0.6)
        var turned = Camera(scale: 24, heading: 0.9)
        turned.focus(on: seat)
        // Opposite the moon and as high, looking down on its image in the water.
        var moonView = Camera(scale: 16, tilt: acos(Double(Sky.moon.y)), heading: atan2(-Double(Sky.moon.x), -Double(Sky.moon.z)))
        moonView.focus(on: lake)
        // Close in on the seat, and closer on a company, with every model staged.
        var close = Camera(scale: 70, tilt: 0.95)
        close.focus(on: seat)
        let company = try XCTUnwrap(state.units(of: state.player).first { $0.kind.isMilitary })
        var companyView = Camera(scale: 150, tilt: 0.85, heading: 0.5)
        companyView.focus(on: company.position)
        let scene = WorldPreviewTests.stage(state)
        let views: [(String, Camera, [UInt8], SceneFrame?)] = [
            ("seat", near, opening, nil), ("lake", lakeView, whole, nil), ("whole", far, whole, nil), ("turned", turned, whole, nil),
            ("moon", moonView, whole, nil), ("close", close, whole, scene), ("company", companyView, whole, scene),
        ]
        var frames: [[String: Any]] = []
        for (name, camera, tiles, scene) in views {
            var entry = WorldPreviewTests.uniforms(WorldPreviewTests.frame(camera, terrain: terrain, radius: state.map.radius, time: 20))
            entry["name"] = name
            entry["tiles"] = Data(tiles).base64EncodedString()
            if let scene { entry["scene"] = WorldPreviewTests.export(scene) }
            frames.append(entry)
        }
        let mesh = terrain.mesh
        let json: [String: Any] = [
            "positions": Data(mesh.vertices.flatMap { [$0.position.x, $0.position.y, $0.position.z] }.withUnsafeBufferPointer { Data(buffer: $0) }).base64EncodedString(),
            "normals": Data(mesh.vertices.flatMap { [$0.normal.x, $0.normal.y, $0.normal.z] }.withUnsafeBufferPointer { Data(buffer: $0) }).base64EncodedString(),
            "colors": Data(mesh.vertices.flatMap { [$0.color.x, $0.color.y, $0.color.z] }.withUnsafeBufferPointer { Data(buffer: $0) }).base64EncodedString(),
            "indices": mesh.indices.withUnsafeBufferPointer { Data(buffer: $0) }.base64EncodedString(),
            "heights": terrain.heights.withUnsafeBufferPointer { Data(buffer: $0) }.base64EncodedString(),
            "columns": terrain.columns, "rows": terrain.rows, "side": TileTexture.side(for: state.map), "frames": frames,
            "models": WorldPreviewTests.meshes(for: scene),
            "viewport": [Double(WorldPreviewTests.viewport.width), Double(WorldPreviewTests.viewport.height)],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        XCTAssertGreaterThan(data.count, 100_000)
        XCTAssertEqual(frames.count, 7)
        if let folder = ProcessInfo.processInfo.environment["NULLMERE_WORLD_PREVIEW"] {
            let url = URL(fileURLWithPath: folder, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try data.write(to: url.appendingPathComponent("world.json"))
        }
    }
}
