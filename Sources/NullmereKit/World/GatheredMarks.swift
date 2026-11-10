import SwiftUI

/// Marks of one kind gathered by where they stand: one path for each square
/// of the view a mark's token stands in, per style (a House's colour, a
/// rim's width), so each path is drawn for the few marks in one place rather
/// than one path across the whole view.
///
/// Why: drawn one path a colour across the view (2c9bc36), the marks timed
/// more than they did drawn a stroke a mark: run 939 timed them over the
/// models at 7.91 ms and flat at 16.29, where run 933, a stroke a mark, timed
/// 2.98 and 6.25. The model behind the squares is that a path's cost follows
/// the area its bounds cover, so a square covers little beyond its marks and
/// each square's marks share one draw. That is not yet measured on the
/// runner: the `shapes.*` lines of OverlayPerformanceTests time the same
/// shapes as one path, as a path for each square and as a fill for each, so
/// a run shows which holds up.
struct GatheredMarks {
    /// The side of the squares, in the view's points: three or four
    /// tokens across at the scales the marks are drawn at.
    static let cell: CGFloat = 128

    private(set) var paths: [Int: Path] = [:]

    var isEmpty: Bool { paths.isEmpty }

    /// The key of a style's square at a point: the style, then the row and
    /// the column, so the styles are drawn in their order. Two cells above
    /// and to the left of the view's origin count from zero, so the marks
    /// drawn just beyond the view stay in their squares; the far edges
    /// share the last.
    static func key(_ style: Int, at point: CGPoint) -> Int {
        func index(_ value: CGFloat) -> Int {
            guard value.isFinite else { return 0 }
            return Int(min(max((value / cell).rounded(.down) + 2, 0), 255))
        }
        return max(style, 0) << 16 | index(point.y) << 8 | index(point.x)
    }

    /// The style a key was made with.
    static func style(of key: Int) -> Int { key >> 16 }

    /// Adds to the path of a style's square, the square of the point its
    /// token stands at.
    mutating func add(_ style: Int = 0, at point: CGPoint, _ make: (inout Path) -> Void) {
        make(&paths[GatheredMarks.key(style, at: point), default: Path()])
    }

    /// Each path with its style, the styles in their order.
    func each(_ body: (_ style: Int, _ path: Path) -> Void) {
        for key in paths.keys.sorted() {
            if let path = paths[key] { body(GatheredMarks.style(of: key), path) }
        }
    }
}
