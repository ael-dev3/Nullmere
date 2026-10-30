import Metal
@testable import NullmereCore
@testable import NullmereKit
import NullmereModels
import NullmereWorld
import XCTest

/// The frame as the keeper waits for it: a world frame's whole time, from
/// encoding to the GPU finishing, and the GPU's share of it, over a game
/// well under way while the camera pans, at a 14-inch MacBook Pro's native
/// resolution. CI holds each figure to its baseline (scripts/perf-check.py).
final class FrameHarnessTests: XCTestCase {
    func testAFrameWhileTheCameraPans() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("No Metal device available") }
        let library = try device.makeLibrary(source: WorldShaders.source, options: nil)
        let renderer = try WorldRenderer(device: device, library: library, pixelFormat: .bgra8Unorm)
        var state = GameState(settings: GameSettings(seedText: "panning frames", keepers: 1))
        for _ in 0..<40 {
            _ = state.stewardTurn(for: state.player)
            _ = state.endWatch()
        }
        try renderer.setLand(TerrainMesh.shared(for: state.map), for: state.map)
        try renderer.updateTiles(TileTexture.bytes(for: state, viewer: state.player), side: TileTexture.side(for: state.map))
        let terrain = try XCTUnwrap(renderer.land).terrain
        let seat = try XCTUnwrap(state.seat(of: state.player)).position
        let start = HexLayout(size: 1).center(of: seat)
        let scale = 28.0
        let fraction = WorldMetalView.renderScale(forCameraScale: scale)
        let width = Int((3024 * fraction).rounded()), height = Int((1964 * fraction).rounded())
        let target = try renderer.makeTarget(width: width, height: height)
        let size = CGSize(width: 1512, height: 982)

        // Two hundred and forty frames once warm, so the slowest twentieth is
        // a dozen frames, not the few a shared runner's hiccup can spoil.
        // Three passes of them: a shared runner's GPU is sometimes busy with
        // other work for seconds on end, and that lands in one pass, while
        // a slower frame of the game's own is slower in every pass. Each
        // figure is the steadiest pass's.
        func percentile(_ values: [Double], _ p: Double) -> Double {
            let sorted = values.sorted()
            return sorted[min(sorted.count - 1, Int(Double(sorted.count) * p))]
        }
        struct Pass { let frames: [Double], gpu: [Double] }
        var passes: [Pass] = []
        for _ in 0..<3 {
            var frames: [Double] = [], gpu: [Double] = []
            for frame in 0..<250 {
                // A slow pan across the lake, as a keeper drags the map.
                let t = Double(frame) / 60 * 90 / 250
                let camera = Camera(centerX: start.x + t * 6, centerY: start.y + t * 2, scale: scale)
                let began = ContinuousClock.now
                let uniforms = FrameUniforms.make(camera: camera, size: size, pixelsPerPoint: 2 * fraction, time: Float(3 + t), motion: 1,
                                                  radius: state.map.radius, terrain: terrain, hovered: nil, selected: nil,
                                                  houses: WorldView.houseColours)
                guard let ms = renderer.measureFrame(uniforms, into: target) else { continue }
                let took = ContinuousClock.now - began
                if frame >= 10 {
                    gpu.append(ms)
                    frames.append(Double(took.components.seconds) * 1000 + Double(took.components.attoseconds) / 1e15)
                }
            }
            XCTAssertGreaterThan(frames.count, 200)
            passes.append(Pass(frames: frames, gpu: gpu))
        }
        func steadiest(_ values: (Pass) -> [Double], _ p: Double) -> Double {
            passes.map { percentile(values($0), p) }.min() ?? 0
        }
        let figures: [(String, (Pass) -> [Double])] = [("frame", { $0.frames }), ("gpu", { $0.gpu })]
        for (name, values) in figures {
            print("PERFMETRIC pan.\(name).p50 \(String(format: "%.3f", steadiest(values, 0.5)))")
            print("PERFMETRIC pan.\(name).p95 \(String(format: "%.3f", steadiest(values, 0.95)))")
        }
        let each = passes.map { String(format: "%.2f", percentile($0.frames, 0.95)) }.joined(separator: ", ")
        print("PERF a panning frame \(width)x\(height) on \(device.name): whole p50 \(String(format: "%.2f", steadiest({ $0.frames }, 0.5))) ms, p95 \(String(format: "%.2f", steadiest({ $0.frames }, 0.95))) ms (passes \(each)); GPU p50 \(String(format: "%.2f", steadiest({ $0.gpu }, 0.5))) ms")
        // The GPU's time is within the whole frame's.
        XCTAssertLessThanOrEqual(steadiest({ $0.gpu }, 0.5), steadiest({ $0.frames }, 0.5) + 0.5)
    }
}
