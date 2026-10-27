import Metal
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The map's Metal view outside the happy path: tiles that come before
/// the shader is ready kept for it, a shader that fails said once, tiles
/// of the wrong size left aside, and the drawing scale following the zoom.
@MainActor
final class WorldMetalViewTests: XCTestCase {
    func testTilesWaitForTheShaderAndFailuresAreSaidOnce() throws {
        guard let device = WorldMetalView.systemDevice else { throw XCTSkip("No Metal device available") }
        let state = GameState(settings: GameSettings(seedText: "waiting tiles", houseCount: 3, radius: 16))
        let side = TileTexture.side(for: state.map)
        let bytes = TileTexture.bytes(for: state, viewer: state.player)

        // Tiles first, the shader after: the tiles are kept, then taken.
        let view = WorldMetalView()
        var failures = 0
        view.onFailure = { failures += 1 }
        view.setTiles(bytes, side: side, version: 1)
        view.setTiles(bytes, side: side, version: 1)
        let library = try device.makeLibrary(source: WorldShader.source, options: nil)
        view.finishLoading(device: device, library: library, error: nil, pixelFormat: .bgra8Unorm)
        XCTAssertNotNil(view.renderer)
        view.setTiles(bytes, side: side, version: 2)
        XCTAssertEqual(failures, 0)
        // Tiles too few for their side are left aside, the last good ones kept.
        view.setTiles([0, 0, 0, 0], side: side, version: 3)
        XCTAssertEqual(failures, 0)
        XCTAssertTrue(try XCTUnwrap(view.renderer).hasTiles)

        // A shader that didn't compile, and one without the world's functions.
        let uncompiled = WorldMetalView()
        var told = 0
        uncompiled.onFailure = { told += 1 }
        uncompiled.finishLoading(device: device, library: nil, error: nil, pixelFormat: .bgra8Unorm)
        uncompiled.finishLoading(device: device, library: nil, error: nil, pixelFormat: .bgra8Unorm)
        XCTAssertEqual(told, 1, "Said once")
        let empty = try device.makeLibrary(source: "#include <metal_stdlib>\nusing namespace metal;\nkernel void nothing() {}\n", options: nil)
        let unbuilt = WorldMetalView()
        var unbuiltTold = 0
        unbuilt.onFailure = { unbuiltTold += 1 }
        unbuilt.finishLoading(device: device, library: empty, error: nil, pixelFormat: .bgra8Unorm)
        XCTAssertEqual(unbuiltTold, 1)
        XCTAssertNil(unbuilt.renderer)
    }

    func testTheDrawingScaleFollowsTheZoom() {
        XCTAssertEqual(WorldMetalView.renderScale(forCameraScale: 28), 1)
        XCTAssertEqual(WorldMetalView.renderScale(forCameraScale: 60), 0.75, "Close in, three quarters of native")
        let view = WorldMetalView()
        view.setFrameSize(NSSize(width: 800, height: 500))
        var camera = view.camera
        camera.scale = 60
        view.camera = camera
        let close = view.drawableSize.width
        camera.scale = 20
        view.camera = camera
        XCTAssertGreaterThan(view.drawableSize.width, close, "Farther out, drawn at full resolution")
        XCTAssertTrue(view.isOpaque)
        XCTAssertTrue(view.acceptsFirstResponder)
    }
}
