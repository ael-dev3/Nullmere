extension GameState {
    /// The cheapest route for a unit from its position to `target`, as the
    /// hexes to step through, not including the start. Hexes holding other
    /// units are avoided, except the target itself.
    public func path(for unit: Unit, to target: Hex) -> [Hex]? {
        guard unit.position != target, map.contains(target) else { return nil }
        guard let targetTile = map[target], targetTile.terrain.isPassable else { return nil }

        struct Node: Comparable {
            let cost: Int
            let estimate: Int
            let hex: Hex
            static func < (a: Node, b: Node) -> Bool {
                (a.cost + a.estimate, a.hex) < (b.cost + b.estimate, b.hex)
            }
        }

        var best: [Hex: Int] = [unit.position: 0]
        var cameFrom: [Hex: Hex] = [:]
        var open = MinHeap<Node>()
        open.push(Node(cost: 0, estimate: unit.position.distance(to: target), hex: unit.position))
        var expanded = 0

        while let node = open.pop() {
            if node.hex == target {
                var route: [Hex] = []
                var cursor = target
                while cursor != unit.position {
                    route.append(cursor)
                    cursor = cameFrom[cursor]!
                }
                return route.reversed()
            }
            guard node.cost == best[node.hex] else { continue }
            expanded += 1
            if expanded > 6_000 { return nil }
            for next in map.neighbors(of: node.hex) {
                guard let tile = map[next], tile.terrain.isPassable else { continue }
                // Other units block the way, though the target itself may be held.
                if next != target, let other = self.unit(at: next), other.id != unit.id { continue }
                let cost = node.cost + tile.terrain.moveCost
                if cost < best[next] ?? Int.max {
                    best[next] = cost
                    cameFrom[next] = node.hex
                    open.push(Node(cost: cost, estimate: next.distance(to: target), hex: next))
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
