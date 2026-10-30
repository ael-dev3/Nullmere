import LauncherCore
@testable import LauncherKit
import Metal
import XCTest
@testable import NullmereCore
@testable import NullmereKit
import NullmereModels
import NullmereWorld

/// The map's Metal view outside the happy path: tiles that come before
/// the shader is ready kept for it, a shader that fails said once, tiles
/// of the wrong size left aside, and the drawing scale following the zoom.
@MainActor
final class WorldMetalViewTests: XCTestCase {
    /// The map starts over with the scene's clock without a jump: every
    /// motion in it comes round a whole number of times in the period.
    func testTheMapStartsOverWithoutAJump() throws {
        let source = WorldShaders.source
        XCTAssertTrue(source.contains("kClockPeriod = \(String(format: "%.1f", SceneClock.period));"))
        for straight in ["sin(time *", "sin(t *", "cos(t *", "time * 0.0"] {
            XCTAssertFalse(source.contains(straight), "No \(straight) left to jump as the clock starts over")
        }
    }

    /// A shader library missing one of the world's functions is refused by
    /// name, so a broken build says what it lacks.
    func testARendererWithoutItsFunctionsSaysWhichIsMissing() throws {
        guard let device = WorldMetalView.systemDevice else { throw XCTSkip("No Metal device available") }
        func library(_ functions: String) throws -> any MTLLibrary {
            try device.makeLibrary(source: "#include <metal_stdlib>\nusing namespace metal;\n" + functions, options: nil)
        }
        let noLand = try library("fragment float4 other_fragment() { return float4(0); }")
        let onlyLandVertex = try library("vertex float4 \(WorldShaders.landVertex)() { return float4(0); }")
        for (lib, missing) in [(noLand, WorldShaders.landVertex), (onlyLandVertex, WorldShaders.landFragment)] {
            XCTAssertThrowsError(try WorldRenderer(device: device, library: lib, pixelFormat: .bgra8Unorm)) { error in
                guard case WorldRenderer.Failure.missingFunction(let name) = error else { return XCTFail("\(error)") }
                XCTAssertEqual(name, missing)
            }
        }
    }

    func testTilesWaitForTheShaderAndFailuresAreSaidOnce() throws {
        guard let device = WorldMetalView.systemDevice else { throw XCTSkip("No Metal device available") }
        let state = GameState(settings: GameSettings(seedText: "waiting tiles", houseCount: 3, radius: 16, keepers: 1))
        let side = TileTexture.side(for: state.map)
        let bytes = TileTexture.bytes(for: state, viewer: state.player)

        // Tiles first, the shader after: the tiles are kept, then taken.
        let view = WorldMetalView()
        var failures = 0
        view.onFailure = { failures += 1 }
        view.setTiles(bytes, side: side, version: 1)
        view.setTiles(bytes, side: side, version: 1)
        // The land, too, waits for the shader, and is sent once for its map.
        let terrain = TerrainMesh.shared(for: state.map, spacing: 0.6)
        view.setLand(terrain, for: state.map)
        view.setLand(terrain, for: state.map)
        let library = try device.makeLibrary(source: WorldShaders.source, options: nil)
        view.finishLoading(device: device, library: library, error: nil, pixelFormat: .bgra8Unorm)
        XCTAssertNotNil(view.renderer)
        XCTAssertEqual(view.renderer?.land?.map, state.map, "the land kept for the shader, then sent")
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
        XCTAssertEqual(view.sampleCount, WorldRenderer.sampleCount, "edges drawn clean against the night")
        XCTAssertEqual(view.depthStencilPixelFormat, WorldRenderer.depthFormat, "what is nearer hides what is farther")
    }

    /// A twist of two fingers turns the world with them, and says so.
    func testATwistTurnsTheWorld() {
        let view = WorldMetalView()
        var told: [Camera] = []
        view.onCameraChange = { told.append($0) }
        view.twist(by: 0.4)
        XCTAssertEqual(view.camera.heading, -0.4, accuracy: 1e-9)
        XCTAssertEqual(told.last, view.camera)
        view.pinch(by: 1.5, around: CGPoint(x: 10, y: 10))
        XCTAssertEqual(told.count, 2)
    }

    func testInAWindowItListensAndLetsGoWhenItLeaves() throws {
        guard WorldMetalView.systemDevice != nil else { throw XCTSkip("No Metal device available") }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        window.contentView = content
        weak var gone: WorldMetalView?
        autoreleasepool {
            let view = WorldMetalView()
            view.frame = content.bounds
            content.addSubview(view)
            window.orderFrontRegardless()
            // The window's occlusion and the app's activity are heard.
            NotificationCenter.default.post(name: NSWindow.didChangeOcclusionStateNotification, object: window)
            NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            view.updateTrackingAreas()
            view.updateTrackingAreas()
            XCTAssertEqual(view.trackingAreas.count, 1, "One tracking area, renewed")
            // Moved to another window, it listens there instead.
            let other = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
            other.isReleasedWhenClosed = false
            defer { other.close() }
            other.contentView?.addSubview(view)
            XCTAssertNotNil(view.window)
            view.removeFromSuperview()
            gone = view
        }
        let deadline = Date().addingTimeInterval(5)
        while gone != nil, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertNil(gone, "Let go, and its observers with it")
    }

    func testWithoutAMetalDeviceItSaysSo() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let view = WorldMetalView()
        view.device = nil
        var failures = 0
        view.onFailure = { failures += 1 }
        window.contentView?.addSubview(view)
        XCTAssertEqual(failures, 1)
        XCTAssertNil(view.renderer)
    }
}
