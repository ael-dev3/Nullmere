import Foundation

/// The four stores' marks, as the Mac's top bar and the phone's House tab
/// draw them beside each figure: a sheaf of grain, a fir of the blackwood
/// for timber, a dressed block of stone and a crystal of moonsalt, each lit
/// from above and the left, so each is told by its shape as well as its
/// colour at the size of a word. Kept here, as outlines alone, so both
/// draw the same marks.
public enum StoreMarks {
    /// A colour, its red, green and blue each from 0 to 1.
    public typealias Shade = (red: Double, green: Double, blue: Double)

    /// A point of an outline in the mark's unit square, y down.
    public struct Point: Equatable, Sendable {
        public let x: Double
        public let y: Double

        public init(_ x: Double, _ y: Double) {
            self.x = x
            self.y = y
        }
    }

    /// One filled outline of a mark, and its shade.
    public typealias Part = (outline: [Point], colour: Shade)

    /// Each store's colour, as its stores, gains and costs are marked.
    public static func colour(of resource: Resource) -> Shade {
        switch resource {
        case .grain: return (0.84, 0.76, 0.52)
        case .timber: return (0.42, 0.55, 0.44)
        case .stone: return (0.62, 0.60, 0.58)
        case .moonsalt: return (0.80, 0.86, 1.0)
        }
    }

    /// A store's mark as filled outlines in a unit square, y down, each
    /// drawn over those before it, with its shade of the store's colour.
    public static func drawing(of resource: Resource) -> [Part] {
        let base = colour(of: resource)
        func lit(_ k: Double) -> Shade { (min(base.red * k, 1), min(base.green * k, 1), min(base.blue * k, 1)) }
        func p(_ x: Double, _ y: Double) -> Point { Point(x, y) }
        switch resource {
        case .grain:
            // Three stalks bound at the middle, an ear at each head.
            let tie = p(0.5, 0.64)
            var parts: [Part] = []
            for (head, foot) in [(p(0.24, 0.16), p(0.36, 0.97)), (p(0.76, 0.16), p(0.64, 0.97)), (p(0.5, 0.06), p(0.5, 0.99))] {
                parts.append((stalk(from: foot, to: tie, width: 0.07), lit(0.8)))
                parts.append((stalk(from: tie, to: head, width: 0.07), lit(0.8)))
                let angle = atan2(head.y - tie.y, head.x - tie.x)
                parts.append((ear(at: p(head.x - 0.13 * cos(angle), head.y - 0.13 * sin(angle)), along: angle), base))
            }
            parts.append(([p(0.36, 0.6), p(0.64, 0.6), p(0.64, 0.69), p(0.36, 0.69)], lit(0.6)))
            return parts
        case .timber:
            // A fir in three tiers on its trunk, darker toward the ground.
            return [([p(0.44, 0.8), p(0.56, 0.8), p(0.56, 1), p(0.44, 1)], (0.43, 0.35, 0.26)),
                    ([p(0.5, 0.42), p(0.06, 0.86), p(0.94, 0.86)], lit(0.8)),
                    ([p(0.5, 0.22), p(0.14, 0.64), p(0.86, 0.64)], lit(0.95)),
                    ([p(0.5, 0.02), p(0.22, 0.42), p(0.78, 0.42)], lit(1.12))]
        case .stone:
            // A dressed block seen from above a corner: its top in the light.
            let top = p(0.5, 0.1), right = p(0.92, 0.33), foot = p(0.5, 0.94), left = p(0.08, 0.33)
            let heart = p(0.5, 0.56), rightFoot = p(0.92, 0.72), leftFoot = p(0.08, 0.72)
            return [([top, right, heart, left], lit(1.18)), ([left, heart, foot, leftFoot], lit(0.95)),
                    ([heart, right, rightFoot, foot], lit(0.72))]
        case .moonsalt:
            // A crystal of six faces, its crown catching the moon.
            let top = p(0.5, 0.02), upperRight = p(0.8, 0.3), lowerRight = p(0.8, 0.72), foot = p(0.5, 0.98)
            let lowerLeft = p(0.2, 0.72), upperLeft = p(0.2, 0.3), crown = p(0.5, 0.2), heel = p(0.5, 0.82)
            return [([top, upperRight, crown, upperLeft], base), ([upperLeft, crown, heel, lowerLeft], lit(0.86)),
                    ([crown, upperRight, lowerRight, heel], lit(0.68)), ([lowerLeft, heel, foot], lit(0.78)),
                    ([heel, lowerRight, foot], lit(0.58))]
        }
    }

    /// A stalk from `a` to `b`, `width` across.
    private static func stalk(from a: Point, to b: Point, width: Double) -> [Point] {
        let dx = b.x - a.x, dy = b.y - a.y, length = (dx * dx + dy * dy).squareRoot()
        let nx = -dy / length * width / 2, ny = dx / length * width / 2
        return [Point(a.x + nx, a.y + ny), Point(b.x + nx, b.y + ny), Point(b.x - nx, b.y - ny), Point(a.x - nx, a.y - ny)]
    }

    /// An ear of grain about `centre`, laid along `angle`.
    private static func ear(at centre: Point, along angle: Double) -> [Point] {
        (0..<24).map { index in
            let t = 2 * Double.pi * Double(index) / 24
            let x = 0.17 * cos(t), y = 0.085 * sin(t)
            return Point(centre.x + x * cos(angle) - y * sin(angle), centre.y + x * sin(angle) + y * cos(angle))
        }
    }
}
