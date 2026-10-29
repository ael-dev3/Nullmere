/// The shape of the black water. Each age of the realm lies on a lake of
/// its own shape, in turn.
public enum Lake: String, Codable, CaseIterable, Sendable {
    /// One round lake: the Nullmere as the first age knew it.
    case round
    /// Two lakes side by side, with a neck of land between.
    case twin
    /// A crescent, the land pushing in from one shore.
    case crescent
    /// A wider lake, crowded with drowned isles.
    case isles

    public var title: String {
        switch self {
        case .round: return "the Nullmere"
        case .twin: return "the Twin Waters"
        case .crescent: return "the Sickle"
        case .isles: return "the Drowned Isles"
        }
    }

    /// The lake of an age of the realm: the round lake first, then each
    /// shape in turn.
    public static func of(age: Int) -> Lake {
        allCases[(max(age, 1) - 1) % allCases.count]
    }
}

/// Builds a world: a basin walled by the Spine, with the black lake of the
/// Nullmere at its heart, a ring of shore and farmland around it, forest and
/// barrows toward the mountains, and islands in the lake carrying the ruins
/// of whoever came before. The same seed always gives the same world.
public struct WorldGenerator: Sendable {
    public struct Result: Sendable {
        public var map: WorldMap
        /// One seat position per House, spread evenly around the lake.
        public var seats: [Hex]
    }

    public let seed: UInt64
    public let radius: Int
    public let houseCount: Int
    public let lake: Lake

    /// The most Houses a lake seats.
    public static let mostHouses = 12

    public init(seed: UInt64, radius: Int = 24, houseCount: Int = 5, lake: Lake = .round) {
        precondition(radius >= 12, "the world needs room for a lake and its shores")
        precondition((2...WorldGenerator.mostHouses).contains(houseCount), "between two and twelve Houses")
        self.seed = seed
        self.radius = radius
        self.houseCount = houseCount
        self.lake = lake
    }

    /// How far a point lies from open water, for the lake's shape: under
    /// 0.48 is the lake, under 0.26 its deep heart.
    func lakeDistance(x: Double, y: Double, d: Double) -> Double {
        switch lake {
        case .round:
            return d
        case .twin:
            let west = ((x + 0.36) * (x + 0.36) + y * y).squareRoot()
            let east = ((x - 0.36) * (x - 0.36) + y * y).squareRoot()
            return min(west, east) * 1.45
        case .crescent:
            let bite = (x * x + (y - 0.3) * (y - 0.3)).squareRoot()
            return bite < 0.3 ? max(d, 0.5 + (0.3 - bite)) : d
        case .isles:
            return d * 0.86
        }
    }

