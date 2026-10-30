import NullmereCore

/// Packs what the world shader needs to know about each tile into four
/// bytes, laid out as a square texture indexed by axial coordinates:
/// terrain, feature, relief, and what the viewer knows of it (whether the
/// tile is unknown, remembered or watched) with the colour of the House
/// whose territory it is.
public enum TileTexture {
    /// Set in the feature byte where a hold stands.
    public static let holdFlag: UInt8 = 0x80

    public static func side(for map: WorldMap) -> Int {
        2 * map.radius + 1
    }

    /// What never changes from watch to watch: each tile's terrain, feature
    /// and relief, and where in the texture each tile lies. Made once for a
    /// map; each change of the world fills in only what the keeper knows.
    public struct Ground: Sendable {
        public let map: WorldMap
        public let bytes: [UInt8]
        public let offsets: [Int]

        public init(map: WorldMap) {
            self.map = map
            let side = TileTexture.side(for: map)
            var bytes = [UInt8](repeating: 0, count: side * side * 4)
            var offsets: [Int] = []
            offsets.reserveCapacity(map.count)
            for (index, hex) in map.hexes.enumerated() {
                let tile = map[index]
                let offset = ((hex.r + map.radius) * side + (hex.q + map.radius)) * 4
                offsets.append(offset)
                bytes[offset] = tile.terrain.code
                bytes[offset + 1] = tile.feature.map { $0.code + 1 } ?? 0
                bytes[offset + 2] = UInt8(clamping: tile.relief * 255 / 100)
            }
            self.bytes = bytes
            self.offsets = offsets
        }
    }

    /// `visible` and `owners` may be passed when already worked out, and
    /// `ground` when the map hasn't changed, as the session does on every
    /// change.
    public static func bytes(for state: GameState, viewer: Int, visible: [Bool]? = nil, owners: [Int?]? = nil,
                      ground: Ground? = nil) -> [UInt8] {
        let map = state.map
        let ground = ground.flatMap { $0.map == map ? $0 : nil } ?? Ground(map: map)
        var bytes = ground.bytes
        let visible = visible ?? state.visibility(for: viewer)
        let explored = state.houses[viewer].explored
        let owners = owners ?? state.territory()
        let holdTiles = Set(state.holds.compactMap { map.index(of: $0.position) })
        // Each hold's colour, found once rather than for every tile.
        var colourOf: [Int: Int] = [:]
        for hold in state.holds { colourOf[hold.id] = state.houses[hold.owner].sigil + 1 }
        for index in 0..<map.count {
            let seen = visible[index] ? 2 : (explored[index] ? 1 : 0)
            guard seen > 0 else { continue }
            let offset = ground.offsets[index]
            var owner = 0
            if let holdID = owners[index], let colour = colourOf[holdID] {
                owner = colour
            }
            // A known hold lights the country round it: the feature byte's top bit.
            if holdTiles.contains(index) {
                bytes[offset + 1] |= TileTexture.holdFlag
            }
            bytes[offset + 3] = UInt8(seen * 16 + owner)
        }
        return bytes
    }
}
