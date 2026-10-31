extension GameState {
    /// The cheapest route for a unit from its position to `target`, as the
    /// hexes to step through, not including the start. Hexes holding other
    /// units, and other Houses' holds, are avoided, except the target
    /// itself: a march stops at a foreign hold.
    public func path(for unit: Unit, to target: Hex) -> [Hex]? {
        guard unit.position != target,
              let start = map.index(of: unit.position),
              let goal = map.index(of: target),
              map[goal].terrain.isPassable
        else { return nil }

        let count = map.count
        var blocked = [Bool](repeating: false, count: count)
        for other in units where other.id != unit.id {
            if let index = map.index(of: other.position), index != goal {
                blocked[index] = true
            }
        }
        for hold in holds where hold.owner != unit.owner {
            if let index = map.index(of: hold.position), index != goal {
                blocked[index] = true
            }
        }
        for wild in wildsStanding {
            if let index = map.index(of: wild.position), index != goal {
                blocked[index] = true
            }
        }
        for lair in lairsStanding {
            if let index = map.index(of: lair.position), index != goal {
                blocked[index] = true
            }
        }
        // Only its alliance's companies pass through a hall, or a storehouse.
        for hall in hallsStanding where !isOfHall(unit.owner, hall) {
            if let index = map.index(of: hall.position), index != goal {
                blocked[index] = true
            }
        }
        for storehouse in storehousesStanding where !isOf(storehouse.alliance, unit.owner) {
            if let index = map.index(of: storehouse.position), index != goal {
                blocked[index] = true
            }
        }
        var search = WaySearch(count: count)
        return search.way(on: map, from: start, to: goal, around: blocked)
    }
}

extension GameState {
    /// A way toward a hex that can't be reached: to the hex nearest it that
    /// can, keeping clear of other companies and of other Houses' holds.
    /// Nil when the unit already stands as near as it can come.
    public func approach(for unit: Unit, toward target: Hex) -> [Hex]? {
        guard let start = map.index(of: unit.position) else { return nil }
        var blocked = [Bool](repeating: false, count: map.count)
        for other in units where other.id != unit.id {
            if let index = map.index(of: other.position) { blocked[index] = true }
        }
        for hold in holds where hold.owner != unit.owner {
            if let index = map.index(of: hold.position) { blocked[index] = true }
        }
        for wild in wildsStanding {
            if let index = map.index(of: wild.position) { blocked[index] = true }
        }
        for lair in lairsStanding {
            if let index = map.index(of: lair.position) { blocked[index] = true }
        }
        let hexes = map.hexes
        var cameFrom = [Int](repeating: -2, count: map.count)
        cameFrom[start] = -1
        var queue = [start]
        var head = 0
        var best = start
        func nearer(_ a: Int, than b: Int) -> Bool {
            (hexes[a].distance(to: target), a) < (hexes[b].distance(to: target), b)
        }
        while head < queue.count, head < 6_000 {
            let tile = queue[head]
            head += 1
            if nearer(tile, than: best) { best = tile }
            for direction in Hex.directions {
                guard let next = map.index(of: hexes[tile] + direction), cameFrom[next] == -2, !blocked[next],
                      map[next].terrain.isPassable else { continue }
                cameFrom[next] = tile
                queue.append(next)
            }
        }
        guard best != start else { return nil }
        var route: [Hex] = []
        var cursor = best
        while cursor != start {
            route.append(hexes[cursor])
            cursor = cameFrom[cursor]
        }
        return route.reversed()
    }
}

/// Routes found many at a time on one state, as a keeper's view finds the
/// way of every march they know of: what stands in the way of each House's
/// companies found once, and the search's room kept from one route to the
/// next, not made anew for each. Each route is the one `path(for:to:)`
/// finds, hex for hex.
struct Routes {
    private let state: GameState
    private var inTheWay: [Int: [Bool]] = [:]
    private var search: WaySearch

    init(on state: GameState) {
        self.state = state
        search = WaySearch(count: state.map.count)
    }

