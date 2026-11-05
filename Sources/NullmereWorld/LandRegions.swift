import NullmereModels

/// The land cut into square chunks of its grid, so that a frame draws only
/// the chunks its view reaches, as the furniture's regions are drawn: each
/// chunk's triangles lie together in the land's index buffer, and its
/// bounds are kept. A wide realm's frame then costs what is in view, not
/// the whole of its land.
public struct LandRegions: Equatable, Sendable {
    /// How many of the grid's squares a chunk spans each way.
    public static let side = 32
    /// The height the land's shader lays the unknown at, under the mist
    /// (`kMistLevel` in WorldShaders): a chunk reaches it too.
    public static let mistLevel: Float = 0.02

    /// The land's triangles, chunk by chunk, row of chunks by row; within
    /// a chunk, row by row, as the mesh has them.
    public let indices: [UInt32]
    /// Each chunk's bounds, the same order.
    public let boxes: [Regions.Box]
    /// Where each chunk's indices begin, and last, how many there are.
    public let starts: [Int]

    public init(_ terrain: TerrainMesh, side: Int = LandRegions.side) {
        let squares = terrain.columns - 1, squareRows = terrain.rows - 1
        let across = (squares + side - 1) / side, down = (squareRows + side - 1) / side
        let mesh = terrain.mesh.indices
        var indices: [UInt32] = []
        indices.reserveCapacity(mesh.count)
        var boxes: [Regions.Box] = []
        var starts: [Int] = []
        for chunkRow in 0..<down {
            for chunkColumn in 0..<across {
                starts.append(indices.count)
                let rows = chunkRow * side..<min((chunkRow + 1) * side, squareRows)
                let columns = chunkColumn * side..<min((chunkColumn + 1) * side, squares)
                for row in rows {
                    let first = (row * squares + columns.lowerBound) * 6, last = (row * squares + columns.upperBound) * 6
                    indices.append(contentsOf: mesh[first..<last])
                }
                // Its corners, and its heights from the lowest to the
                // highest of its points and the mist.
                var low = LandRegions.mistLevel, high = LandRegions.mistLevel
                for row in rows.lowerBound...rows.upperBound {
                    for column in columns.lowerBound...columns.upperBound {
                        let height = terrain.heights[row * terrain.columns + column]
                        low = min(low, height)
                        high = max(high, height)
                    }
                }
                let x0 = terrain.originX + Float(columns.lowerBound) * terrain.spacing
                let x1 = terrain.originX + Float(columns.upperBound) * terrain.spacing
                let z0 = terrain.originZ + Float(rows.lowerBound) * terrain.spacing
                let z1 = terrain.originZ + Float(rows.upperBound) * terrain.spacing
                boxes.append(Regions.Box(low: Vec3(x0, low, z0), high: Vec3(x1, high, z1)))
            }
        }
        starts.append(indices.count)
        self.indices = indices
        self.boxes = boxes
        self.starts = starts
    }

    /// The runs of `indices` a frame of `viewProjection` sees: the chunks in
    /// its view, neighbours in the buffer joined into one run.
    public func runs(seenBy viewProjection: Mat4) -> [Range<Int>] {
        let planes = Regions.planes(of: viewProjection)
        var runs: [Range<Int>] = []
        for (chunk, box) in boxes.enumerated() where box.isSeen(by: planes) && starts[chunk] < starts[chunk + 1] {
            let run = starts[chunk]..<starts[chunk + 1]
            if let last = runs.last, last.upperBound == run.lowerBound {
                runs[runs.count - 1] = last.lowerBound..<run.upperBound
            } else {
                runs.append(run)
            }
        }
        return runs
    }
}
