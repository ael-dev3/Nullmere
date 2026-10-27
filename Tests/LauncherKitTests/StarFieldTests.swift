import LauncherCore
import Metal
import XCTest
@testable import LauncherKit

/// The launcher's sky holds its stars as the night does, by chance: no
/// lattice of rows or columns shows through. Measured on the lake's own
/// shader by how strongly the stars' rows and columns repeat at any spacing,
/// against what scattered stars give.
final class StarFieldTests: XCTestCase {
    /// The strongest repeat in a series, after taking out its slow trend:
    /// near 0.15 for scattered stars, near 1 for a lattice.
    static func strongestRepeat(_ series: [Double]) -> (strength: Double, spacing: Int) {
        let n = series.count
        var detrended = [Double](repeating: 0, count: n)
        for i in 0..<n {
            let lo = max(0, i - 15), hi = min(n, i + 16)
            detrended[i] = series[i] - series[lo..<hi].reduce(0, +) / Double(hi - lo)
        }
        let variance = max(detrended.reduce(0) { $0 + $1 * $1 }, 1e-9)
        var best = (strength: -1.0, spacing: 0)
        for lag in 6..<min(60, n / 2) {
            var sum = 0.0
            for i in 0..<(n - lag) { sum += detrended[i] * detrended[i + lag] }
            if sum / variance > best.strength { best = (sum / variance, lag) }
        }
        return best
    }

    func testTheMeasureKnowsALatticeFromScatter() {
        var lattice = [Double](repeating: 0, count: 300)
        for i in stride(from: 0, to: 300, by: 13) { lattice[i] = 5 }
        XCTAssertGreaterThan(Self.strongestRepeat(lattice).strength, 0.8)
        var generator = SystemRandomNumberGenerator()
        let scatter = (0..<300).map { _ in Double(Int.random(in: 0..<5, using: &generator) == 0 ? 3 : 0) }
        XCTAssertLessThan(Self.strongestRepeat(scatter).strength, 0.4)
    }

    func testTheSkyShowsNoLattice() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("No Metal device available") }
        let library = try device.makeLibrary(source: LakeShader.source, options: nil)
        let renderer = try LakeRenderer(device: device, library: library, pixelFormat: .bgra8Unorm)
        let width = 1512, height = 982
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        let target = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let uniforms = LakeUniforms(sizeAndPixels: SIMD4(Float(width), Float(height), Float(width), Float(height)),
                                    params: SIMD4(4, 1, Float(LakeComposition.horizon), 0))
        XCTAssertNotNil(renderer.measureFrame(uniforms, into: target))
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        target.getBytes(&pixels, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)

        // The sky's upper left, clear of the moon and the shore.
        let xs = Int(Double(width) * 0.02)..<Int(Double(width) * 0.40)
        let ys = Int(Double(height) * 0.06)..<Int(Double(height) * 0.30)
        func light(_ x: Int, _ y: Int) -> Int {
            let i = (y * width + x) * 4
            return Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2])
        }
        var values: [Int] = []
        for y in ys { for x in xs { values.append(light(x, y)) } }
        let median = values.sorted()[values.count / 2]
        var columns = [Double](repeating: 0, count: xs.count), rows = [Double](repeating: 0, count: ys.count)
        var stars = 0
        for (row, y) in ys.enumerated() {
            for (column, x) in xs.enumerated() where light(x, y) > median + 24 {
                columns[column] += 1
                rows[row] += 1
                stars += 1
            }
        }
        let across = Self.strongestRepeat(columns), down = Self.strongestRepeat(rows)
        print(String(format: "STARS %ld star pixels; strongest repeat across %.2f at %ld px, down %.2f at %ld px",
                     stars, across.strength, across.spacing, down.strength, down.spacing))
        XCTAssertGreaterThan(stars, 200, "Stars in the sky")
        XCTAssertLessThan(across.strength, 0.35, "No columns of stars")
        XCTAssertLessThan(down.strength, 0.35, "No rows of stars")
    }
}