    /// What stands in the way of a House's companies: every company, and
    /// what else `path(for:to:)` goes round for them. A company's own hex
    /// is among them, but a search never comes back to where it began.
    private mutating func blocked(for owner: Int) -> [Bool] {
        if let found = inTheWay[owner] { return found }
        let map = state.map
        var blocked = [Bool](repeating: false, count: map.count)
        func mark(_ hex: Hex) {
            if let index = map.index(of: hex) { blocked[index] = true }
        }
        for unit in state.units { mark(unit.position) }
        for hold in state.holds where hold.owner != owner { mark(hold.position) }
        for wild in state.wildsStanding { mark(wild.position) }
        for lair in state.lairsStanding { mark(lair.position) }
        for hall in state.hallsStanding where !state.isOfHall(owner, hall) { mark(hall.position) }
        for storehouse in state.storehousesStanding where !state.isOf(storehouse.alliance, owner) { mark(storehouse.position) }
        inTheWay[owner] = blocked
        return blocked
    }

    /// The route `path(for:to:)` finds for the unit to `target`.
    mutating func path(for unit: Unit, to target: Hex) -> [Hex]? {
        let map = state.map
        guard unit.position != target,
              let start = map.index(of: unit.position),
              let goal = map.index(of: target),
              map[goal].terrain.isPassable
        else { return nil }
        return search.way(on: map, from: start, to: goal, around: blocked(for: unit.owner))
    }
}

/// The search for a way across the map: A* over its tiles, a step costing
/// the move cost of the ground it enters, guided by the distance left. Of
/// tiles equally promising, the lower index is taken first, so a way is
/// always the same way. Its room, each tile's cost and whence it was
/// reached, is kept from one search to the next and set back only where
/// the last one went.
struct WaySearch {
    /// Each tile's cheapest cost found, plus one; 0 for a tile not reached.
    private var best: [Int32]
    private var cameFrom: [Int32]
    /// The tiles the last search reached.
    private var touched: [Int32] = []
    private var open = KeyHeap()

    init(count: Int) {
        best = [Int32](repeating: 0, count: count)
        cameFrom = [Int32](repeating: 0, count: count)
    }

    /// The cheapest way from the tile `start` to the tile `goal`, as the
    /// hexes stepped through after the start, round every tile `blocked`
    /// but the goal; nil when there is none, or none found within 6,000
    /// tiles searched.
    mutating func way(on map: WorldMap, from start: Int, to goal: Int, around blocked: [Bool]) -> [Hex]? {
        let hexes = map.hexes, neighbours = map.neighbours
        // A goal every way into which is shut, or a start every way out of
        // which is, has no way to it: known at once, not after searching
        // all the land that can be reached, as a goal ringed by companies
        // would have it.
        func shut(_ tile: Int, but other: Int) -> Bool {
            for side in 0..<6 {
                let next = Int(neighbours[tile * 6 + side])
                if next >= 0, next == other || (!blocked[next] && map[next].terrain.isPassable) { return false }
            }
            return true
        }
        if shut(goal, but: start) || shut(start, but: goal) { return nil }
        for tile in touched { best[Int(tile)] = 0 }
        touched.removeAll(keepingCapacity: true)
        open.removeAll()
        let target = hexes[goal]
        best[start] = 1
        touched.append(Int32(start))
        open.push(KeyHeap.key(hexes[start].distance(to: target), start))
        var expanded = 0

        while let key = open.pop() {
            let tile = KeyHeap.tile(of: key)
            if tile == goal {
                var route: [Hex] = []
                var cursor = goal
                while cursor != start {
                    route.append(hexes[cursor])
                    cursor = Int(cameFrom[cursor])
                }
                return route.reversed()
            }
            let cost = Int(best[tile]) - 1
            // A stale entry: a cheaper way here was already found.
            guard KeyHeap.priority(of: key) == cost + hexes[tile].distance(to: target) else { continue }
            expanded += 1
            if expanded > 6_000 { return nil }
            for side in 0..<6 {
                let next = Int(neighbours[tile * 6 + side])
                guard next >= 0, next == goal || !blocked[next] else { continue }
                let terrain = map[next].terrain
                guard terrain.isPassable else { continue }
                let total = cost + terrain.moveCost
                let known = Int(best[next])
                if known == 0 || total + 1 < known {
                    if known == 0 { touched.append(Int32(next)) }
                    best[next] = Int32(total + 1)
                    cameFrom[next] = Int32(tile)
                    open.push(KeyHeap.key(total + hexes[next].distance(to: target), next))
                }
            }
        }
        return nil
    }
}

