import NullmereCore

/// Packs what the world shader needs to know about each tile into four
/// bytes, laid out as a square texture indexed by axial coordinates:
/// terrain, feature, relief, and what the viewer knows of it (whether the
/// tile is unknown, remembered or watched) with the colour of the House
/// whose territory it is.
enum TileTexture {
    /// Set in the feature byte where a hold stands.
    static let holdFlag: UInt8 = 0x80

    static func side(for map: WorldMap) -> Int {
        2 * map.radius + 1
    }

    /// `visible` and `owners` may be passed when already worked out, as
    /// the session does on every change.
    static func bytes(for state: GameState, viewer: Int, visible: [Bool]? = nil, owners: [Int?]? = nil) -> [UInt8] {
        let map = state.map
        let side = side(for: map)
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        let visible = visible ?? state.visibility(for: viewer)
        let explored = state.houses[viewer].explored
        let owners = owners ?? state.territory()
        let holdTiles = Set(state.holds.compactMap { map.index(of: $0.position) })
        // Each hold's colour, found once rather than for every tile.
        var colourOf: [Int: Int] = [:]
        for hold in state.holds { colourOf[hold.id] = state.houses[hold.owner].sigil + 1 }
        for (index, hex) in map.hexes.enumerated() {
            let tile = map[index]
            let offset = ((hex.r + map.radius) * side + (hex.q + map.radius)) * 4
            let seen = visible[index] ? 2 : (explored[index] ? 1 : 0)
            var owner = 0
            if seen > 0, let holdID = owners[index], let colour = colourOf[holdID] {
                owner = colour
            }
            bytes[offset] = UInt8(Terrain.allCases.firstIndex(of: tile.terrain) ?? 0)
            bytes[offset + 1] = tile.feature.map { UInt8((Feature.allCases.firstIndex(of: $0) ?? 0) + 1) } ?? 0
            // A known hold lights the country round it: the feature byte's top bit.
            if seen > 0, holdTiles.contains(index) {
                bytes[offset + 1] |= TileTexture.holdFlag
            }
            bytes[offset + 2] = UInt8(clamping: tile.relief * 255 / 100)
            bytes[offset + 3] = UInt8(seen * 16 + owner)
        }
        return bytes
    }
}
