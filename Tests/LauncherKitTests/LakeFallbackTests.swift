import AppKit
import LauncherCore
import SwiftUI
import XCTest
@testable import LauncherKit

/// The lake drawn without Metal keeps the scene's shape: the far shore's
/// mesas stand dark against the sky and lie mirrored in the water, the
/// moon whole above and in the water below, and no taller than the Metal
/// lake draws them.
@MainActor
final class LakeFallbackTests: XCTestCase {
    private let width = 960, height = 600

    private func paint(veil: Double = 0) throws -> [UInt8] {
        let renderer = ImageRenderer(content: LakeFallbackView(horizon: LakeComposition.horizon, veil: veil)
            .frame(width: CGFloat(width), height: CGFloat(height)))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    private func light(_ pixels: [UInt8], _ x: Int, _ y: Int) -> Int {
        let i = (y * width + x) * 4
        return Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2])
    }

    func testTheFarShoreStandsAndLiesMirrored() throws {
        let pixels = try paint()
        let waterline = Double(height) * (1 - LakeComposition.horizon)
        var shore = 0, mirrored = 0
        for x in stride(from: 4, to: width - 4, by: 8) {
            let rise = LakeFallbackView.mesas(Double(x) / Double(width), aspect: Double(width) / Double(height)) * Double(height)
            XCTAssertLessThanOrEqual(rise / Double(height), LakeShore.tallest, "No higher than the Metal lake's tallest mesa")
            guard rise > 8 else { continue }
            // Halfway up the shore, and halfway down its image.
            let above = light(pixels, x, Int(waterline - rise / 2)), below = light(pixels, x, Int(waterline + rise / 2))
            // Just above its top: the sky.
            let sky = light(pixels, x, Int(waterline - rise - 4))
            if above < sky { shore += 1 }
            if below < 45 { mirrored += 1 }
        }
        XCTAssertGreaterThan(shore, 20, "The mesas stand dark against the sky")
        XCTAssertGreaterThan(mirrored, 20, "and lie mirrored in the water")
    }

    func testTheMoonIsWholeAboveAndDimsUnderAPanel() throws {
        let open = try paint(), veiled = try paint(veil: 1)
        let moonX = Int(LakeComposition.moonX * Double(width))
        let moonY = Int((1 - LakeComposition.moonY) * Double(height))
        let imageY = Int((1 - (2 * LakeComposition.horizon - LakeComposition.moonY)) * Double(height))
        // The Metal lake's moon is 620 to 640 at its heart, its seas and all.
        XCTAssertGreaterThan(light(open, moonX, moonY), 580, "The moon")
        XCTAssertGreaterThan(light(open, moonX, imageY), 450, "and its image in the water")
        XCTAssertEqual(light(veiled, moonX, moonY), light(open, moonX, moonY), accuracy: 3, "The moon stays under a panel")
        XCTAssertLessThan(light(veiled, moonX, imageY), light(open, moonX, imageY) * 4 / 10, "its image dims")
        XCTAssertGreaterThan(light(veiled, moonX, imageY), light(open, moonX, imageY) / 12, "but is never gone")
    }

    /// Without Metal the moon wears the shader's face: its seas and grain
    /// from the same noise, its limb darker than its heart, its one bright
    /// crater, and its image in the water upside down.
    func testTheMoonWithoutMetalWearsTheShadersFace() throws {
        // As the shader shades these points, its noise worked out apart in
        // single precision.
        XCTAssertEqual(MoonFace.shade(0, 0), 0.8597, accuracy: 0.0005)
        XCTAssertEqual(MoonFace.shade(0, 0.5), 0.8529, accuracy: 0.0005)
        XCTAssertEqual(MoonFace.shade(0, -0.5), 0.8983, accuracy: 0.0005)
        XCTAssertEqual(MoonFace.shade(0.3, 0.3), 0.9698, accuracy: 0.0005)
        XCTAssertLessThan(MoonFace.shade(0.97, 0), MoonFace.shade(0.3, 0.3), "Its limb darker")
        XCTAssertEqual(MoonFace.crater(-0.18, -0.62), 0.06, accuracy: 0.0001, "Its one bright crater")

        let side = 64
        func pixels(_ image: CGImage) throws -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: side * side * 4)
            let context = try XCTUnwrap(CGContext(data: &bytes, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return bytes
        }
        let face = try pixels(XCTUnwrap(LakeFallbackView.moonFace(diameter: side)))
        let image = try pixels(XCTUnwrap(LakeFallbackView.moonFace(diameter: side, mirrored: true)))
        func value(_ bytes: [UInt8], _ x: Int, _ y: Int) -> Int { Int(bytes[(y * side + x) * 4]) }
        XCTAssertEqual(value(face, 0, 0), 0, "Nothing outside the disc")
        var seas = Set<Int>()
        for y in stride(from: 12, to: 52, by: 4) {
            for x in stride(from: 12, to: 52, by: 4) {
                XCTAssertEqual(value(face, x, y), value(image, x, side - 1 - y), "Given back upside down")
                seas.insert(value(face, x, y) / 4)
            }
        }
        XCTAssertGreaterThan(seas.count, 4, "Seas and grain, not a flat coin")
    }
}
