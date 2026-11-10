import Foundation
import XCTest
@testable import NullmereCore

/// The stores' marks the Mac and the phone both draw: each store's outlines
/// within the unit square, its shades true colours, and each store told by
/// its own shape.
final class StoreMarksTests: XCTestCase {
    func testEachStoreHasAMarkOfItsOwnWithinItsSquare() {
        var shapes: [[StoreMarks.Point]] = []
        for resource in Resource.allCases {
            let drawing = StoreMarks.drawing(of: resource)
            XCTAssertFalse(drawing.isEmpty, "\(resource)")
            for part in drawing {
                XCTAssertGreaterThanOrEqual(part.outline.count, 3, "an outline to fill: \(resource)")
                for point in part.outline {
                    XCTAssertTrue((-0.01...1.01).contains(point.x) && (-0.01...1.01).contains(point.y), "\(resource) \(point)")
                }
                for channel in [part.colour.red, part.colour.green, part.colour.blue] {
                    XCTAssertTrue((0...1).contains(channel), "\(resource) shade \(channel)")
                }
            }
            shapes.append(drawing.flatMap(\.outline))
        }
        XCTAssertEqual(Set(shapes.map { $0.map { "\($0.x),\($0.y)" }.joined(separator: ";") }).count, Resource.allCases.count,
                       "each store told by its shape")
        // The grain's ears are its own colour, lit no further.
        let grain = StoreMarks.colour(of: .grain)
        XCTAssertTrue(StoreMarks.drawing(of: .grain).contains { $0.colour == grain })
    }
}
