import Foundation

extension Terrain {
    /// Its place among the terrains: the case it is, as it is held, which
    /// is its place in the order they are told in.
    public var code: UInt8 { caseNumber }
}

extension Feature {
    /// Its place among the features: the case it is, as it is held, which
    /// is its place in the order they are told in.
    public var code: UInt8 { caseNumber }
}

/// One tile of the world.
public struct Tile: Codable, Equatable, Sendable {
    public var terrain: Terrain
    public var feature: Feature?
    /// 0...100, for shading only; it never affects the rules.
    public var relief: Int

    public init(terrain: Terrain, feature: Feature? = nil, relief: Int = 0) {
        self.terrain = terrain
        self.feature = feature
        self.relief = relief
    }

    /// What a hold gets from working this tile each watch.
    public var yield: Stock {
        terrain.yield + (feature?.yield ?? .zero)
    }
}

/// The hexagonal world: every hex within `radius` of the origin, stored row
/// by row so a hex's index is computed rather than looked up.
public struct WorldMap: Codable, Equatable, Sendable {
    public let radius: Int
    public private(set) var tiles: [Tile]
    /// Index of the first hex in each row, from `-radius` to `radius`.
    private let rowStarts: [Int]
    /// Every hex in index order, laid out once.
    private let hexList: [Hex]
    /// Each tile's neighbours' indices, six to a tile in the order of
    /// `Hex.directions`, -1 past the world's edge: laid out once, for the
    /// search for ways.
    let neighbours: [Int32]
    /// What stepping onto each tile costs a company, 0 where none may: kept
    /// as the tiles change, for the search for ways.
    private(set) var steps: [UInt8]
    /// The lie of the land toward the goals far marches have sought, kept
    /// while the ground is as it is: shared by the map's copies, and let go
    /// of by any copy whose ground changes.
    private(set) var lie = LieOfTheLand()
    /// Each tile's hold as the holds that last asked claim it, kept while
    /// the ground is as it is and they stand as they stood: shared by the
    /// map's copies, and let go of by any copy whose ground changes.
    private(set) var claims = Claims()
    /// The nearest hex of a terrain to each hex it was sought from, kept
    /// while the ground is as it is: shared by the map's copies, and let go
    /// of by any copy whose ground changes.
    private(set) var nearest = Nearest()
    /// The deepest of its open water, kept while the ground is as it is:
    /// shared by the map's copies, and let go of by any copy whose ground
    /// changes.
    private(set) var deep = Deepest()
    /// Which relief it has: shared by the map's copies and by the maps a
    /// keeper is shown of it (`unexplored`, `known(by:from:)`), which keep
    /// its relief, and let go of by any copy whose relief changes; two maps
    /// that share it have the same relief, though not a tile of it is
    /// compared.
    private(set) var reliefOf = ReliefOf()

    private enum CodingKeys: String, CodingKey {
        case radius
        case tiles
        /// Three bytes a tile, base64: terrain, feature (0 for none),
        /// relief. Maps were kept so before their ground went as its runs.
        case cells
        /// The terrain and feature of every tile, each as its runs
        /// (`WorldMap.ground(of:)`).
        case ground
        /// Every tile's relief, each as its difference from the one before
        /// it (`WorldMap.relief(of:)`).
        case relief
    }

    public init(radius: Int, fill: Tile) {
        precondition(radius >= 1, "radius must be positive")
        self.radius = radius
        self.tiles = Array(repeating: fill, count: WorldMap.count(radius: radius))
        steps = Array(repeating: WorldMap.step(onto: fill.terrain), count: WorldMap.count(radius: radius))
        self.rowStarts = WorldMap.rowStarts(radius: radius)
        hexList = WorldMap.hexes(radius: radius)
        neighbours = WorldMap.neighbours(radius: radius, of: hexList)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let radius = try container.decode(Int.self, forKey: .radius)
        let tiles: [Tile]
        if let ground = try container.decodeIfPresent(String.self, forKey: .ground) {
            guard let decoded = WorldMap.tiles(ground: ground, relief: try container.decode(String.self, forKey: .relief)) else {
                throw DecodingError.dataCorruptedError(forKey: .ground, in: container, debugDescription: "Unreadable ground")
            }
            tiles = decoded
        } else if let cells = try container.decodeIfPresent(String.self, forKey: .cells) {
            guard let decoded = WorldMap.tiles(fromCells: cells) else {
                throw DecodingError.dataCorruptedError(forKey: .cells, in: container, debugDescription: "Unreadable tiles")
            }
            tiles = decoded
        } else {
            tiles = try container.decode([Tile].self, forKey: .tiles)
        }
        guard let map = WorldMap(radius: radius, tiles: tiles) else {
            throw DecodingError.dataCorruptedError(forKey: .tiles, in: container, debugDescription: "Tile count doesn't match the radius")
        }
        self = map
    }

