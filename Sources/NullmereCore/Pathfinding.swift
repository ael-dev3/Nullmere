extension GameState {
    /// The cheapest route for a unit from its position to `target`, as the
    /// hexes to step through, not including the start. Hexes holding other
    /// units are avoided, except the target itself.
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

/// A binary heap, smallest first.
struct MinHeap<Element: Comparable> {
    private var items: [Element] = []

    var isEmpty: Bool { items.isEmpty }

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
