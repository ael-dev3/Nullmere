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
        var rim = (rough: 0.0, worst: 0.0)
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

            // Its rim clean, as on dead still water: the edge, found along 72
            // rays from its heart, strays little from the edge smoothed.
            let cut = Double(light(Int(mirrorX), Int(mirrorY))) * 0.6
            var rays: [Double] = []
            for k in 0..<72 {
                let angle = 2 * Double.pi * Double(k) / 72
                var r = 0.0
                while r < 2 * radius, Double(light(Int(mirrorX + r * cos(angle)), Int(mirrorY + r * sin(angle)))) > cut { r += 0.5 }
                rays.append(r)
            }
            let strays = rays.indices.map { i -> Double in
                let smooth = (-4...4).map { rays[(i + $0 + 72) % 72] }.reduce(0, +) / 9
                return abs(rays[i] - smooth) / radius
            }
            rim = (max(rim.rough, strays.reduce(0, +) / 72), max(rim.worst, strays.max() ?? 0))

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
        print(String(format: "STILL the moon's image's rim strays %.3f on average, %.3f at most", rim.rough, rim.worst))
        XCTAssertLessThan(rim.rough, 0.016, "Its rim clean, not bitten by ripples")
        XCTAssertLessThan(rim.worst, 0.055, "nowhere")
        XCTAssertLessThan(water, 40, "Open water is black")
        XCTAssertGreaterThanOrEqual(bright, 10, "Bright stars stand in the sky")
    }

    /// Under a panel the moon's image sinks into the water: gone from its
    /// place, while the moon in the sky and the stars on the water stay.
    func testAPanelSinksTheMoonsImageAndLeavesTheStars() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("No Metal device available") }
        let library = try device.makeLibrary(source: LakeShader.source, options: nil)
        let renderer = try LakeRenderer(device: device, library: library, pixelFormat: .bgra8Unorm)
        let width = 1512, height = 982
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        let target = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        func frame(veil: Float) -> [UInt8] {
            let uniforms = LakeUniforms(sizeAndPixels: SIMD4(Float(width), Float(height), Float(width), Float(height)),
                                        params: SIMD4(12.25, 0, Float(LakeComposition.horizon), veil))
            XCTAssertNotNil(renderer.measureFrame(uniforms, into: target))
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            target.getBytes(&pixels, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            return pixels
        }
        let whole = frame(veil: 0), sunk = frame(veil: 1)
        func light(_ pixels: [UInt8], _ x: Int, _ y: Int) -> Int {
            let i = (y * width + x) * 4
            return Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2])
        }
        let moonX = Int(LakeComposition.moonX * Double(width))
        let moonY = Int((1 - LakeComposition.moonY) * Double(height))
        let mirrorY = Int((1 - (2 * LakeComposition.horizon - LakeComposition.moonY)) * Double(height))
        // The dithering differs by a step at most.
        XCTAssertEqual(light(sunk, moonX, moonY), light(whole, moonX, moonY), accuracy: 6, "The moon in the sky stays")
        XCTAssertGreaterThan(light(whole, moonX, mirrorY), 330)
        XCTAssertLessThan(light(sunk, moonX, mirrorY), 30, "Its image is gone")

        // Stars on the open water, away from the moon's image, in both. A
        // star is a point that stands out from the water around it: the
        // moon's halo, gone with its image, lit the water and its stars
        // alike, so how bright a point is can't tell a star.
        func stars(_ pixels: [UInt8], standingOut contrast: Int) -> [(x: Int, y: Int)] {
            var found: [(x: Int, y: Int)] = []
            for y in stride(from: Int(Double(height) * 0.62), to: Int(Double(height) * 0.95), by: 1) {
                for x in stride(from: 3, to: width / 3, by: 1) {
                    let here = light(pixels, x, y)
                    let around = (light(pixels, x - 3, y) + light(pixels, x + 3, y) + light(pixels, x, y - 3) + light(pixels, x, y + 3)) / 4
                    guard here - around > contrast else { continue }
                    if here >= light(pixels, x - 1, y), here >= light(pixels, x + 1, y), here >= light(pixels, x, y - 1), here > light(pixels, x, y + 1) {
                        found.append((x: x, y: y))
                    }
                }
            }
            return found
        }
        // Each star found in one is found in the other, where it was: by a
        // margin the dithering can't cross, give or take a pixel.
        func stillThere(_ stars: [(x: Int, y: Int)], among others: [(x: Int, y: Int)]) -> Int {
            stars.filter { star in !others.contains { abs($0.x - star.x) <= 1 && abs($0.y - star.y) <= 1 } }.count
        }
        let before = stars(whole, standingOut: 40), after = stars(sunk, standingOut: 40)
        print("STILL stars on the water: \(before.count) beside the moon's image, \(after.count) with it sunk")
        XCTAssertGreaterThan(before.count, 5, "Stars lie on the water")
        XCTAssertEqual(stillThere(before, among: stars(sunk, standingOut: 28)), 0, "and stay when the moon's image sinks")
        XCTAssertEqual(stillThere(after, among: stars(whole, standingOut: 28)), 0, "and none appear that weren't there")
    }
}