    /// A map of these tiles, row by row; nil if they aren't as many as a
    /// world of this radius has.
    init?(radius: Int, tiles: [Tile]) {
        guard radius >= 1, tiles.count == WorldMap.count(radius: radius) else { return nil }
        self.radius = radius
        self.tiles = tiles
        rowStarts = WorldMap.rowStarts(radius: radius)
        hexList = WorldMap.hexes(radius: radius)
        neighbours = WorldMap.neighbours(radius: radius, of: hexList)
        steps = tiles.map { WorldMap.step(onto: $0.terrain) }
    }

    /// This map as one who has explored none of it knows it: every tile as
    /// `GameState.unknown` tells it.
    public var unexplored: WorldMap {
        var map = self
        map.tiles = tiles.map(GameState.unknown)
        map.steps = map.tiles.map { WorldMap.step(onto: $0.terrain) }
        map.forget()
        // The lie of the land is known, however little of the land is: its
        // relief is this map's.
        assert(map.tiles.lazy.map(\.relief).elementsEqual(tiles.lazy.map(\.relief)), "Unknown ground keeps its relief")
        return map
    }

    /// This map as one who has explored the tiles `known` marks knows it:
    /// `unexplored`, this map as `unexplored` gives it, with each tile known
    /// as it is here. Worked out from the tiles known alone, so a House
    /// that has explored a little of a wide lake costs a little.
    func known(by known: Explored, from unexplored: WorldMap) -> WorldMap {
        precondition(unexplored.count == count, "The unexplored map of another world")
        var map = unexplored
        var any = false
        known.forEachSeen { index in
            guard index < tiles.count else { return }
            if !any {
                any = true
                // Its ground is not the unexplored map's: what that one keeps
                // of its own ground is not this one's.
                map.forget()
            }
            map.tiles[index] = tiles[index]
            map.steps[index] = steps[index]
        }
        // Its relief this map's where the unexplored map's was this map's;
        // else some of each.
        if any, map.reliefOf !== reliefOf { map.reliefOf = ReliefOf() }
        return map
    }

    /// Whether its relief is `other`'s, tile for tile: at a glance where
    /// both have the relief of one map.
    func hasTheRelief(of other: WorldMap) -> Bool {
        reliefOf === other.reliefOf || (count == other.count && tiles.lazy.map(\.relief).elementsEqual(other.tiles.lazy.map(\.relief)))
    }

    /// What it keeps of its ground let go of, for ground of its own.
    private mutating func forget() {
        lie = LieOfTheLand()
        claims = Claims()
        nearest = Nearest()
        deep = Deepest()
    }

    /// What stepping onto ground costs, 0 where it can't be entered.
    static func step(onto terrain: Terrain) -> UInt8 {
        terrain.isPassable ? UInt8(terrain.moveCost) : 0
    }

    // The rest of a map is laid out from its radius.
    public static func == (a: WorldMap, b: WorldMap) -> Bool {
        a.radius == b.radius && a.tiles == b.tiles
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(radius, forKey: .radius)
        try container.encode(WorldMap.ground(of: tiles), forKey: .ground)
        try container.encode(WorldMap.relief(of: tiles), forKey: .relief)
    }

    // The order of terrains and features is part of the stored world: new
    // ones go at the end.