    public func generate() -> Result {
        var map = WorldMap(radius: radius, fill: Tile(terrain: .greyfield))
        let hexes = map.hexes
        let layout = HexLayout()
        let lakeNoise = ValueNoise(seed: Seed.mix(seed, 1))
        let rimNoise = ValueNoise(seed: Seed.mix(seed, 2))
        let woodNoise = ValueNoise(seed: Seed.mix(seed, 3))
        let hillNoise = ValueNoise(seed: Seed.mix(seed, 4))
        let saltNoise = ValueNoise(seed: Seed.mix(seed, 5))
        let reliefNoise = ValueNoise(seed: Seed.mix(seed, 6))
        var random = SeededRandom(seed: Seed.mix(seed, 7))

        let width = 3.0.squareRoot() * Double(radius)
        let height = 1.5 * Double(radius)
        func position(_ hex: Hex) -> (x: Double, y: Double, d: Double) {
            let c = layout.center(of: hex)
            let x = c.x / width
            let y = c.y / height
            return (x, y, (x * x + y * y).squareRoot())
        }

        // 1. Lake and rim.
        for (index, hex) in hexes.enumerated() {
            let p = position(hex)
            let wobble = lakeNoise.fractal(p.x * 2.4 + 11, p.y * 2.4 + 7) - 0.5
            let edge = rimNoise.fractal(p.x * 3 + 3, p.y * 3 + 5) - 0.5
            if lakeDistance(x: p.x, y: p.y, d: p.d) + wobble * 0.32 < 0.48 {
                map[index] = Tile(terrain: .still)
            } else if p.d + edge * 0.14 > 0.9 || hex.length == radius {
                map[index] = Tile(terrain: .spine)
            }
        }

        // 2. Islands, deep in the lake.
        var islandCentres: [Hex] = []
        let deep = hexes.filter { hex in
            let p = position(hex)
            return lakeDistance(x: p.x, y: p.y, d: p.d) < 0.26 && map[hex]?.terrain == .still
        }
        if !deep.isEmpty {
            let count = lake == .isles ? 5 + random.int(below: 2) : 2 + random.int(below: 2)
            for _ in 0..<(count * 8) where islandCentres.count < count {
                let candidate = random.pick(deep)
                if islandCentres.allSatisfy({ $0.distance(to: candidate) >= 5 }) {
                    islandCentres.append(candidate)
                }
            }
            for centre in islandCentres {
                map.set(centre, Tile(terrain: .barrow, feature: .drownedRuin))
                for neighbor in map.neighbors(of: centre) where random.chance(55) {
                    map.set(neighbor, Tile(terrain: random.chance(50) ? .strand : .blackwood))
                }
            }
        }

        // 3. Land bands, measured from the water.
        let fromWater = distances(in: map, from: hexes.filter { map[$0]?.terrain == .still })
        for (index, hex) in hexes.enumerated() {
            let tile = map[index]
            guard tile.terrain != .still, tile.terrain != .spine, tile.feature == nil else { continue }
            guard !islandCentres.contains(where: { $0.distance(to: hex) <= 1 }) else { continue }
            let p = position(hex)
            let shore = fromWater[index]
            let wood = woodNoise.fractal(p.x * 4.2 + 1, p.y * 4.2 + 9)
            let hill = hillNoise.fractal(p.x * 3.6 + 4, p.y * 3.6 + 2)
            let outer = max(0, p.d - 0.62) * 0.9
            let terrain: Terrain
            if shore <= 1 {
                terrain = saltNoise.fractal(p.x * 5 + 2, p.y * 5 + 8) > 0.53 ? .saltFlat : .strand
            } else if hill + outer > 0.66, shore >= 3 {
                terrain = .barrow
            } else if wood + outer > 0.56 {
                terrain = .blackwood
            } else {
                terrain = .greyfield
            }
            map[index] = Tile(terrain: terrain)
        }

        // 4. Water near any land is dead shallows; the rest is the Still.
        let fromLand = distances(in: map, from: hexes.filter { !(map[$0]?.terrain.isWater ?? true) })
        for (index, _) in hexes.enumerated() where map[index].terrain == .still && fromLand[index] <= 2 {
            map[index] = Tile(terrain: .shallows)
        }

        // 5. Causeways: every island must be reachable on foot.
        let mainland = hexes.first { hex in
            map[hex]?.terrain.isSettleable == true && position(hex).d > 0.5
        } ?? hexes[0]
        for centre in islandCentres {
            let reachable = reachableSet(in: map, from: mainland)
            guard let centreIndex = map.index(of: centre), !reachable.contains(centreIndex) else { continue }
            let target = hexes
                .filter { reachable.contains(map.index(of: $0)!) }
                .min { ($0.distance(to: centre), $0) < ($1.distance(to: centre), $1) } ?? mainland
            for hex in centre.line(to: target) where map[hex]?.terrain == .still {
                map.set(hex, Tile(terrain: .shallows))
            }
        }

        // 6. Features.
        for (index, hex) in hexes.enumerated() where map[index].feature == nil {
            var cellRandom = SeededRandom(seed: Seed.mix(seed, 8, UInt64(index)))
            let feature: Feature?
            switch map[index].terrain {
            case .saltFlat: feature = cellRandom.chance(30) ? .moonsaltBed : nil
            case .blackwood: feature = cellRandom.chance(9) ? .elderGrove : nil
            case .barrow: feature = cellRandom.chance(12) ? .stoneSeam : nil
            case .greyfield: feature = cellRandom.chance(8) ? .darkLoam : nil
            default: feature = nil
            }
            map[index].feature = feature
            let p = position(hex)
            map[index].relief = Int((reliefNoise.fractal(p.x * 6, p.y * 6) * 100).rounded())
        }

        // 7. Seats, as far apart as possible, a short walk from the shore.
        let candidates = hexes.filter { hex in
            guard let index = map.index(of: hex), map[index].terrain.isSettleable else { return false }
            let shore = fromWater[index]
            return (2...5).contains(shore) && position(hex).d < 0.8
                && !map.neighbors(of: hex).contains { map[$0]?.terrain == .spine }
        }
        var seats: [Hex] = []
        if !candidates.isEmpty {
            seats.append(random.pick(candidates))
            while seats.count < houseCount {
                let next = candidates.max { a, b in
                    let da = seats.map { $0.distance(to: a) }.min()!
                    let db = seats.map { $0.distance(to: b) }.min()!
                    return (da, b) < (db, a)
                }!
                seats.append(next)
            }
            // Picked so, the last few are squeezed between the first: each
            // in turn moves to the nearby site furthest from its nearest
            // neighbour, a few times over, until they lie evenly spread.
            let sites = Set(candidates)
            for _ in 0..<4 {
                for i in seats.indices {
                    let others = seats.indices.filter { $0 != i }.map { seats[$0] }
                    // Room enough from its neighbours, then, among the
                    // roomiest sites, the most land nearer it than any other
                    // seat.
                    func room(_ hex: Hex) -> Int { min(others.map { $0.distance(to: hex) }.min() ?? 0, 12) }
                    func land(_ hex: Hex) -> Int {
                        hex.spiral(6).filter { tile in
                            guard let index = map.index(of: tile), map[index].terrain.isSettleable else { return false }
                            let mine = tile.distance(to: hex)
                            return others.allSatisfy { $0.distance(to: tile) > mine }
                        }.count
                    }
                    let near = seats[i].spiral(3).filter { sites.contains($0) && !others.contains($0) }.map { ($0, room($0)) }
                    guard let roomiest = near.map(\.1).max(), roomiest >= room(seats[i]) else { continue }
                    let finalists = near.filter { $0.1 == roomiest }.map { ($0.0, land($0.0)) }
                    let here = (room(seats[i]), land(seats[i]))
                    if let best = finalists.max(by: { ($0.1, $1.0) < ($1.1, $0.0) }), (roomiest, best.1) > here {
                        seats[i] = best.0
                    }
                }
            }
            // A seat left with little land of its own, hemmed in by water,
            // the Spine or its neighbours, moves to the best site anywhere
            // still well apart from the rest.
            func ownLand(_ hex: Hex, among others: [Hex]) -> Int {
                hex.spiral(6).filter { tile in
                    guard let index = map.index(of: tile), map[index].terrain.isSettleable else { return false }
                    let mine = tile.distance(to: hex)
                    return others.allSatisfy { $0.distance(to: tile) > mine }
                }.count
            }
            let lands = seats.indices.map { i in ownLand(seats[i], among: seats.indices.filter { $0 != i }.map { seats[$0] }) }
            let median = lands.sorted()[lands.count / 2]
            for i in seats.indices where lands[i] * 2 < median {
                let others = seats.indices.filter { $0 != i }.map { seats[$0] }
                let apart = candidates.filter { site in others.allSatisfy { $0.distance(to: site) >= 8 } }
                if let best = apart.map({ ($0, ownLand($0, among: others)) }).max(by: { ($0.1, $1.0) < ($1.1, $0.0) }),
                   best.1 > lands[i] {
                    seats[i] = best.0
                }
            }
            // Which House sits where is the luck of the draw, not the order
            // the seats were found in.
            random.shuffle(&seats)
        }

        // 8. Every seat gets a fair start.
        for seat in seats {
            provision(seat: seat, in: &map)
        }

        // 9. Ruins on the far shores, away from every seat.
        let shores = hexes.filter { hex in
            guard let tile = map[hex] else { return false }
            return tile.terrain == .strand && tile.feature == nil
        }
        let farShores = shores
            .map { hex in (hex, seats.map { $0.distance(to: hex) }.min() ?? 0) }
            .filter { $0.1 >= 6 }
            .sorted { ($0.1, $0.0) > ($1.1, $1.0) }
        for (hex, _) in farShores.prefix(3) {
            map.set(hex, Tile(terrain: .strand, feature: .drownedRuin, relief: map[hex]?.relief ?? 0))
        }

        return Result(map: map, seats: seats)
    }

