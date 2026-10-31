import SwiftUI
import XCTest
@testable import NullmereKit

/// The map's marks gathered by look: many of one look go as one path, and
/// whatever order they were gathered in, they stack layer by layer, under
/// to over, as each token would drawn alone.
@MainActor
final class MarkBatchTests: XCTestCase {
    func testMarksOfOneLookGoAsOnePath() {
        var batch = MarkBatch()
        for index in 0..<50 {
            let shield = Path(ellipseIn: CGRect(x: CGFloat(index) * 10, y: 0, width: 8, height: 8))
            batch.add(shield, .shields, WorldMarks.shieldFace, .fill)
            batch.add(shield, .rims, index.isMultiple(of: 2) ? Palette.good : Palette.bad, .stroke(1.3))
        }
        XCTAssertEqual(batch.count, 3, "A hundred marks, three paths: the faces, and the rims in each colour")
        batch.add(Path(CGRect(x: 0, y: 0, width: 4, height: 4)), .rims, Palette.good, .stroke(2.2))
        XCTAssertEqual(batch.count, 4, "A rim of another width is another look")
        batch.add(Path(CGRect(x: 0, y: 0, width: 4, height: 4)), .glyphs, Palette.good, .stroke(1.3))
        XCTAssertEqual(batch.count, 5, "and one in another layer another again")
    }

    func testTheyStackLayerByLayerWhateverOrderTheyCameIn() throws {
        var batch = MarkBatch()
        let square = Path(CGRect(x: 0, y: 0, width: 40, height: 40))
        let red = Color(red: 1, green: 0, blue: 0), blue = Color(red: 0, green: 0, blue: 1), green = Color(red: 0, green: 1, blue: 0)
        // A keep gathered before the tower under it still stands over it.
        batch.add(square, .keeps, red, .fill)
        batch.add(square, .towers, blue, .fill)
        // A bar over everything, and a warning broken along its way under it all.
        var bar = Path()
        bar.move(to: CGPoint(x: 0, y: 5))
        bar.addLine(to: CGPoint(x: 40, y: 5))
        batch.add(bar, .bar, green, .stroke(3))
        var warning = Path()
        warning.move(to: CGPoint(x: 0, y: 30))
        warning.addLine(to: CGPoint(x: 40, y: 30))
        batch.add(warning, .warning, green, .dashed(3))
        let drawn = batch
        let renderer = ImageRenderer(content: Canvas { context, _ in drawn.draw(in: &context) }.frame(width: 40, height: 40))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        let keep = rgba(of: image, x: 20, y: 20)
        XCTAssertGreaterThan(keep.red, 200, "The keep over the tower")
        XCTAssertLessThan(keep.blue, 60)
        let over = rgba(of: image, x: 20, y: 5)
        XCTAssertGreaterThan(over.green, 200, "The bar over the keep")
        let under = rgba(of: image, x: 2, y: 30)
        XCTAssertGreaterThan(under.red, 200, "The warning under the keep, broken or not")
        XCTAssertLessThan(under.green, 60)
    }

    /// One pixel of an image, its top row first.
    private func rgba(of image: CGImage, x: Int, y: Int) -> (red: UInt8, green: UInt8, blue: UInt8) {
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes { raw in
            guard let context = CGContext(data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        let at = (y * width + x) * 4
        return (bytes[at], bytes[at + 1], bytes[at + 2])
    }
}