    /// A run of tiles' ground, base64: how many tiles there are, then the
    /// terrain of each as its runs (how many tiles, then which terrain),
    /// then each one's feature so (0 for none, else its place and one).
    /// The lake's ground lies together, so a page of the map is a few
    /// hundred runs, and a House that knows a little of the lake is told a
    /// little; the relief goes apart (`relief(of:)`), as it is the same
    /// however much of the lake is known.
    static func ground<Tiles: Collection>(of tiles: Tiles) -> String where Tiles.Element == Tile {
        var bytes: [UInt8] = []
        Varint.append(tiles.count, to: &bytes)
        runs(of: tiles.lazy.map { tile in tile.terrain.code }, into: &bytes)
        runs(of: tiles.lazy.map { tile in tile.feature.map { $0.code + 1 } ?? 0 }, into: &bytes)
        return Data(bytes).base64EncodedString()
    }

    private static func runs<Codes: Sequence>(of codes: Codes, into bytes: inout [UInt8]) where Codes.Element == UInt8 {
        var code: UInt8?
        var run = 0
        for next in codes {
            if next == code {
                run += 1
                continue
            }
            if let code {
                Varint.append(run, to: &bytes)
                bytes.append(code)
            }
            code = next
            run = 1
        }
        if let code {
            Varint.append(run, to: &bytes)
            bytes.append(code)
        }
    }

    /// A run of tiles' relief, base64: how many tiles there are, then each
    /// one's relief as its difference from the one before it (the first's
    /// from none). The land rises and falls by a little from tile to tile,
    /// so each is a byte.
    static func relief<Tiles: Collection>(of tiles: Tiles) -> String where Tiles.Element == Tile {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(tiles.count + 3)
        Varint.append(tiles.count, to: &bytes)
        var last = 0
        for tile in tiles {
            Varint.append(Varint.zigzag(tile.relief &- last), to: &bytes)
            last = tile.relief
        }
        return Data(bytes).base64EncodedString()
    }

    /// The tiles `ground(of:)` and `relief(of:)` wrote; nil unless each
    /// reads whole and both tell of the same tiles.
    static func tiles(ground: String, relief: String) -> [Tile]? {
        guard let reliefs = reliefs(fromText: relief), var tiles = tiles(fromGround: ground, count: reliefs.count) else { return nil }
        for index in tiles.indices { tiles[index].relief = reliefs[index] }
        return tiles
    }

    /// Each tile's relief as `relief(of:)` wrote it; nil unless it reads
    /// whole.
    static func reliefs(fromText text: String) -> [Int]? {
        guard let data = Data(base64Encoded: text) else { return nil }
        var read = Varint.Reader([UInt8](data))
        // A byte at the least for each tile's: no more tiles than bytes.
        guard let count = read.count(), count <= data.count else { return nil }
        var reliefs: [Int] = []
        reliefs.reserveCapacity(count)
        var relief = 0
        for _ in 0..<count {
            guard let step = read.next() else { return nil }
            relief &+= Varint.unzigzag(step)
            reliefs.append(relief)
        }
        return read.isAtEnd ? reliefs : nil
    }

    /// The `count` tiles `ground(of:)` wrote, their relief none; nil unless
    /// it tells of `count` tiles and reads whole.
    static func tiles(fromGround text: String, count: Int) -> [Tile]? {
        guard let data = Data(base64Encoded: text) else { return nil }
        var read = Varint.Reader([UInt8](data))
        guard read.count() == count else { return nil }
        func codes(below limit: Int) -> [UInt8]? {
            var codes: [UInt8] = []
            codes.reserveCapacity(count)
            while codes.count < count {
                guard let run = read.count(), run >= 1, run <= count - codes.count, let code = read.byte(), Int(code) < limit else { return nil }
                codes.append(contentsOf: repeatElement(code, count: run))
            }
            return codes
        }
        let terrains = Terrain.allCases, features = Feature.allCases
        guard let terrain = codes(below: terrains.count), let feature = codes(below: features.count + 1), read.isAtEnd else { return nil }
        return zip(terrain, feature).map { terrain, feature in
            Tile(terrain: terrains[Int(terrain)], feature: feature == 0 ? nil : features[Int(feature) - 1])
        }
    }

