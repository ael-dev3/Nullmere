import AppKit
import Metal
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit
import NullmereModels
import NullmereWorld

/// The interface's portraits: the world's own models drawn by its renderer
/// on a small stage, framed by their size, kept once drawn.
@MainActor
final class PortraitTests: XCTestCase {
    /// How many of a picture's pixels differ plainly from its corner's.
    private func drawnShare(of image: CGImage) -> Double {
        let side = image.width
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        let context = CGContext(data: &bytes, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        let corner = Array(bytes[0..<3])
        var differing = 0
        for pixel in stride(from: 0, to: bytes.count, by: 4) {
            let delta = (0..<3).map { abs(Int(bytes[pixel + $0]) - Int(corner[$0])) }.max() ?? 0
            if delta > 12 { differing += 1 }
        }
        return Double(differing) / Double(side * side)
    }

    func testTheModelsAreDrawnAsPortraits() throws {
        XCTAssertTrue(Portraits.shared.prepareNow(), "The stage is built where Metal draws")
        XCTAssertTrue(Portraits.shared.isReady)
        let red = Vec4(0.8, 0.2, 0.2, 1)
        let commander = try XCTUnwrap(Portraits.shared.image(of: .commander(variant: 2), colour: red))
        XCTAssertEqual(commander.width, Portraits.side)
        XCTAssertGreaterThan(drawnShare(of: commander), 0.08, "A commander stands in the picture")
        XCTAssertTrue(Portraits.shared.image(of: .commander(variant: 2), colour: red) === commander, "Kept once drawn")
        for key: ModelKey in [.keep(seat: true), .work(.granary, level: 2), .figure(.spear, tier: 3), .shrine(.moonwell), .walls(level: 2)] {
            let image = try XCTUnwrap(Portraits.shared.image(of: key), "\(key)")
            XCTAssertGreaterThan(drawnShare(of: image), 0.05, "\(key) fills some of its picture")
        }
        XCTAssertNil(Portraits.image(bgra: [1, 2, 3], side: 4), "Pixels that aren't a picture make none")

        // Framed by its size: looked at from above its middle, far enough to see it whole.
        let framing = Portraits.framing(low: Vec3(-0.1, 0, -0.1), high: Vec3(0.1, 0.4, 0.1), ground: 0.05)
        XCTAssertEqual(framing.target.y, 0.25, accuracy: 1e-5)
        XCTAssertGreaterThan(framing.eye.y, framing.target.y)
        let near = Portraits.framing(low: Vec3(-0.01, 0, -0.01), high: Vec3(0.01, 0.04, 0.01), ground: 0)
        XCTAssertLessThan((near.eye - near.target).length, (framing.eye - framing.target).length, "A small thing is looked at from nearer")

        // In a panel, for the eye alone.
        let renderer = ImageRenderer(content: Portrait(key: .figure(.bow, tier: 2), colour: red, size: 40).background(Color.black))
        XCTAssertNotNil(renderer.cgImage)
        let state = GameState(settings: GameSettings(seedText: "portraits", houseCount: 3, radius: 14, keepers: 1))
        XCTAssertNotNil(Portrait.colour(of: state.player, in: state))
        XCTAssertNil(Portrait.colour(of: 99, in: state))
    }

    func testTheStageIsBuiltAwayFromTheMainThreadWhenFirstAskedFor() {
        let portraits = Portraits()
        XCTAssertNil(portraits.image(of: .keep(seat: false)), "Not until the stage is built; asking begins it")
        let built = expectation(description: "the stage built")
        func check() {
            if portraits.isReady { built.fulfill() } else { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { check() } }
        }
        check()
        wait(for: [built], timeout: 60)
        XCTAssertNotNil(portraits.image(of: .keep(seat: false)))
        portraits.warm()
        XCTAssertTrue(portraits.prepareNow(), "Built already")
    }
}
