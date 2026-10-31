import Foundation
@testable import NullmereWorld
import XCTest

/// The world's pictures painted for the interface: strokes that keep to
/// the forms, ink along the edges, a canvas under it all.
final class PaintingTests: XCTestCase {
    /// An opaque picture, each pixel's blue, green and red from its place.
    static func picture(_ width: Int, _ height: Int, alpha: UInt8 = 255,
                        _ colour: (Int, Int) -> (UInt8, UInt8, UInt8)) -> [UInt8] {
        var pixels: [UInt8] = []
        for y in 0..<height {
            for x in 0..<width {
                let (b, g, r) = colour(x, y)
                pixels += [b, g, r, alpha]
            }
        }
        return pixels
    }

    /// How far a picture's blues stray from their mean, on average.
    static func spread(_ pixels: [UInt8]) -> Double {
        let blues = stride(from: 0, to: pixels.count, by: 4).map { Double(pixels[$0]) }
        let mean = blues.reduce(0, +) / Double(blues.count)
        return blues.reduce(0) { $0 + abs($1 - mean) } / Double(blues.count)
    }

    func testStrokesKeepFlatFieldsAndSharpEdgesAndCalmTheNoise() {
        var flat = PaintingTests.picture(16, 16) { _, _ in (40, 90, 160) }
        let before = flat
        Painting.strokes(bgra: &flat, width: 16, height: 16, reach: 2)
        XCTAssertEqual(flat, before, "A flat field as it was")
        var edge = PaintingTests.picture(16, 16) { x, _ in x < 8 ? (20, 20, 20) : (220, 220, 220) }
        Painting.strokes(bgra: &edge, width: 16, height: 16, reach: 2)
        for y in 0..<16 {
            XCTAssertEqual(edge[(y * 16 + 7) * 4], 20, "The dark side stays dark to the edge")
            XCTAssertEqual(edge[(y * 16 + 8) * 4], 220, "The light side stays light from it")
        }
        var noisy = PaintingTests.picture(32, 32) { x, y in
            let value = UInt8(100 + Int(Painting.grain(x, y) * 60))
            return (value, value, value)
        }
        let rough = PaintingTests.spread(noisy)
        Painting.strokes(bgra: &noisy, width: 32, height: 32, reach: 2)
        XCTAssertLessThan(PaintingTests.spread(noisy), rough * 0.7, "Fine noise laid down in strokes")
        // Nothing to stroke with: as it was.
        var kept = edge
        Painting.strokes(bgra: &kept, width: 16, height: 16, reach: 0)
        XCTAssertEqual(kept, edge)
    }

    func testInkDarkensTheEdgesAlone() {
        let edge = PaintingTests.picture(16, 16) { x, _ in x < 8 ? (60, 60, 60) : (220, 220, 220) }
        var inked = edge
        Painting.ink(bgra: &inked, width: 16, height: 16)
        XCTAssertLessThan(inked[(4 * 16 + 8) * 4], 220, "Ink along the edge's light side")
        XCTAssertLessThan(inked[(4 * 16 + 7) * 4], 60, "And its dark side")
        XCTAssertEqual(inked[(4 * 16 + 14) * 4], 220, "Far from it, none")
        XCTAssertEqual(inked[(4 * 16 + 1) * 4], 60)
        XCTAssertEqual(inked[(4 * 16 + 8) * 4 + 3], 255, "Alpha untouched")
        // Too small to have edges: as it was.
        var tiny = PaintingTests.picture(2, 2) { _, _ in (1, 2, 3) }
        Painting.ink(bgra: &tiny, width: 2, height: 2)
        XCTAssertEqual(tiny, PaintingTests.picture(2, 2) { _, _ in (1, 2, 3) })
    }

