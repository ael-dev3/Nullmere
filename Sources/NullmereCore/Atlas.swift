/// What every keeper of a realm knows of its land from the first watch, as
/// a map of it would show: the streams that run from the Spine down to the
/// lake, each with its name and course; the regions of the shores between
/// them, each with its name; and the crest the lake gave each House. Kept
/// with the world, and whole in every keeper's view, the fog over the land
/// or not.
public struct Atlas: Codable, Equatable, Sendable {
    /// A stream: its name, and its course from its spring under the Spine
    /// to its mouth on the lake.
    public struct River: Codable, Equatable, Sendable {
        public var name: String
        public var course: [Hex]

        public init(name: String, course: [Hex]) {
            self.name = name
            self.course = course
        }
    }

    /// A region of the shores: its name, and its heart, where the map
    /// writes its name.
    public struct Region: Codable, Equatable, Sendable {
        public var name: String
        public var heart: Hex

        public init(name: String, heart: Hex) {
            self.name = name
            self.heart = heart
        }
    }

    public var rivers: [River]
    public var regions: [Region]
    /// The crest the lake gave each House, by its id.
    public var crests: [Crest]

    public init(rivers: [River], regions: [Region], crests: [Crest]) {
        self.rivers = rivers
        self.regions = regions
        self.crests = crests
    }

    /// The atlas of a world grown from `seed` (its words `seedText`): its
    /// streams' courses and its regions' hearts as the world was made, each
    /// named, and the crests the lake gave its `seats` Houses. Named with
    /// randomness of its own, never the world's.
    public init(streams: [[Hex]], hearts: [Hex], seats: Int, seed: UInt64, seedText: String) {
        var random = SeededRandom(seed: Seed.mix(seed, 0xA71A5))
        var riverNames = Atlas.riverNames, regionNames = Atlas.regionNames
        random.shuffle(&riverNames)
        random.shuffle(&regionNames)
        rivers = streams.enumerated().map { River(name: riverNames[$0.offset % riverNames.count], course: $0.element) }
        regions = hearts.enumerated().map { Region(name: regionNames[$0.offset % regionNames.count], heart: $0.element) }
        crests = (0..<seats).map { Crest.given(to: $0, seedText: seedText) }
    }

    /// What the streams are called.
    public static let riverNames = [
        "the Lorn", "the Wending", "the Brack", "the Hollin", "the Sallow", "the Withy", "the Tarnrun", "the Coldwell",
        "the Murrow", "the Ashburn", "the Greywell", "the Lammer", "the Skirl", "the Ebbing", "the Dunlin", "the Quill",
        "the Mosswater", "the Wren", "the Blackbrook", "the Shiver",
    ]

    /// What the regions of the shores are called.
    public static let regionNames = [
        "the Reedmarch", "the Heronfens", "Saltreach", "the Cold Leas", "Larkstead", "Thornwick", "the Ashfields",
        "the Lantern Shore", "the Gloaming", "the Hagstones", "Fernmoor", "the Pale Reach", "the Low Combe", "Owlcrook",
        "the Sedgelands", "Candlefell", "the Hollow Downs", "Moorwatch", "the Rimeholt", "Bellwether Vale",
    ]

    /// The region each hex of `map` lies in, by its index; nil on a
    /// stream's course and the lines that carry each stream on, from its
    /// mouth to the lake's heart and from its spring to the edge of the
    /// world. Worked out from the atlas alone, the same in the realm and in
    /// every keeper's view: out from each region's heart a step at a time,
    /// the nearest heart first, never across a stream or its lines.
    public func regionIndices(over map: WorldMap) -> [Int?] {
        var owner = [Int?](repeating: nil, count: map.count)
        guard !regions.isEmpty else { return owner }
        var wall = [Bool](repeating: false, count: map.count)
        func shut(_ hexes: [Hex]) {
            for hex in hexes { if let index = map.index(of: hex) { wall[index] = true } }
        }
        for river in rivers {
            guard let spring = river.course.first, let mouth = river.course.last else { continue }
            shut(river.course)
            shut(mouth.line(to: .origin))
            shut(spring.line(to: Atlas.edge(beyond: spring, radius: map.radius)))
        }
        var queue: [Int] = []
        for (number, region) in regions.enumerated() {
            guard let index = map.index(of: region.heart), owner[index] == nil else { continue }
            owner[index] = number
            queue.append(index)
        }
        let hexes = map.hexes
        var head = 0
        while head < queue.count {
            let index = queue[head]
            head += 1
            for neighbour in map.neighbors(of: hexes[index]) {
                guard let next = map.index(of: neighbour), owner[next] == nil, !wall[next] else { continue }
                owner[next] = owner[index]
                queue.append(next)
            }
        }
        return owner
    }

    /// The hex at the world's edge straight out from the lake's heart
    /// through `hex`.
    static func edge(beyond hex: Hex, radius: Int) -> Hex {
        let length = max(hex.length, 1)
        var q = Int((Double(hex.q * radius) / Double(length)).rounded())
        var r = Int((Double(hex.r * radius) / Double(length)).rounded())
        while Hex(q, r).length > radius {
            // Back in a step, toward the heart.
            if abs(q) >= abs(r) { q -= q.signum() } else { r -= r.signum() }
        }
        return Hex(q, r)
    }

    /// The stream whose course runs through `hex`, if one does.
    public func river(at hex: Hex) -> River? {
        rivers.first { $0.course.contains(hex) }
    }
}

extension GameState {
    /// The region of the shores a hex lies in, if the world has regions and
    /// the hex lies in one.
    public func region(of hex: Hex, among regions: [Int?]? = nil) -> Atlas.Region? {
        guard let atlas, let index = map.index(of: hex) else { return nil }
        let owners = regions ?? atlas.regionIndices(over: map)
        guard owners.indices.contains(index), let region = owners[index], atlas.regions.indices.contains(region) else { return nil }
        return atlas.regions[region]
    }
}
