import AppKit
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// Each store's mark is drawn: a sheaf of grain, a fir for timber, a
/// dressed block of stone, a crystal of moonsalt, each in its own colour
/// and told apart by its shape too; and each thing a satchel holds, a
/// cache by its store's mark; kept with CI's screenshots as the top bar,
/// a cost and the satchel draw them.
@MainActor
final class ResourceGlyphTests: XCTestCase {
    func testEachStoreIsMarkedByAShapeOfItsOwnInItsColour() throws {
        var outlines: [[CGPoint]] = []
        for resource in Resource.allCases {
            let drawing = ResourceGlyph.drawing(of: resource)
            XCTAssertGreaterThanOrEqual(drawing.count, 3, "\(resource) drawn of parts, lit and shaded")
            for part in drawing {
                XCTAssertGreaterThanOrEqual(part.outline.count, 3, "\(resource): an outline, not a line")
                XCTAssertTrue(part.outline.allSatisfy { (0 ... 1).contains($0.x) && (0 ... 1).contains($0.y) }, "\(resource) within its square")
                for value in [part.colour.red, part.colour.green, part.colour.blue] {
                    XCTAssertTrue((0 ... 1).contains(value), "\(resource): a colour that can be shown")
                }
            }
            outlines.append(drawing.flatMap(\.outline))
            // Its brightest part in the resource's own colour.
            let base = ResourceGlyph.colour(of: resource)
            XCTAssertTrue(drawing.contains { $0.colour == base || ($0.colour.red >= base.red && $0.colour.green >= base.green) },
                          "\(resource) shown in its own colour")
        }
        XCTAssertEqual(Set(outlines.map { $0.map { "\($0.x),\($0.y)" }.joined(separator: ";") }).count, Resource.allCases.count,
                       "each store a shape of its own, told apart without its colour")
        // The satchel's things: each its own mark, a cache its store's.
        for kind in ItemKind.allCases {
            let drawing = ItemGlyph.drawing(of: kind)
            XCTAssertGreaterThanOrEqual(drawing.count, 3, "\(kind) drawn of parts")
            XCTAssertTrue(drawing.allSatisfy { part in
                part.outline.count >= 3 && part.outline.allSatisfy { (0 ... 1).contains($0.x) && (0 ... 1).contains($0.y) }
            }, "\(kind) within its square")
        }
        XCTAssertEqual(ItemGlyph.drawing(of: .stoneCache).flatMap(\.outline), ResourceGlyph.drawing(of: .stone).flatMap(\.outline),
                       "a cache marked as the store it holds")
        let kept = [ItemKind.hourglass, .wardStone, .mendingDraught].map { ItemGlyph.drawing(of: $0).flatMap(\.outline).map { "\($0.x),\($0.y)" }.joined() }
        XCTAssertEqual(Set(kept).count, 3, "the hourglass, the ward stone and the draught each its own")
        // As the top bar and a cost draw them, on the panels' dark.
        try CardShot.keep(HStack(spacing: 14) {
            ForEach(Resource.allCases, id: \.self) { resource in
                VStack(spacing: 8) {
                    ResourceGlyph(resource: resource, size: 12)
                    ResourceGlyph(resource: resource)
                }
            }
        }
        .padding(16).background(Palette.panel), as: "game-store-marks.png")
        try CardShot.keep(HStack(spacing: 12) {
            ForEach(ItemKind.allCases, id: \.self) { kind in ItemGlyph(kind: kind) }
        }
        .padding(16).background(Palette.panel), as: "game-satchel-marks.png")
    }
}