/// A binary heap of a search's open tiles, smallest key first, each key a
/// tile's priority above its index: so of equal priorities the lower index
/// comes first, and no two keys are ever equal.
struct KeyHeap {
    private var keys: [Int] = []

    static func key(_ priority: Int, _ tile: Int) -> Int { priority << 32 | tile }
    static func priority(of key: Int) -> Int { key >> 32 }
    static func tile(of key: Int) -> Int { key & 0xFFFF_FFFF }

    mutating func removeAll() {
        keys.removeAll(keepingCapacity: true)
    }

    mutating func push(_ key: Int) {
        keys.append(key)
        var child = keys.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard key < keys[parent] else { break }
            keys[child] = keys[parent]
            child = parent
        }
        keys[child] = key
    }

    mutating func pop() -> Int? {
        guard let last = keys.popLast() else { return nil }
        guard !keys.isEmpty else { return last }
        let top = keys[0]
        // The last key sinks from the top to where it belongs.
        let count = keys.count
        var hole = 0
        while true {
            var child = hole * 2 + 1
            guard child < count else { break }
            if child + 1 < count, keys[child + 1] < keys[child] { child += 1 }
            guard keys[child] < last else { break }
            keys[hole] = keys[child]
            hole = child
        }
        keys[hole] = last
        return top
    }
}

extension GameState {
    /// Every hex the unit could march to and stop on this watch, with the
    /// moves it would have left there: by the same steps a march takes, so
    /// through no other unit and into no foreign hold or other alliance's
    /// hall or storehouse.
    public func reach(of unit: Unit) -> [Hex: Int] {
        guard unit.movesLeft > 0, let start = map.index(of: unit.position) else { return [:] }
        // What stands in the way: other companies, the wilds and their
        // lairs, others' holds and other alliances' halls and storehouses.
        var occupied = Set<Int>()
        for other in units where other.id != unit.id {
            if let index = map.index(of: other.position) { occupied.insert(index) }
        }
        for wild in wildsStanding {
            if let index = map.index(of: wild.position) { occupied.insert(index) }
        }
        for lair in lairsStanding {
            if let index = map.index(of: lair.position) { occupied.insert(index) }
        }
        for hold in holds where hold.owner != unit.owner {
            if let index = map.index(of: hold.position) { occupied.insert(index) }
        }
        for hall in hallsStanding where !isOfHall(unit.owner, hall) {
            if let index = map.index(of: hall.position) { occupied.insert(index) }
        }
        for storehouse in storehousesStanding where !isOf(storehouse.alliance, unit.owner) {
            if let index = map.index(of: storehouse.position) { occupied.insert(index) }
        }
        let full = movement(of: unit)
        let hexes = map.hexes
        var left = [Int](repeating: -1, count: map.count)
        left[start] = unit.movesLeft
        var frontier = [start]
        var result: [Hex: Int] = [:]
        while !frontier.isEmpty {
            // Most moves left first, so each hex settles at its best.
            frontier.sort { (left[$0], $0) > (left[$1], $1) }
            let tile = frontier.removeFirst()
            let remaining = left[tile]
            guard remaining > 0 else { continue }
            for direction in Hex.directions {
                guard let next = map.index(of: hexes[tile] + direction), !occupied.contains(next) else { continue }
                let terrain = map[next].terrain
                guard terrain.isPassable else { continue }
                // A step costs its terrain's moves; with all its moves a
                // company can always take one step.
                guard remaining >= terrain.moveCost || remaining == full else { continue }
                let after = max(0, remaining - terrain.moveCost)
                if after > left[next] {
                    left[next] = after
                    result[hexes[next]] = after
                    frontier.append(next)
                }
            }
        }
        return result
    }

    /// Hexes the unit could strike this watch.
    public func strikeTargets(of unit: Unit) -> [Hex] {
        unit.position.spiral(unit.kind.range).filter { forecast(unit: unit.id, at: $0) != nil }
    }
}
