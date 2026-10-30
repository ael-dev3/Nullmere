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
        let views: [(String, Camera, [UInt8])] = [("seat", near, opening), ("lake", lakeView, whole), ("whole", far, whole),
                                                 ("turned", turned, whole), ("moon", moonView, whole)]
        var frames: [[String: Any]] = []
        for (name, camera, tiles) in views {
            var entry = WorldPreviewTests.uniforms(WorldPreviewTests.frame(camera, terrain: terrain, radius: state.map.radius, time: 20))
            entry["name"] = name
            entry["tiles"] = Data(tiles).base64EncodedString()
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
            "viewport": [Double(WorldPreviewTests.viewport.width), Double(WorldPreviewTests.viewport.height)],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        XCTAssertGreaterThan(data.count, 100_000)
        XCTAssertEqual(frames.count, 5)
        if let folder = ProcessInfo.processInfo.environment["NULLMERE_WORLD_PREVIEW"] {
            let url = URL(fileURLWithPath: folder, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try data.write(to: url.appendingPathComponent("world.json"))
        }
    }
}
