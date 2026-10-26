import Metal
import NullmereCore
import XCTest
@testable import NullmereKit

/// How long the GPU takes to draw the world at a 14-inch MacBook Pro's
/// native resolution, over a game well under way. Prints the time for the
/// record; fails if a frame would not fit a 60 Hz display's budget.
final class WorldPerformanceTests: XCTestCase {
    static let width = 3024
    static let height = 1964

    func testTheWorldFitsAFrameAtSixtyHertz() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("No Metal device available") }
        let library = try device.makeLibrary(source: WorldShader.source, options: nil)
        let renderer = try WorldRenderer(device: device, library: library, pixelFormat: .bgra8Unorm)
        var state = GameState(settings: GameSettings(seedText: "measured water"))
        for _ in 0..<60 {
            _ = state.stewardTurn(for: state.player)
            _ = state.endWatch()
        }
        try renderer.updateTiles(TileTexture.bytes(for: state, viewer: state.player), side: TileTexture.side(for: state.map))
        let seat = try XCTUnwrap(state.seat(of: state.player)).position
        let centre = HexLayout(size: 1).center(of: seat)

        var results: [String] = []
        // Zoomed out is the most work: the most tiles, edges and mist on screen.
        for scale in [12.0, 28.0, 60.0] {
            // At the resolution the view draws at for this zoom.
            let fraction = WorldMetalView.renderScale(forCameraScale: scale)
            let width = Int((Double(Self.width) * fraction).rounded())
            let height = Int((Double(Self.height) * fraction).rounded())
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false
            )
            descriptor.usage = .renderTarget
            descriptor.storageMode = .private
            let target = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
            var times: [Double] = []
            for frame in 0..<30 {
                let uniforms = WorldUniforms(
                    view: SIMD4(Float(width), Float(height), Float(scale * 2 * fraction), Float(3 + Double(frame) / 60)),
                    camera: SIMD4(Float(centre.x), Float(centre.y), Float(state.map.radius), Float(2 * fraction)),
                    highlight: SIMD4(Float(seat.q), Float(seat.r), Float(seat.q), Float(seat.r)),
                    moon: MoonMirror.place(in: state.map)
                )
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
