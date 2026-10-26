import NullmereCore

/// Packs what the world shader needs to know about each tile into four
/// bytes, laid out as a square texture indexed by axial coordinates:
/// terrain, feature, relief, and what the viewer knows of it (whether the
/// tile is unknown, remembered or watched) with the colour of the House
/// whose territory it is.
enum TileTexture {
    static func side(for map: WorldMap) -> Int {
        2 * map.radius + 1
    }

    static func bytes(for state: GameState, viewer: Int) -> [UInt8] {
        let map = state.map
        let side = side(for: map)
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        let visible = state.visibility(for: viewer)
        let explored = state.houses[viewer].explored
        let owners = state.territory()
        for (index, hex) in map.hexes.enumerated() {
            let tile = map[index]
            let offset = ((hex.r + map.radius) * side + (hex.q + map.radius)) * 4
            let seen = visible[index] ? 2 : (explored[index] ? 1 : 0)
            var owner = 0
            if seen > 0, let holdID = owners[index], let hold = state.hold(holdID) {
                owner = state.houses[hold.owner].sigil + 1
            }
            bytes[offset] = UInt8(Terrain.allCases.firstIndex(of: tile.terrain) ?? 0)
            bytes[offset + 1] = tile.feature.map { UInt8((Feature.allCases.firstIndex(of: $0) ?? 0) + 1) } ?? 0
            bytes[offset + 2] = UInt8(clamping: tile.relief * 255 / 100)
            bytes[offset + 3] = UInt8(seen * 16 + owner)
        }
        return bytes
    }
}
