import NullmereCore

/// Where the moon lies in the black water: over the deepest open water of
/// the age's lake, the hex farthest from any shore, sized to fit it. On the
/// Twin Waters that is one of the two lakes, never the land between them.
enum MoonMirror {
    /// World x and y of the reflection's centre, its radius in world units,
    /// and 1 when there is water deep enough to hold it.
    static func place(in map: WorldMap) -> SIMD4<Float> {
        guard let water = map.deepestWater() else { return SIMD4(0, 0, 0, 0) }
        return place(water)
    }

    /// Where the moon's reflection lies in a world: where the realm found
    /// it on the whole map, or, for a world from before it did, on the map
    /// as this keeper knows it.
    static func place(for state: GameState) -> SIMD4<Float> {
        guard let water = state.moonWater else { return place(in: state.map) }
        return place(water)
    }

    private static func place(_ water: DeepWater) -> SIMD4<Float> {
        guard water.depth >= 2 else { return SIMD4(0, 0, 0, 0) }
        let centre = HexLayout(size: 1).center(of: water.hex)
        let radius = min(1.05, 0.45 * Double(water.depth - 1))
        return SIMD4(Float(centre.x), Float(centre.y), Float(radius), 1)
    }
}
