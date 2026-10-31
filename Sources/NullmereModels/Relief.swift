import NullmereCore

/// The lie of the land everywhere over the map: each hex rises to its
/// terrain's height at its heart, the land runs smoothly from one to the
/// next, and each terrain lays its own grain over it: the Spine's ridges,
/// the barrows' mounds, the greyfields' long swells. Beyond the map the
/// Spine goes on, climbing. The still water's face is height zero.
public struct Relief: Sendable {
    public let radius: Int
    let map: WorldMap
    private let heights: [Float]

    /// The still lake's face.
    public static let waterline: Float = 0
    /// Distance between the hearts of neighbouring hexes.
    public static let hexSpacing: Float = Float(3).squareRoot()

    public init(map: WorldMap) {
        self.map = map
        radius = map.radius
        heights = (0..<map.count).map { index in
            let tile = map[index]
            return Relief.baseHeight(tile.terrain) + Relief.reliefLift(tile.terrain) * Float(tile.relief) / 100
        }
    }

    /// Where each terrain's land lies, at a hex's heart, before its grain.
    public static func baseHeight(_ terrain: Terrain) -> Float {
        switch terrain {
        case .still: return -0.75
        case .shallows: return -0.09
        // Just under the water: the moon's road shows pale through it.
        case .ford: return -0.03
        case .strand: return 0.04
        case .saltFlat: return 0.06
        case .greyfield: return 0.16
        case .blackwood: return 0.22
        case .barrow: return 0.34
        case .spine: return 1.25
        }
    }

    /// How much the map's own shading lifts a hex of this terrain.
    static func reliefLift(_ terrain: Terrain) -> Float {
        switch terrain {
        case .still, .shallows, .strand, .saltFlat, .ford: return 0
        case .greyfield, .blackwood: return 0.12
        case .barrow: return 0.18
        case .spine: return 0.5
        }
    }

    /// Each terrain's own grain, laid over the smooth land.
    static func grain(_ terrain: Terrain, _ x: Float, _ z: Float) -> Float {
        switch terrain {
        case .still: return -0.18 * Noise.fractal(x * 0.35, z * 0.35, octaves: 3, seed: 11)
        case .shallows: return 0.03 * Noise.fractal(x * 1.7, z * 1.7, octaves: 2, seed: 12)
        case .ford: return 0.012 * Noise.value(x * 3.7, z * 3.7, seed: 19)
        case .strand: return 0.025 * Noise.value(x * 3.1, z * 3.1, seed: 13)
        case .saltFlat: return 0.008 * Noise.value(x * 4.3, z * 4.3, seed: 14)
        case .greyfield: return 0.08 * Noise.fractal(x * 0.8, z * 0.8, octaves: 3, seed: 15)
        case .blackwood: return 0.07 * Noise.fractal(x * 1.2, z * 1.2, octaves: 3, seed: 16)
        case .barrow:
            let mound = Noise.fractal(x * 1.4, z * 1.4, octaves: 2, seed: 17)
            return 0.3 * mound * mound
        case .spine:
            // Ridges bent by a broad warp, sharpened by squaring: long
            // crests and steep valleys, not a field of bumps.
            let wx = x + 1.8 * Noise.fractal(x * 0.19, z * 0.19, octaves: 2, seed: 31)
            let wz = z + 1.8 * Noise.fractal(x * 0.19 + 5.3, z * 0.19 - 3.1, octaves: 2, seed: 32)
            let ridge = Noise.ridged(wx * 0.3, wz * 0.3, octaves: 5, seed: 18)
            return 1.7 * ridge * ridge + 0.22 * Noise.fractal(x * 1.3, z * 1.3, octaves: 3, seed: 33)
        }
    }

    /// The map position of a hex's heart.
    public static func centre(of hex: Hex) -> (x: Float, z: Float) {
        (Relief.hexSpacing * (Float(hex.q) + Float(hex.r) / 2), 1.5 * Float(hex.r))
    }

    /// The terrain of a hex, the Spine beyond the map.
    public func terrain(of hex: Hex) -> Terrain {
        map[hex]?.terrain ?? .spine
    }