    /// The tiles of a map kept before its ground went as its runs: three
    /// bytes a tile, base64 (terrain, feature or 0, relief).
    static func tiles(fromCells text: String) -> [Tile]? {
        guard let data = Data(base64Encoded: text), data.count % 3 == 0 else { return nil }
        let bytes = [UInt8](data)
        var tiles: [Tile] = []
        tiles.reserveCapacity(bytes.count / 3)
        for start in stride(from: 0, to: bytes.count, by: 3) {
            let terrain = Int(bytes[start]), feature = Int(bytes[start + 1])
            guard terrain < Terrain.allCases.count, feature <= Feature.allCases.count else { return nil }
            tiles.append(Tile(terrain: Terrain.allCases[terrain], feature: feature == 0 ? nil : Feature.allCases[feature - 1],
                              relief: Int(bytes[start + 2])))
        }
        return tiles
    }

    private static func rowStarts(radius: Int) -> [Int] {
        var starts: [Int] = []
        var start = 0
        for row in -radius...radius {
            starts.append(start)
            start += 2 * radius + 1 - abs(row)
        }
        return starts
    }

    /// Number of hexes within `radius` of the origin.
    public static func count(radius: Int) -> Int {
        3 * radius * (radius + 1) + 1
    }

    public var count: Int { tiles.count }

    public func contains(_ hex: Hex) -> Bool {
        // A hex of the world has each coordinate within the radius. Reject
        // anything past that by comparison alone, before `length`: a hex
        // from a keeper's order carries client-chosen coordinates, and ones
        // near the limits of Int would overflow the sum in `Hex.distance`.
        guard hex.q >= -radius, hex.q <= radius, hex.r >= -radius, hex.r <= radius else { return false }
        return hex.length <= radius
    }

    /// The tile index of a hex, or nil outside the world.
    public func index(of hex: Hex) -> Int? {
        guard contains(hex) else { return nil }
        let r = hex.r
        let qMin = max(-radius, -r - radius)
        return rowStarts[r + radius] + hex.q - qMin
    }

    /// Each tile within `range` of a hex, by its index, in the order
    /// `Hex.forEach(within:)` walks them, those off the map left out. The
    /// tiles are kept row by row, so each row of the disc is a run of
    /// indices side by side: found by its ends, not hex by hex.
    func forEachIndex(within range: Int, of centre: Hex, _ body: (Int) -> Void) {
        let range = max(range, 0)
        for dr in -range...range {
            let r = centre.r + dr
            guard r >= -radius, r <= radius else { continue }
            let first = max(-radius, -r - radius)
            let low = max(centre.q + max(-range, -dr - range), first)
            let high = min(centre.q + min(range, range - dr), min(radius, radius - r))
            guard low <= high else { continue }
            let base = rowStarts[r + radius] - first
            for q in low...high { body(base + q) }
        }
    }

    /// The hex at a tile index.
    public func hex(at index: Int) -> Hex {
        precondition(tiles.indices.contains(index), "index out of range")
        var remaining = index
        var r = -radius
        while true {
            let width = 2 * radius + 1 - abs(r)
            if remaining < width {
                let qMin = max(-radius, -r - radius)
                return Hex(qMin + remaining, r)
            }
            remaining -= width
            r += 1
        }
    }

    /// Every hex in index order.
    public var hexes: [Hex] { hexList }

    private static func neighbours(radius: Int, of hexes: [Hex]) -> [Int32] {
        let starts = rowStarts(radius: radius)
        var neighbours: [Int32] = []
        neighbours.reserveCapacity(hexes.count * 6)
        for hex in hexes {
            for direction in Hex.directions {
                let next = hex + direction
                guard next.q >= -radius, next.q <= radius, next.r >= -radius, next.r <= radius, next.length <= radius else {
                    neighbours.append(-1)
                    continue
                }
                neighbours.append(Int32(starts[next.r + radius] + next.q - max(-radius, -next.r - radius)))
            }
        }
        return neighbours
    }

