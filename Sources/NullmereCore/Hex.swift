/// A cell of the world's hex grid in axial coordinates, pointy-top.
///
/// `q` runs east and `r` south-east; the third cube coordinate is
/// `s = -q - r`. Ordering is row by row (`r`, then `q`), so anything that
/// walks hexes in sorted order is deterministic.
public struct Hex: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    public var q: Int
    public var r: Int

    public init(_ q: Int, _ r: Int) {
        self.q = q
        self.r = r
    }

    public static let origin = Hex(0, 0)

    public var s: Int { -q - r }

    /// The six neighbours' offsets, clockwise from east.
    public static let directions: [Hex] = [
        Hex(1, 0), Hex(1, -1), Hex(0, -1), Hex(-1, 0), Hex(-1, 1), Hex(0, 1),
    ]

    public var neighbors: [Hex] {
        Hex.directions.map { self + $0 }
    }

    public func distance(to other: Hex) -> Int {
        let dq = q - other.q
        let dr = r - other.r
        let ds = dq + dr
        return ((dq < 0 ? -dq : dq) + (dr < 0 ? -dr : dr) + (ds < 0 ? -ds : ds)) / 2
    }

    /// Distance from the origin.
    public var length: Int { distance(to: .origin) }

    /// The hexes exactly `radius` steps away, clockwise from the east.
    public func ring(_ radius: Int) -> [Hex] {
        guard radius > 0 else { return [self] }
        var result: [Hex] = []
        result.reserveCapacity(6 * radius)
        var cell = self + Hex.directions[4] * radius
        for side in 0..<6 {
            for _ in 0..<radius {
                result.append(cell)
                cell = cell + Hex.directions[side]
            }
        }
        return result
    }

    /// This hex and every hex within `radius` steps, as `spiral` holds
    /// them but row by row, none laid out: for those that ask of each
    /// what it is, not which comes first.
    @inline(__always)
    func forEach(within radius: Int, _ body: (Hex) -> Void) {
        let radius = max(radius, 0)
        for dr in -radius...radius {
            for dq in max(-radius, -dr - radius)...min(radius, radius - dr) {
                body(Hex(q + dq, r + dr))
            }
        }
    }

    /// This hex and every hex within `radius` steps, nearest first.
    public func spiral(_ radius: Int) -> [Hex] {
        var result = [self]
        guard radius > 0 else { return result }
        result.reserveCapacity(1 + 3 * radius * (radius + 1))
        // Ring by ring, as `ring` walks each, laid into the one array.
        for step in 1...radius {
            var cell = self + Hex.directions[4] * step
            for side in 0..<6 {
                let direction = Hex.directions[side]
                for _ in 0..<step {
                    result.append(cell)
                    cell = cell + direction
                }
            }
        }
        return result
    }

    /// The hexes on a straight line from here to `other`, both ends included.
    public func line(to other: Hex) -> [Hex] {
        let steps = distance(to: other)
        guard steps > 0 else { return [self] }
        var result: [Hex] = []
        result.reserveCapacity(steps + 1)
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            // A tiny nudge keeps points on a hex edge from rounding both ways.
            let q = Double(q) + (Double(other.q - q)) * t + 1e-6
            let r = Double(r) + (Double(other.r - r)) * t + 1e-6
            result.append(HexLayout.round(q: q, r: r))
        }
        return result
    }

    public static func + (lhs: Hex, rhs: Hex) -> Hex { Hex(lhs.q + rhs.q, lhs.r + rhs.r) }
    public static func - (lhs: Hex, rhs: Hex) -> Hex { Hex(lhs.q - rhs.q, lhs.r - rhs.r) }
    public static func * (lhs: Hex, rhs: Int) -> Hex { Hex(lhs.q * rhs, lhs.r * rhs) }

    public static func < (lhs: Hex, rhs: Hex) -> Bool {
        (lhs.r, lhs.q) < (rhs.r, rhs.q)
    }

    public var description: String { "(\(q), \(r))" }
}

/// Converts between hexes and points on a flat plane, for drawing and for
/// picking the hex under the pointer. One unit is the distance from a hex's
/// centre to a corner.
public struct HexLayout: Sendable, Equatable {
    public var size: Double

    public init(size: Double = 1) {
        self.size = size
    }

    private static let root3 = 3.0.squareRoot()

    public func center(of hex: Hex) -> (x: Double, y: Double) {
        let x = size * HexLayout.root3 * (Double(hex.q) + Double(hex.r) / 2)
        let y = size * 1.5 * Double(hex.r)
        return (x, y)
    }

    /// The hex containing the point.
    public func hex(atX x: Double, y: Double) -> Hex {
        let q = (HexLayout.root3 / 3 * x - y / 3) / size
        let r = (2.0 / 3 * y) / size
        return HexLayout.round(q: q, r: r)
    }

    /// The six corners, clockwise from the top.
    public func corners(of hex: Hex) -> [(x: Double, y: Double)] {
        let c = center(of: hex)
        let half = size * HexLayout.root3 / 2
        return [
            (c.x, c.y - size),
            (c.x + half, c.y - size / 2),
            (c.x + half, c.y + size / 2),
            (c.x, c.y + size),
            (c.x - half, c.y + size / 2),
            (c.x - half, c.y - size / 2),
        ]
    }

    static func round(q: Double, r: Double) -> Hex {
        let s = -q - r
        var rq = q.rounded()
        var rr = r.rounded()
        let rs = s.rounded()
        let dq = abs(rq - q)
        let dr = abs(rr - r)
        let ds = abs(rs - s)
        if dq > dr, dq > ds {
            rq = -rr - rs
        } else if dr > ds {
            rr = -rq - rs
        }
        return Hex(Int(rq), Int(rr))
    }
}
