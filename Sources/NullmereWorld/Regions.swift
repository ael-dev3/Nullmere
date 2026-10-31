import NullmereCore
import NullmereModels

/// The land cut into square regions of hexes, so that a frame draws the
/// land's furniture only where its view reaches: what each region holds
/// lies together in every batch, and its bounds are kept, so a frame finds
/// the regions it sees and draws just their runs of each batch.
public struct Regions: Equatable, Sendable {
    /// A region's bounds in the world: every piece in it, as far as it
    /// reaches.
    public struct Box: Equatable, Sendable {
        public var low: Vec3
        public var high: Vec3

        /// Whether any of it lies inside every one of `planes`.
        func isSeen(by planes: [Vec4]) -> Bool {
            planes.allSatisfy { plane in
                // The corner furthest along the plane's normal.
                let x = plane.x >= 0 ? high.x : low.x, y = plane.y >= 0 ? high.y : low.y, z = plane.z >= 0 ? high.z : low.z
                return plane.x * x + plane.y * y + plane.z * z + plane.w >= 0
            }
        }
    }

    /// How many hexes a region spans each way.
    public static let side = 8
    /// How far a piece reaches past where it stands: the widest crown and
    /// the tallest stone.
    static let reach: Float = 2.5

    public let radius: Int
    public let columns: Int
    /// Each region's bounds, row by row; nil where nothing stands.
    public let boxes: [Box?]
    /// For each batch, where each region's instances begin, and last, how
    /// many it has.
    public let starts: [[Int]]

    /// The region a hex lies in, row by row.
    public static func region(of hex: Hex, radius: Int) -> Int {
        let columns = (2 * radius + side) / side
        return (hex.r + radius) / side * columns + (hex.q + radius) / side
    }

    /// The pieces placed over a map of `radius`, gathered kind by kind as
    /// `WorldStage.batches` gathers them, each kind's pieces region by
    /// region, with the regions they make.
    public static func gather(_ placed: [(ModelKey, ModelInstance)], radius: Int) -> (batches: [ModelBatch], regions: Regions) {
        let columns = (2 * radius + side) / side
        let count = columns * columns
        func region(_ instance: ModelInstance) -> Int {
            Regions.region(of: Hex(Int(instance.hex.x), Int(instance.hex.y)), radius: radius)
        }
        // Region by region, keeping each region's own order.
        var byRegion = [[(ModelKey, ModelInstance)]](repeating: [], count: count)
        for piece in placed { byRegion[region(piece.1)].append(piece) }
        let ordered = byRegion.flatMap { $0 }
        let batches = WorldStage.batches(ordered)
        var boxes = [Box?](repeating: nil, count: count)
        for (_, instance) in ordered {
            let at = instance.model.c3
            let low = Vec3(at.x - reach, at.y - reach, at.z - reach), high = Vec3(at.x + reach, at.y + reach, at.z + reach)
            let index = region(instance)
            if let box = boxes[index] {
                boxes[index] = Box(low: Vec3(min(box.low.x, low.x), min(box.low.y, low.y), min(box.low.z, low.z)),
                                   high: Vec3(max(box.high.x, high.x), max(box.high.y, high.y), max(box.high.z, high.z)))
            } else {
                boxes[index] = Box(low: low, high: high)
            }
        }
        let starts = batches.map { batch -> [Int] in
            var starts = [Int](repeating: 0, count: count + 1)
            for instance in batch.instances { starts[region(instance) + 1] += 1 }
            for index in 1...count { starts[index] += starts[index - 1] }
            return starts
        }
        return (batches, Regions(radius: radius, columns: columns, boxes: boxes, starts: starts))
    }

    /// The planes that bound what a view-projection sees, each kept where
    /// a point's dot with it is at least nought: left, right, bottom, top,
    /// near and far, as Metal's clip space has them.
    public static func planes(of viewProjection: Mat4) -> [Vec4] {
        let m = viewProjection
        func row(_ i: Int) -> Vec4 { Vec4(m.c0[i], m.c1[i], m.c2[i], m.c3[i]) }
        let (x, y, z, w) = (row(0), row(1), row(2), row(3))
        return [w + x, w - x, w + y, w - y, z, w - z]
    }

    /// For each batch, the runs of its instances in the regions a frame of
    /// `viewProjection` sees, neighbouring regions' runs joined.
    public func runs(seenBy viewProjection: Mat4) -> [[Range<Int>]] {
        let planes = Regions.planes(of: viewProjection)
        let seen = boxes.map { $0?.isSeen(by: planes) ?? false }
        return starts.map { starts in
            var runs: [Range<Int>] = []
            for region in seen.indices where seen[region] && starts[region] < starts[region + 1] {
                let run = starts[region]..<starts[region + 1]
                if let last = runs.last, last.upperBound == run.lowerBound {
                    runs[runs.count - 1] = last.lowerBound..<run.upperBound
                } else {
                    runs.append(run)
                }
            }
            return runs
        }
    }
}
