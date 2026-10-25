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

    public init(seed: UInt64, radius: Int = 24, houseCount: Int = 5) {
        precondition(radius >= 12, "the world needs room for a lake and its shores")
        precondition((2...8).contains(houseCount), "between two and eight Houses")
        self.seed = seed
        self.radius = radius
        self.houseCount = houseCount
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
            if p.d + wobble * 0.32 < 0.48 {
                map[index] = Tile(terrain: .still)
            } else if p.d + edge * 0.14 > 0.9 || hex.length == radius {
                map[index] = Tile(terrain: .spine)
            }
        }

        // 2. Islands, deep in the lake.
        var islandCentres: [Hex] = []
        let deep = hexes.filter { hex in
            let p = position(hex)
            return p.d < 0.26 && map[hex]?.terrain == .still
        }
        if !deep.isEmpty {
            let count = 2 + random.int(below: 2)
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