    /// Makes sure the land around a seat can feed and build a House.
    private func provision(seat: Hex, in map: inout WorldMap) {
        map.set(seat, Tile(terrain: .greyfield, relief: map[seat]?.relief ?? 0))
        let around = seat.spiral(2).dropFirst().filter { hex in
            guard let tile = map[hex] else { return false }
            return tile.terrain.isSettleable
        }
        func count(_ terrain: Terrain) -> Int {
            around.filter { map[$0]?.terrain == terrain }.count
        }
        let needs: [(Terrain, Int)] = [(.greyfield, 4), (.blackwood, 3), (.barrow, 2)]
        let minimums = Dictionary(uniqueKeysWithValues: needs)
        for (terrain, minimum) in needs {
            while count(terrain) < minimum {
                // Take a tile from whichever terrain has the most to spare.
                let donors = around.filter { hex in
                    guard let other = map[hex]?.terrain, other != terrain, map[hex]?.feature == nil else { return false }
                    return count(other) > (minimums[other] ?? 0)
                }
                guard let donor = donors.max(by: { a, b in
                    (count(map[a]!.terrain), b) < (count(map[b]!.terrain), a)
                }) else { break }
                map.set(donor, Tile(terrain: terrain, relief: map[donor]?.relief ?? 0))
            }
        }
        // Every House needs moonsalt within reach: a salt flat on its nearest shore.
        let shoreline = seat.spiral(5).filter { hex in
            guard let tile = map[hex], tile.terrain == .strand || tile.terrain == .saltFlat else { return false }
            return map.neighbors(of: hex).contains { map[$0]?.terrain.isWater == true }
        }
        if !shoreline.contains(where: { map[$0]?.terrain == .saltFlat }),
           let nearest = shoreline.min(by: { ($0.distance(to: seat), $0) < ($1.distance(to: seat), $1) }) {
            map.set(nearest, Tile(terrain: .saltFlat, feature: .moonsaltBed, relief: map[nearest]?.relief ?? 0))
        }
        if !around.contains(where: { map[$0]?.feature != nil }),
           let loam = around.first(where: { map[$0]?.terrain == .greyfield }) {
            map.set(loam, Tile(terrain: .greyfield, feature: .darkLoam, relief: map[loam]?.relief ?? 0))
        }
    }

