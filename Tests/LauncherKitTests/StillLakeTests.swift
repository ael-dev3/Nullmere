import LauncherCore
import Metal
import XCTest
@testable import LauncherKit

/// The launcher's lake as the game means it: dead and deep, nearly still,
/// a black mirror holding the moon whole and the stars with it, under a sky
/// of bright stars. Measured on the lake's own shader.
final class StillLakeTests: XCTestCase {
    func testTheLakeIsABlackMirrorUnderBrightStars() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("No Metal device available") }
        let library = try device.makeLibrary(source: LakeShader.source, options: nil)
        let renderer = try LakeRenderer(device: device, library: library, pixelFormat: .bgra8Unorm)
        let width = 1512, height = 982
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        let target = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        var worst = (gathered: 1.0, filled: 1.0, heart: 765)
        var water = 0, bright = 0
        // Over several moments, so no lucky frame passes for a still lake.
        for time in [3.0, 7.5, 12.25, 20.0] {
            let uniforms = LakeUniforms(sizeAndPixels: SIMD4(Float(width), Float(height), Float(width), Float(height)),
                                        params: SIMD4(Float(time), 1, Float(LakeComposition.horizon), 0))
            XCTAssertNotNil(renderer.measureFrame(uniforms, into: target))
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            target.getBytes(&pixels, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            func light(_ x: Int, _ y: Int) -> Int {
                let i = (y * width + x) * 4
                return Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2])
            }
            // The moon's image in the water, straight below it, whole: its
            // light gathered in a disc the moon's size, not strewn down the
            // water in a broken column.
            let radius = LakeComposition.moonRadius * Double(height)
            let mirrorY = (1 - (2 * LakeComposition.horizon - LakeComposition.moonY)) * Double(height)
            let mirrorX = LakeComposition.moonX * Double(width)
            var inside = 0, outside = 0
            for y in Int(Double(height) * 0.55)..<height {
                for x in Int(mirrorX - 4 * radius)..<Int(mirrorX + 4 * radius) where light(x, y) > 200 {
                    let dx = Double(x) - mirrorX, dy = Double(y) - mirrorY
                    if dx * dx + dy * dy <= (1.25 * radius) * (1.25 * radius) { inside += 1 } else { outside += 1 }
                }
            }
            let gathered = Double(inside) / Double(max(inside + outside, 1))
            let filled = Double(inside) / (Double.pi * (1.25 * radius) * (1.25 * radius))
            worst = (min(worst.gathered, gathered), min(worst.filled, filled), min(worst.heart, light(Int(mirrorX), Int(mirrorY))))

            // Open water, away from the moon's image: black.
            var values: [Int] = []
            for y in stride(from: Int(Double(height) * 0.72), to: Int(Double(height) * 0.95), by: 3) {
                for x in stride(from: Int(Double(width) * 0.05), to: Int(Double(width) * 0.28), by: 3) { values.append(light(x, y)) }
            }
            water = max(water, values.sorted()[values.count / 2])

            // Bright stars in the sky above the moon's glare.
            var stars = 0
            for y in stride(from: Int(Double(height) * 0.04), to: Int(Double(height) * 0.32), by: 1) {
                for x in stride(from: 2, to: width / 3, by: 1) where light(x, y) > 250 {
                    let here = light(x, y)
                    if here >= light(x - 1, y), here >= light(x + 1, y), here >= light(x, y - 1), here > light(x, y + 1) { stars += 1 }
                }
            }
            bright = max(bright, stars)
        }
        print(String(format: "STILL the moon's image gathered %.2f, filled %.2f, heart %ld; open water %ld; bright stars %ld",
                     worst.gathered, worst.filled, worst.heart, water, bright))
        XCTAssertGreaterThan(worst.heart, 330, "The moon lies in the water")
        XCTAssertGreaterThan(worst.gathered, 0.97, "gathered in a disc, not strewn down the water")
        XCTAssertGreaterThan(worst.filled, 0.58, "and whole")
        XCTAssertLessThan(water, 40, "Open water is black")
        XCTAssertGreaterThanOrEqual(bright, 10, "Bright stars stand in the sky")
    }
}
