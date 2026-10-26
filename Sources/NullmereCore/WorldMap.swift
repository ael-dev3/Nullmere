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

    private enum CodingKeys: String, CodingKey {
        case radius
        case tiles
    }

    public init(radius: Int, fill: Tile) {
        precondition(radius >= 1, "radius must be positive")
        self.radius = radius
        self.tiles = Array(repeating: fill, count: WorldMap.count(radius: radius))
        self.rowStarts = WorldMap.rowStarts(radius: radius)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        radius = try container.decode(Int.self, forKey: .radius)
        tiles = try container.decode([Tile].self, forKey: .tiles)
        guard radius >= 1, tiles.count == WorldMap.count(radius: radius) else {
            throw DecodingError.dataCorruptedError(forKey: .tiles, in: container, debugDescription: "Tile count doesn't match the radius")
        }
        rowStarts = WorldMap.rowStarts(radius: radius)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(radius, forKey: .radius)
        try container.encode(tiles, forKey: .tiles)
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
        hex.length <= radius
    }

    /// The tile index of a hex, or nil outside the world.
    public func index(of hex: Hex) -> Int? {
        guard contains(hex) else { return nil }
        let r = hex.r
        let qMin = max(-radius, -r - radius)
        return rowStarts[r + radius] + hex.q - qMin
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
    public var hexes: [Hex] {
        var result: [Hex] = []
        result.reserveCapacity(count)
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
        set { tiles[index] = newValue }
    }

    public mutating func set(_ hex: Hex, _ tile: Tile) {
        guard let index = index(of: hex) else { return }
        tiles[index] = tile
    }

    public func neighbors(of hex: Hex) -> [Hex] {
        hex.neighbors.filter(contains)
    }
}
