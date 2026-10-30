import Metal
@testable import NullmereCore
@testable import NullmereKit
import NullmereModels
import NullmereWorld
import XCTest

/// How long the GPU takes to draw the world at a 14-inch MacBook Pro's
/// native resolution, over a game well under way. Prints the time for the
/// record; fails if a frame would not fit a 60 Hz display's budget.
final class WorldPerformanceTests: XCTestCase {
    static let width = 3024
    static let height = 1964

    func testTheWorldFitsAFrameAtSixtyHertz() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("No Metal device available") }
        let library = try device.makeLibrary(source: WorldShaders.source, options: nil)
        let renderer = try WorldRenderer(device: device, library: library, pixelFormat: .bgra8Unorm)
        var state = GameState(settings: GameSettings(seedText: "measured water", keepers: 1))
        for _ in 0..<60 {
            _ = state.stewardTurn(for: state.player)
            _ = state.endWatch()
        }
        try renderer.setLand(TerrainMesh.shared(for: state.map), for: state.map)
        try renderer.updateTiles(TileTexture.bytes(for: state, viewer: state.player), side: TileTexture.side(for: state.map))
        // The keeper's seat, or, should their House have fallen in sixty
        // watches of stewards, the first seat still standing.
        let seat = try XCTUnwrap(state.seat(of: state.player) ?? state.livingHouses.lazy.compactMap { state.seat(of: $0.id) }.first).position
        let terrain = try XCTUnwrap(renderer.land).terrain

        var results: [String] = []
        // Zoomed out is the most work: the most land, mist and water in view.
        for scale in [12.0, 28.0, 60.0] {
            // At the resolution the view draws at for this zoom.
            let fraction = WorldMetalView.renderScale(forCameraScale: scale)
            let width = Int((Double(Self.width) * fraction).rounded())
            let height = Int((Double(Self.height) * fraction).rounded())
            let target = try renderer.makeTarget(width: width, height: height)
            var camera = Camera(scale: scale)
            camera.focus(on: seat)
            // The view as the window has it, in points: half the pixels each way.
            let size = CGSize(width: Double(Self.width) / 2, height: Double(Self.height) / 2)
            // Eighty frames once it has settled, as the pan is measured: over
            // fewer, the worst twentieth is a frame or two, and one hiccup of
            // a shared GPU reads as the world's own.
            var times: [Double] = []
            for frame in 0..<85 {
                let uniforms = FrameUniforms.make(camera: camera, size: size, pixelsPerPoint: 2 * fraction, time: Float(3 + Double(frame) / 60),
                                                  motion: 1, radius: state.map.radius, terrain: terrain, hovered: seat, selected: seat,
                                                  houses: WorldView.houseColours)
                if let ms = renderer.measureFrame(uniforms, into: target) { times.append(ms) }
            }
            let settled = Array(times.dropFirst(5)).sorted()
            let median = settled[settled.count / 2]
            let p95 = settled[min(settled.count - 1, Int(Double(settled.count) * 0.95))]
            print("PERFMETRIC world.gpu.scale\(Int(scale)).p50 \(String(format: "%.3f", median))")
            print("PERFMETRIC world.gpu.scale\(Int(scale)).p95 \(String(format: "%.3f", p95))")
            results.append("scale \(Int(scale)) at \(Int(fraction * 100))% median \(String(format: "%.2f", median)) ms")
            // A 60 Hz frame, with a sixth to spare for the interface.
            XCTAssertLessThan(median, 1000.0 / 60 * 0.85, "The world at scale \(scale) must fit a 60 Hz frame with room to spare")
        }
        print("PERF world \(Self.width)x\(Self.height) on \(device.name): " + results.joined(separator: ", "))
    }
}