    /// A hex's height at its heart before its grain; past the map's edge
    /// the Spine climbs with each ring.
    func heartHeight(_ hex: Hex) -> Float {
        if let index = map.index(of: hex) { return heights[index] }
        let distance = (abs(hex.q) + abs(hex.r) + abs(hex.q + hex.r)) / 2
        let beyond = Float(distance - radius)
        return Relief.baseHeight(.spine) + 0.2 + min(beyond, 8) * 0.3 + 0.3 * Noise.unit(Int32(hex.q), Int32(hex.r), 19)
    }

    /// The three hexes whose hearts surround a point, with how near the
    /// point lies to each: weights that sum to one.
    public static func surrounding(x: Float, z: Float) -> [(hex: Hex, weight: Float)] {
        let t = Relief.triangle(x: x, z: z)
        return [(t.a, t.wa), (t.b, t.wb), (t.c, t.wc)]
    }

    /// The lattice triangle of hearts round a point and the point's weights,
    /// without making an array: the land is asked this a hundred thousand
    /// times as it is built.
    static func triangle(x: Float, z: Float) -> (a: Hex, wa: Float, b: Hex, wb: Float, c: Hex, wc: Float) {
        let qf = (Relief.hexSpacing / 3 * x - z / 3)
        let rf = 2 * z / 3
        let q0 = qf.rounded(.down), r0 = rf.rounded(.down)
        let fq = qf - q0, fr = rf - r0
        let q = Int(q0), r = Int(r0)
        if fq + fr <= 1 {
            return (Hex(q, r), 1 - fq - fr, Hex(q + 1, r), fq, Hex(q, r + 1), fr)
        }
        return (Hex(q + 1, r + 1), fq + fr - 1, Hex(q, r + 1), 1 - fq, Hex(q + 1, r), 1 - fr)
    }

    /// A weight raised to a power: near its heart a hex holds its own
    /// height or colour, and the change comes toward its edge.
    static func raise(_ value: Float, _ power: Int) -> Float {
        var w: Float = 1
        for _ in 0..<power { w *= max(value, 0) }
        return w
    }

    /// The height of the land at a point of the map.
    public func height(atX x: Float, z: Float) -> Float {
        let t = Relief.triangle(x: x, z: z)
        let wa = Relief.raise(t.wa, 3), wb = Relief.raise(t.wb, 3), wc = Relief.raise(t.wc, 3)
        let total = wa + wb + wc
        guard total > 0 else { return 0 }
        // A hex too far from the point to matter adds nothing, and its grain
        // isn't worked out.
        func share(_ hex: Hex, _ weight: Float) -> Float {
            weight > 1e-4 ? weight * (heartHeight(hex) + Relief.grain(terrain(of: hex), x, z)) : 0
        }
        return share(t.a, wa / total) + share(t.b, wb / total) + share(t.c, wc / total)
    }

    /// Which way the land faces at a point.
    public func normal(atX x: Float, z: Float, step: Float = 0.05) -> Vec3 {
        let dx = height(atX: x + step, z: z) - height(atX: x - step, z: z)
        let dz = height(atX: x, z: z + step) - height(atX: x, z: z - step)
        return Vec3(-dx, 2 * step, -dz).normalized
    }

    /// The height at a hex's heart, where a hold or a company stands.
    public func height(of hex: Hex) -> Float {
        let c = Relief.centre(of: hex)
        return height(atX: c.x, z: c.z)
    }

    /// Where a ray from `origin` along `direction` first meets the land or
    /// the still water's face, if it does within `reach`.
    public func intersect(origin: Vec3, direction: Vec3, reach: Float = 400) -> Vec3? {
        let d = direction.normalized
        func above(_ t: Float) -> Float {
            let p = origin + d * t
            return p.y - max(height(atX: p.x, z: p.z), Relief.waterline)
        }
        var t: Float = 0
        var previous = above(0)
        guard previous > 0 else { return origin }
        var step: Float = 0.25
        while t < reach {
            let next = t + step
            let value = above(next)
            if value <= 0 {
                // Narrow it down between the last point above and the first below.
                var low = t, high = next
                for _ in 0..<24 {
                    let mid = (low + high) / 2
                    if above(mid) > 0 { low = mid } else { high = mid }
                }
                return origin + d * high
            }
            previous = value
            t = next
            // Long strides while far above the land, short ones close to it.
            step = min(max(previous * 0.5, 0.05), 2)
        }
        return nil
    }
}
