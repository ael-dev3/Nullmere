import Foundation
import NullmereCore

/// The land as one mesh: a grid of points over the map and the Spine round
/// it, each raised to the relief's height and coloured by the ground there,
/// lit smoothly. Its heights are kept as a grid too, for the water to know
/// how deep it lies.
public struct TerrainMesh: Sendable {
    public let mesh: Mesh
    /// The land's height at each grid point, row by row from the north-west.
    public let heights: [Float]
    public let columns: Int
    public let rows: Int
    /// The map position of the first grid point.
    public let originX: Float
    public let originZ: Float
    public let spacing: Float
    /// The land's corner and far corner, worked out once: a frame asks for
    /// them, and a hundred thousand vertices are not to be counted each time.
    public let low: Vec3
    public let high: Vec3

    /// The colour each terrain shows in plain white light, in sRGB.
    public static func colour(_ terrain: Terrain) -> Vec3 {
        switch terrain {
        case .still: return Vec3(0.06, 0.07, 0.07)
        case .shallows: return Vec3(0.14, 0.15, 0.14)
        // Shingle washed silver by the moon.
        case .ford: return Vec3(0.56, 0.58, 0.62)
        case .strand: return Vec3(0.47, 0.46, 0.43)
        case .saltFlat: return Vec3(0.84, 0.87, 0.90)
        case .greyfield: return Vec3(0.33, 0.36, 0.30)
        case .blackwood: return Vec3(0.13, 0.16, 0.13)
        case .barrow: return Vec3(0.34, 0.33, 0.27)
        case .spine: return Vec3(0.21, 0.21, 0.24)
        }
    }

    /// Frost on the Spine's heights.
    static let frost = Vec3(0.5, 0.52, 0.57)
    static let frostLine: Float = 2.7

    /// How far past the map's outermost hexes the land is drawn.
    public static let margin: Float = 7

    public init(relief: Relief, spacing: Float = 0.3) {
        let radius = Float(relief.radius)
        let halfWidth = Relief.hexSpacing * (radius + 0.5) + TerrainMesh.margin
        let halfDepth = 1.5 * radius + 1 + TerrainMesh.margin
        let columns = Int((2 * halfWidth / spacing).rounded(.up)) + 1
        let rows = Int((2 * halfDepth / spacing).rounded(.up)) + 1
        let originX = -halfWidth, originZ = -halfDepth

        var heights = [Float](repeating: 0, count: columns * rows)
        var colours = [Vec3](repeating: .zero, count: columns * rows)
        var grounds = [UInt8](repeating: 0, count: columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let x = originX + Float(column) * spacing, z = originZ + Float(row) * spacing
                let index = row * columns + column
                let height = relief.height(atX: x, z: z)
                heights[index] = height
                // The colour keeps each hex's own ground until near its edge.
                let t = Relief.triangle(x: x, z: z)
                let wa = Relief.raise(t.wa, 6), wb = Relief.raise(t.wb, 6), wc = Relief.raise(t.wc, 6)
                let total = max(wa + wb + wc, 1e-12)
                let ta = relief.terrain(of: t.a), tb = relief.terrain(of: t.b), tc = relief.terrain(of: t.c)
                var colour = (TerrainMesh.colour(ta) * wa + TerrainMesh.colour(tb) * wb + TerrainMesh.colour(tc) * wc) / total
                let strongest = wa >= wb && wa >= wc ? ta : (wb >= wc ? tb : tc)
                if height > TerrainMesh.frostLine {
                    colour = colour.mix(TerrainMesh.frost, min((height - TerrainMesh.frostLine) / 0.8, 1))
                }
                // A little mottling, so no field is one flat colour.
                colour *= 0.9 + 0.2 * Noise.value(x * 2.3, z * 2.3, seed: 21)
                colours[index] = colour
                grounds[index] = strongest.code
            }
        }

        var vertices: [MeshVertex] = []
        vertices.reserveCapacity(columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let index = row * columns + column
                let left = heights[row * columns + max(column - 1, 0)]
                let right = heights[row * columns + min(column + 1, columns - 1)]
                let up = heights[max(row - 1, 0) * columns + column]
                let down = heights[min(row + 1, rows - 1) * columns + column]
                let normal = Vec3(left - right, 2 * spacing, up - down).normalized
                let position = Vec3(originX + Float(column) * spacing, heights[index], originZ + Float(row) * spacing)
                vertices.append(MeshVertex(position: position, normal: normal, color: colours[index],
                                           part: UInt16(grounds[index]), material: .plain))
            }
        }
        var indices: [UInt32] = []
        indices.reserveCapacity((columns - 1) * (rows - 1) * 6)
        for row in 0..<(rows - 1) {
            for column in 0..<(columns - 1) {
                let a = UInt32(row * columns + column), b = a + 1
                let c = UInt32((row + 1) * columns + column), d = c + 1
                // Counter-clockwise seen from above: north-west, south-west, south-east…
                // with the diagonal alternating, so no slope leans one way.
                if (row + column) % 2 == 0 {
                    indices += [a, c, d, a, d, b]
                } else {
                    indices += [a, c, b, b, c, d]
                }
            }
        }
        let built = Mesh(vertices: vertices, indices: indices)
        let bounds = built.bounds
        self.mesh = built
        self.low = bounds.min
        self.high = bounds.max
        self.heights = heights
        self.columns = columns
        self.rows = rows
        self.originX = originX
        self.originZ = originZ
        self.spacing = spacing
    }

    /// The land of a map, made once and kept: every view of the same map
    /// shares it.
    public static func shared(for map: WorldMap, spacing: Float = 0.3) -> TerrainMesh {
        TerrainMesh.store.lock.lock()
        defer { TerrainMesh.store.lock.unlock() }
        if let kept = TerrainMesh.store.kept.first(where: { $0.map == map && $0.spacing == spacing }) {
            return kept.terrain
        }
        let terrain = TerrainMesh(relief: Relief(map: map), spacing: spacing)
        TerrainMesh.store.kept.append((map, spacing, terrain))
        // A few maps are kept: an age's, and the next as it begins.
        if TerrainMesh.store.kept.count > 3 { TerrainMesh.store.kept.removeFirst() }
        return terrain
    }

    private final class Store: @unchecked Sendable {
        let lock = NSLock()
        var kept: [(map: WorldMap, spacing: Float, terrain: TerrainMesh)] = []
    }

    private static let store = Store()

    /// The height at a point, read from the grid between its points.
    public func height(atX x: Float, z: Float) -> Float {
        let gx = min(max((x - originX) / spacing, 0), Float(columns - 1))
        let gz = min(max((z - originZ) / spacing, 0), Float(rows - 1))
        let c0 = min(Int(gx), columns - 2), r0 = min(Int(gz), rows - 2)
        let fx = gx - Float(c0), fz = gz - Float(r0)
        let h00 = heights[r0 * columns + c0], h10 = heights[r0 * columns + c0 + 1]
        let h01 = heights[(r0 + 1) * columns + c0], h11 = heights[(r0 + 1) * columns + c0 + 1]
        return (h00 + (h10 - h00) * fx) + ((h01 + (h11 - h01) * fx) - (h00 + (h10 - h00) * fx)) * fz
    }
}