    private static func hexes(radius: Int) -> [Hex] {
        var result: [Hex] = []
        result.reserveCapacity(count(radius: radius))
        for r in -radius...radius {
            let qMin = max(-radius, -r - radius)
            let qMax = min(radius, -r + radius)
            for q in qMin...qMax {
                result.append(Hex(q, r))
            }
        }
        return result
    }

    public subscript(hex: Hex) -> Tile? {
        guard let index = index(of: hex) else { return nil }
        return tiles[index]
    }

    public subscript(index: Int) -> Tile {
        get { tiles[index] }
        set { set(index: index, newValue) }
    }

    mutating func set(index: Int, _ tile: Tile) {
        // Relief its other copies still have is theirs.
        if tiles[index].relief != tile.relief { reliefOf = ReliefOf() }
        tiles[index] = tile
        // Claims its other copies still keep are theirs, of their ground.
        if isKnownUniquelyReferenced(&claims) { claims.clear() } else { claims = Claims() }
        if isKnownUniquelyReferenced(&nearest) { nearest.clear() } else { nearest = Nearest() }
        if isKnownUniquelyReferenced(&deep) { deep.clear() } else { deep = Deepest() }
        let step = WorldMap.step(onto: tile.terrain)
        if steps[index] != step {
            // A lie its other copies still keep is theirs, of their ground.
            if isKnownUniquelyReferenced(&lie) { lie.clear() } else { lie = LieOfTheLand() }
        }
        steps[index] = step
    }

    /// The hex of a terrain nearest a hex, the lowest q and then r among
    /// those as near; nil if the map has none. Found ring by ring out from
    /// the hex once, and kept while the ground is as it is.
    public func nearest(_ terrain: Terrain, to hex: Hex) -> Hex? {
        if let known = nearest.hex(of: terrain, near: hex) { return known }
        var found: Hex?
        for distance in 0...(2 * radius + 1) {
            found = hex.ring(distance).filter { self[$0]?.terrain == terrain }.min { ($0.q, $0.r) < ($1.q, $1.r) }
            if found != nil { break }
        }
        nearest.keep(found, of: terrain, near: hex)
        return found
    }

    public mutating func set(_ hex: Hex, _ tile: Tile) {
        guard let index = index(of: hex) else { return }
        set(index: index, tile)
    }

    public func neighbors(of hex: Hex) -> [Hex] {
        hex.neighbors.filter(contains)
    }
}

/// The open water farthest from any shore, and how far: where the full
/// moon's reflection lies.
public struct DeepWater: Codable, Equatable, Sendable {
    public let hex: Hex
    public let depth: Int

    public init(hex: Hex, depth: Int) {
        self.hex = hex
        self.depth = depth
    }
}

extension WorldMap {
    /// The hex of open water farthest from any shore; of equals, the
    /// nearest the middle of the world. Nil when there is no open water.
    public func deepestWater() -> DeepWater? {
        if let kept = deep.water { return kept }
        let found = seekDeepestWater()
        deep.keep(found)
        return found
    }

    /// The deepest water, sought through every tile of the lake.
    func seekDeepestWater() -> DeepWater? {
        // Hexes of open water, by their distance from anything that isn't.
        var depth = [Int](repeating: -1, count: count)
        var frontier: [Int] = []
        for index in 0..<count where self[index].terrain != .still {
            depth[index] = 0
            frontier.append(index)
        }
        let hexes = self.hexes
        var head = 0
        while head < frontier.count {
            let index = frontier[head]
            head += 1
            for neighbour in neighbors(of: hexes[index]) {
                guard let next = self.index(of: neighbour), depth[next] < 0 else { continue }
                depth[next] = depth[index] + 1
                frontier.append(next)
            }
        }
        guard let deepest = depth.indices.max(by: { a, b in
            (depth[a], -hexes[a].length, -a) < (depth[b], -hexes[b].length, -b)
        }), depth[deepest] > 0 else { return nil }
        return DeepWater(hex: hexes[deepest], depth: depth[deepest])
    }
}