    func testTheCanvasWeavesAndShadesItsCorners() {
        var field = PaintingTests.picture(64, 64) { _, _ in (200, 200, 200) }
        Painting.canvas(bgra: &field, width: 64, height: 64)
        let centre = Int(field[(32 * 64 + 32) * 4]), corner = Int(field[0])
        XCTAssertLessThan(corner, centre, "The corners in shadow")
        let blues = stride(from: 0, to: field.count, by: 4).map { field[$0] }
        XCTAssertTrue(blues.allSatisfy { (166...234).contains($0) }, "No colour changed by more than a sixth")
        XCTAssertGreaterThan(Set(blues).count, 8, "The weave runs through it")
        // One pixel: shaded as a centre is, and no more than a sixth.
        var one: [UInt8] = [200, 200, 200, 255]
        Painting.canvas(bgra: &one, width: 1, height: 1)
        XCTAssertTrue((166...234).contains(one[0]))
    }

    func testPaintingKeepsAlphaAndLeavesWhatIsNotAPictureAlone() {
        var wrong: [UInt8] = [1, 2, 3, 4, 5]
        Painting.paint(bgra: &wrong, width: 2, height: 2)
        XCTAssertEqual(wrong, [1, 2, 3, 4, 5])
        Painting.canvas(bgra: &wrong, width: 2, height: 2)
        XCTAssertEqual(wrong, [1, 2, 3, 4, 5])
        var none: [UInt8] = []
        Painting.paint(bgra: &none, width: 0, height: 0)
        XCTAssertEqual(none, [])
        // Half seen: its alpha kept, its colour never above it.
        var half = PaintingTests.picture(24, 24, alpha: 128) { x, y in (UInt8(x * 5), UInt8(y * 5), 128) }
        Painting.paint(bgra: &half, width: 24, height: 24)
        for at in stride(from: 0, to: half.count, by: 4) {
            XCTAssertEqual(half[at + 3], 128)
            XCTAssertTrue(half[at..<(at + 3)].allSatisfy { $0 <= 128 })
        }
        // A portrait strokes finer than a vista.
        XCTAssertEqual(Painting.stroke(forWidth: 112), 1)
        XCTAssertEqual(Painting.stroke(forWidth: 360), 2)
        // A whole picture painted: changed, its edge still there.
        let scene = PaintingTests.picture(40, 30) { x, _ in x < 20 ? (40, 70, 30) : (210, 200, 180) }
        var painted = scene
        Painting.paint(bgra: &painted, width: 40, height: 30)
        XCTAssertNotEqual(painted, scene)
        XCTAssertLessThan(painted[(15 * 40 + 10) * 4 + 2], painted[(15 * 40 + 30) * 4 + 2])
    }

    /// Paints the pictures NULLMERE_PAINT_PREVIEW names ("in.ppm:out.ppm",
    /// binary PPM, pairs parted by commas), for looking at.
    func testPaintsAPreview() throws {
        guard let pairs = ProcessInfo.processInfo.environment["NULLMERE_PAINT_PREVIEW"] else { return }
        for pair in pairs.split(separator: ",") {
            let paths = pair.split(separator: ":").map(String.init)
            guard paths.count == 2 else { continue }
            let data = try Data(contentsOf: URL(fileURLWithPath: paths[0]))
            // The header: P6, width, height and 255, each followed by a space.
            var fields: [String] = [], at = 0, field = ""
            while fields.count < 4, at < data.count {
                let byte = data[at]
                at += 1
                if byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09 {
                    if !field.isEmpty { fields.append(field); field = "" }
                } else {
                    field.append(Character(UnicodeScalar(byte)))
                }
            }
            let width = try XCTUnwrap(Int(fields[1])), height = try XCTUnwrap(Int(fields[2]))
            var pixels: [UInt8] = []
            pixels.reserveCapacity(width * height * 4)
            for index in 0..<(width * height) {
                let rgb = at + index * 3
                pixels += [data[rgb + 2], data[rgb + 1], data[rgb], 255]
            }
            Painting.paint(bgra: &pixels, width: width, height: height)
            var out = Data("P6\n\(width) \(height)\n255\n".utf8)
            for index in 0..<(width * height) {
                out.append(contentsOf: [pixels[index * 4 + 2], pixels[index * 4 + 1], pixels[index * 4]])
            }
            try out.write(to: URL(fileURLWithPath: paths[1]))
        }
    }
}
