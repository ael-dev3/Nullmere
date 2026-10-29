import LauncherCore
import Metal
import XCTest
@testable import LauncherKit

/// How long the GPU takes to draw the lake at a 14-inch MacBook Pro's
/// native resolution. Prints the time for the record; fails if a frame
/// would not fit a 60 Hz display's budget.
final class LakePerformanceTests: XCTestCase {
    static let width = 3024
    static let height = 1964

    func testTheLakeFitsAFrameAtSixtyHertz() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("No Metal device available") }
        let library = try device.makeLibrary(source: LakeShader.source, options: nil)
        let renderer = try LakeRenderer(device: device, library: library, pixelFormat: .bgra8Unorm)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: Self.width, height: Self.height, mipmapped: false
        )
        descriptor.usage = .renderTarget
        descriptor.storageMode = .private
        let target = try XCTUnwrap(device.makeTexture(descriptor: descriptor))

        // Two hundred and forty frames once it has settled, so the worst
        // twentieth is a dozen frames, not the few a shared GPU's hiccup
        // can spoil.
        var times: [Double] = []
        for frame in 0..<245 {
            let uniforms = LakeUniforms(
                sizeAndPixels: SIMD4(Float(Self.width) / 2, Float(Self.height) / 2, Float(Self.width), Float(Self.height)),
                params: SIMD4(Float(4 + Double(frame) / 60), 1, Float(LakeComposition.horizon), 0)
            )
            if let ms = renderer.measureFrame(uniforms, into: target) { times.append(ms) }
        }
        let settled = times.dropFirst(5).sorted()
        let median = settled[settled.count / 2]
        print("PERFMETRIC lake.gpu.p50 \(String(format: "%.3f", median))")
        print("PERFMETRIC lake.gpu.p95 \(String(format: "%.3f", settled[min(settled.count - 1, Int(Double(settled.count) * 0.95))]))")
        print("PERF lake \(Self.width)x\(Self.height) on \(device.name): median \(String(format: "%.2f", median)) ms, worst \(String(format: "%.2f", times.dropFirst(5).max() ?? 0)) ms")
        XCTAssertLessThan(median, 1000.0 / 60, "The lake must fit a 60 Hz frame")
    }
}
