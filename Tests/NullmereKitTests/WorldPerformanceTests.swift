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

    /// A realm of forty-eight seats, its lake twice as wide and its land's
    /// furniture four times the realm proper's, every hex known: near, the
    /// frame draws only the regions in view, and takes no longer than the
    /// whole land drawn, as it was before, which is measured beside it.
    /// One of ninety-six seats, its lake wider again and its land twice
    /// that, draws its frame near in about the time the forty-eight's does:
    /// what a frame costs is what is in view, not how wide the realm is.
    func testAWideRealmDrawsOnlyWhatItSees() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("No Metal device available") }
        let library = try device.makeLibrary(source: WorldShaders.source, options: nil)
        let renderer = try WorldRenderer(device: device, library: library, pixelFormat: .bgra8Unorm)
        renderer.meshSource = { Library.model($0).mesh }
        let wide = try measureNear(seats: 48, seed: "a wide realm drawn", wholeToo: true, renderer: renderer)
        let culledMedian = wide.culled, wholeMedian = try XCTUnwrap(wide.whole)
        print("PERFMETRIC wide.gpu.scale28.p50 \(String(format: "%.3f", culledMedian))")
        print("PERFMETRIC wide.gpu.scale28.whole.p50 \(String(format: "%.3f", wholeMedian))")
        print("PERF a realm of 48 seats near on \(device.name): \(String(format: "%.2f", culledMedian)) ms drawing what is in view, "
              + "\(String(format: "%.2f", wholeMedian)) ms drawing the whole land")
        XCTAssertLessThanOrEqual(culledMedian, wholeMedian * 1.1 + 0.5, "Drawing what is in view costs no more than drawing it all")

        let wider = try measureNear(seats: 96, seed: "a wider realm drawn", wholeToo: false, renderer: renderer)
        print("PERFMETRIC wider.gpu.scale28.p50 \(String(format: "%.3f", wider.culled))")
        print("PERF a realm of 96 seats near on \(device.name): \(String(format: "%.2f", wider.culled)) ms drawing what is in view")
        XCTAssertLessThanOrEqual(wider.culled, culledMedian * 1.25 + 1, "A realm twice as wide costs a frame near what the narrower does")
        XCTAssertLessThan(wider.culled, 16.7, "and well inside one")
    }

    /// The GPU's median time for a frame near a realm's seat, every hex
    /// known, drawing only the regions in view; and, `wholeToo`, drawing
    /// the whole land, as was done before.
    private func measureNear(seats: Int, seed: String, wholeToo: Bool, renderer: WorldRenderer) throws -> (culled: Double, whole: Double?) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: seats, radius: RealmState.radius(forSeats: seats), keepers: 1))
        state.houses[state.player].explored = Array(repeating: true, count: state.map.count)
        try renderer.setLand(TerrainMesh.shared(for: state.map), for: state.map)
        try renderer.updateTiles(TileTexture.bytes(for: state, viewer: state.player), side: TileTexture.side(for: state.map))
        let terrain = try XCTUnwrap(renderer.land).terrain
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        var culled = SceneFrame()
        culled.fixed = stage.furnish(occupied: [], holds: Set(state.holds.map(\.position)))
        culled.fixedVersion = stage.furnitureVersion
        culled.fixedRegions = stage.furnitureRegions
        XCTAssertNotNil(culled.fixedRegions)
        var whole = culled
        whole.fixedRegions = nil
        let seat = try XCTUnwrap(state.seat(of: state.player)).position
        let scale = 28.0
        let fraction = WorldMetalView.renderScale(forCameraScale: scale)
        let target = try renderer.makeTarget(width: Int((Double(Self.width) * fraction).rounded()),
                                             height: Int((Double(Self.height) * fraction).rounded()))
        var camera = Camera(scale: scale)
        camera.focus(on: seat)
        let size = CGSize(width: Double(Self.width) / 2, height: Double(Self.height) / 2)
        var medians: [String: Double] = [:]
        let scenes: [(String, SceneFrame)] = wholeToo ? [("culled", culled), ("whole", whole)] : [("culled", culled)]
        for (name, scene) in scenes {
            var times: [Double] = []
            for frame in 0..<85 {
                let uniforms = FrameUniforms.make(camera: camera, size: size, pixelsPerPoint: 2 * fraction, time: Float(3 + Double(frame) / 60),
                                                  motion: 1, radius: state.map.radius, terrain: terrain, hovered: nil, selected: nil,
                                                  houses: WorldView.houseColours)
                if let ms = renderer.measureFrame(uniforms, scene: scene, into: target) { times.append(ms) }
            }
            let settled = Array(times.dropFirst(5)).sorted()
            medians[name] = settled[settled.count / 2]
        }
        return (try XCTUnwrap(medians["culled"]), medians["whole"])
    }
}
