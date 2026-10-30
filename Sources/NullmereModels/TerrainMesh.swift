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

    /// The colour each terrain shows in plain white light, in sRGB.
    public static func colour(_ terrain: Terrain) -> Vec3 {
        switch terrain {
        case .still: return Vec3(0.06, 0.07, 0.07)
        case .shallows: return Vec3(0.14, 0.15, 0.14)
        case .strand: return Vec3(0.47, 0.46, 0.43)
        case .saltFlat: return Vec3(0.84, 0.87, 0.90)
        case .greyfield: return Vec3(0.33, 0.36, 0.30)
        case .blackwood: return Vec3(0.13, 0.16, 0.13)
        case .barrow: return Vec3(0.34, 0.33, 0.27)
        case .spine: return Vec3(0.27, 0.27, 0.30)
        }
    }

    /// Frost on the Spine's heights.
    static let frost = Vec3(0.5, 0.52, 0.57)
    static let frostLine: Float = 2.4

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
                var colour = Vec3.zero
                var strongest: (terrain: Terrain, weight: Float) = (.spine, -1)
                for (hex, weight) in Relief.sharpened(Relief.surrounding(x: x, z: z), power: 6) {
                    let terrain = relief.terrain(of: hex)
                    colour += TerrainMesh.colour(terrain) * weight
                    if weight > strongest.weight { strongest = (terrain, weight) }
                }
                if height > TerrainMesh.frostLine {
                    colour = colour.mix(TerrainMesh.frost, min((height - TerrainMesh.frostLine) / 0.8, 1))
                }
                // A little mottling, so no field is one flat colour.
                colour *= 0.9 + 0.2 * Noise.value(x * 2.3, z * 2.3, seed: 21)
                colours[index] = colour
                grounds[index] = strongest.terrain.code
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
        self.mesh = Mesh(vertices: vertices, indices: indices)
        self.heights = heights
        self.columns = columns
        self.rows = rows
        self.originX = originX
        self.originZ = originZ
        self.spacing = spacing
    }

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
