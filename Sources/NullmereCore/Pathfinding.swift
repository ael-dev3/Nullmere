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

        struct Node: Comparable {
            let priority: Int
            let tile: Int
            static func < (a: Node, b: Node) -> Bool {
                (a.priority, a.tile) < (b.priority, b.tile)
            }
        }

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
        var best = [Int](repeating: Int.max, count: count)
        var cameFrom = [Int](repeating: -1, count: count)
        let hexes = map.hexes
        best[start] = 0
        var open = MinHeap<Node>()
        open.push(Node(priority: unit.position.distance(to: target), tile: start))
        var expanded = 0

        while let node = open.pop() {
            if node.tile == goal {
                var route: [Hex] = []
                var cursor = goal
                while cursor != start {
                    route.append(hexes[cursor])
                    cursor = cameFrom[cursor]
                }
                return route.reversed()
            }
            let hex = hexes[node.tile]
            let cost = best[node.tile]
            // A stale entry: a cheaper way here was already found.
            guard node.priority == cost + hex.distance(to: target) else { continue }
            expanded += 1
            if expanded > 6_000 { return nil }
            for direction in Hex.directions {
                guard let next = map.index(of: hex + direction), !blocked[next] else { continue }
                let terrain = map[next].terrain
                guard terrain.isPassable else { continue }
                let total = cost + terrain.moveCost
                if total < best[next] {
                    best[next] = total
                    cameFrom[next] = node.tile
                    open.push(Node(priority: total + hexes[next].distance(to: target), tile: next))
                }
            }
        }
        return nil
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

/// A binary heap, smallest first.
struct MinHeap<Element: Comparable> {
    private var items: [Element] = []

    mutating func push(_ element: Element) {
        items.append(element)
        var child = items.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard items[child] < items[parent] else { break }
            items.swapAt(child, parent)
            child = parent
        }
    }

    mutating func pop() -> Element? {
        guard !items.isEmpty else { return nil }
        items.swapAt(0, items.count - 1)
        let top = items.removeLast()
        var parent = 0
        while true {
            let left = parent * 2 + 1
            let right = left + 1
            var smallest = parent
            if left < items.count, items[left] < items[smallest] { smallest = left }
            if right < items.count, items[right] < items[smallest] { smallest = right }
            if smallest == parent { break }
            items.swapAt(parent, smallest)
            parent = smallest
        }
        return top
    }
}

extension GameState {
    /// Every hex the unit could march to and stop on this watch, with the
    /// moves it would have left there: by the same steps a march takes, so
    /// through no other unit and into no foreign hold.
    public func reach(of unit: Unit) -> [Hex: Int] {
        guard unit.movesLeft > 0, let start = map.index(of: unit.position) else { return [:] }
        var occupied = Set<Int>()
        for other in units where other.id != unit.id {
            if let index = map.index(of: other.position) { occupied.insert(index) }
        }
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
                if let hold = hold(at: hexes[next]), hold.owner != unit.owner { continue }
                // A step costs its terrain's moves; with all its moves a
                // company can always take one step.
                guard remaining >= terrain.moveCost || remaining == movement(of: unit) else { continue }
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
