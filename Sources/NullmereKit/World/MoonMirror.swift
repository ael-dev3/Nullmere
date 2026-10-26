import NullmereCore

/// Where the moon lies in the black water: over the deepest open water of
/// the age's lake, the hex farthest from any shore, sized to fit it. On the
/// Twin Waters that is one of the two lakes, never the land between them.
enum MoonMirror {
    /// World x and y of the reflection's centre, its radius in world units,
    /// and 1 when there is water deep enough to hold it.
    static func place(in map: WorldMap) -> SIMD4<Float> {
        guard let (hex, depth) = deepest(in: map), depth >= 2 else { return SIMD4(0, 0, 0, 0) }
        let centre = HexLayout(size: 1).center(of: hex)
        let radius = min(1.05, 0.45 * Double(depth - 1))
        return SIMD4(Float(centre.x), Float(centre.y), Float(radius), 1)
    }

    /// The hex of open water farthest from any shore, and how far.
    static func deepest(in map: WorldMap) -> (Hex, Int)? {
        // Hexes of open water, by their distance from anything that isn't.
        var depth = [Int](repeating: -1, count: map.count)
        var frontier: [Int] = []
        for index in 0..<map.count where map[index].terrain != .still {
            depth[index] = 0
            frontier.append(index)
        }
        let hexes = map.hexes
        var head = 0
        while head < frontier.count {
            let index = frontier[head]
            head += 1
            for neighbour in map.neighbors(of: hexes[index]) {
                guard let next = map.index(of: neighbour), depth[next] < 0 else { continue }
                depth[next] = depth[index] + 1
                frontier.append(next)
            }
        }
        // The deepest; of equals, the nearest the middle of the world.
        guard let deepest = depth.indices.max(by: { a, b in
            (depth[a], -hexes[a].length, -a) < (depth[b], -hexes[b].length, -b)
        }), depth[deepest] > 0 else { return nil }
        return (hexes[deepest], depth[deepest])
    }
}
