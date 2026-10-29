import Metal
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The map's Metal view outside the happy path: tiles that come before
/// the shader is ready kept for it, a shader that fails said once, tiles
/// of the wrong size left aside, and the drawing scale following the zoom.
@MainActor
final class WorldMetalViewTests: XCTestCase {
    /// A shader library missing the world's vertex or fragment function is
    /// refused by name, so a broken build says what it lacks.
    func testARendererWithoutItsFunctionsSaysWhichIsMissing() throws {
        guard let device = WorldMetalView.systemDevice else { throw XCTSkip("No Metal device available") }
        func library(_ functions: String) throws -> any MTLLibrary {
            try device.makeLibrary(source: "#include <metal_stdlib>\nusing namespace metal;\n" + functions, options: nil)
        }
        let noVertex = try library("fragment float4 other_fragment() { return float4(0); }")
        let onlyVertex = try library("vertex float4 \(WorldShader.vertexFunction)() { return float4(0); }")
        for (lib, missing) in [(noVertex, WorldShader.vertexFunction), (onlyVertex, WorldShader.fragmentFunction)] {
            XCTAssertThrowsError(try WorldRenderer(device: device, library: lib, pixelFormat: .bgra8Unorm)) { error in
                guard case WorldRenderer.Failure.missingFunction(let name) = error else { return XCTFail("\(error)") }
                XCTAssertEqual(name, missing)
            }
        }
    }

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
