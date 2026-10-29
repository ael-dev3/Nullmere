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

    func testTheMoonIsWholeAboveAndSinksUnderAPanel() throws {
        let open = try paint(), veiled = try paint(veil: 1)
        let moonX = Int(LakeComposition.moonX * Double(width))
        let moonY = Int((1 - LakeComposition.moonY) * Double(height))
        let imageY = Int((1 - (2 * LakeComposition.horizon - LakeComposition.moonY)) * Double(height))
        XCTAssertGreaterThan(light(open, moonX, moonY), 650, "The moon")
        XCTAssertGreaterThan(light(open, moonX, imageY), 450, "and its image in the water")
        XCTAssertEqual(light(veiled, moonX, moonY), light(open, moonX, moonY), accuracy: 3, "The moon stays under a panel")
        XCTAssertLessThan(light(veiled, moonX, imageY), 120, "its image sinks")
    }
}
