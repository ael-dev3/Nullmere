import Foundation
import XCTest
@testable import NullmereCore

/// Each kind of company's mark, stroked alike by the Mac's flat map and the
/// phone: strokes within the mark's radius, each kind told by its own.
final class CompanyMarksTests: XCTestCase {
    func testEachKindHasAMarkOfItsOwnWithinItsRadius() {
        var marks: [[CompanyMarks.Stroke]] = []
        for kind in UnitKind.allCases {
            let strokes = CompanyMarks.strokes(of: kind)
            XCTAssertFalse(strokes.isEmpty, "\(kind)")
            for stroke in strokes {
                switch stroke {
                case .lines(let points, _):
                    XCTAssertGreaterThanOrEqual(points.count, 2, "\(kind): a line, not a point")
                    XCTAssertTrue(points.allSatisfy { abs($0.x) <= 1 && abs($0.y) <= 1 }, "\(kind) within its radius")
                case .arc(let centre, let radius, let from, let to, _):
                    XCTAssertLessThanOrEqual(hypot(centre.x, centre.y) + radius, 1.31, "\(kind)'s arc near its radius")
                    XCTAssertNotEqual(from, to)
                case .ellipse(let x, let y, let width, let height):
                    XCTAssertTrue(width > 0 && height > 0 && x >= -1 && y >= -1 && x + width <= 1 && y + height <= 1, "\(kind)")
                }
            }
            XCTAssertFalse(marks.contains(strokes), "\(kind) told by its own mark")
            marks.append(strokes)
        }
    }
}
