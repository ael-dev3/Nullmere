import Foundation

/// Each kind of company's mark, as the Mac's flat map strokes it on a
/// company's token and the phone strokes it beside the company's name: a
/// lantern's diamond, a spear's point, a bow drawn, a rider's chevrons, a
/// Mangonel's frame, wheel and arm, and a founder's house. Kept here as
/// strokes alone, so both draw the same marks.
public enum CompanyMarks {
    /// A stroke of a mark, in units of the mark's radius about its centre,
    /// y down.
    public enum Stroke: Equatable, Sendable {
        /// Lines through the points, closed back to the first if asked.
        case lines([StoreMarks.Point], closed: Bool)
        /// An arc about a centre, from one angle to another in degrees,
        /// turned clockwise or not as SwiftUI turns it.
        case arc(centre: StoreMarks.Point, radius: Double, from: Double, to: Double, clockwise: Bool)
        /// An ellipse in a box: its corner nearest the origin, and its size.
        case ellipse(x: Double, y: Double, width: Double, height: Double)
    }

    /// A kind of company's mark, stroke by stroke.
    public static func strokes(of kind: UnitKind) -> [Stroke] {
        func p(_ x: Double, _ y: Double) -> StoreMarks.Point { StoreMarks.Point(x, y) }
        switch kind {
        case .lantern:
            return [.lines([p(0, -1), p(0.7, 0), p(0, 1), p(-0.7, 0)], closed: true)]
        case .spear:
            return [.lines([p(0, 1), p(0, -1)], closed: false), .lines([p(-0.4, -0.45), p(0, -1), p(0.4, -0.45)], closed: false)]
        case .bow:
            return [.arc(centre: p(-0.3, 0), radius: 1, from: -60, to: 60, clockwise: false),
                    .lines([p(0.2, -0.87), p(0.2, 0.87)], closed: false)]
        case .rider:
            return [.lines([p(-1, 0.2), p(0, -0.6), p(1, 0.2)], closed: false), .lines([p(-1, 0.8), p(0, 0), p(1, 0.8)], closed: false)]
        case .mangonel:
            // A frame on its wheel, and its arm raised to throw.
            return [.lines([p(-1, 0.5), p(1, 0.5)], closed: false), .ellipse(x: -0.25, y: 0.5, width: 0.5, height: 0.5),
                    .lines([p(-0.3, 0.5), p(0.55, -0.9)], closed: false), .ellipse(x: 0.45, y: -1, width: 0.3, height: 0.3)]
        case .founder:
            return [.lines([p(-0.75, 0.7), p(-0.75, -0.1), p(0, -0.8), p(0.75, -0.1), p(0.75, 0.7)], closed: true)]
        }
    }
}