    /// Steps from the nearest source hex to every tile, over any terrain.
    private func distances(in map: WorldMap, from sources: [Hex]) -> [Int] {
        var result = Array(repeating: Int.max, count: map.count)
        var queue: [Hex] = []
        for hex in sources {
            guard let index = map.index(of: hex) else { continue }
            result[index] = 0
            queue.append(hex)
        }
        var head = 0
        while head < queue.count {
            let hex = queue[head]
            head += 1
            let next = result[map.index(of: hex)!] + 1
            for neighbor in map.neighbors(of: hex) {
                let index = map.index(of: neighbor)!
                if result[index] > next {
                    result[index] = next
                    queue.append(neighbor)
                }
            }
        }
        return result
    }

    /// Tile indices reachable on foot from `start`.
    private func reachableSet(in map: WorldMap, from start: Hex) -> Set<Int> {
        var seen: Set<Int> = []
        guard let startIndex = map.index(of: start) else { return seen }
        seen.insert(startIndex)
        var queue = [start]
        var head = 0
        while head < queue.count {
            let hex = queue[head]
            head += 1
            for neighbor in map.neighbors(of: hex) {
                let index = map.index(of: neighbor)!
                guard !seen.contains(index), map[index].terrain.isPassable else { continue }
                seen.insert(index)
                queue.append(neighbor)
            }
        }
        return seen
    }
}
