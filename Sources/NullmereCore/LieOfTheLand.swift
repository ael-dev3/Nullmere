import Foundation

/// The lie of the land toward a goal: how dear every tile of the land is
/// from it by the cheapest way over the ground alone, as if no company or
/// hold stood anywhere. A far march's search is guided by it along the
/// shore it has to follow, where the distance as the crow flies would have
/// it look over all the land before a lake for a way across: in a realm of
/// ninety-six seats a march of a hundred and fifty steps looked over six
/// thousand tiles. Worked out once for each goal far marches seek, and
/// kept with the map while its ground stays as it is.
final class LieOfTheLand: @unchecked Sendable {
    private let lock = NSLock()
    private var fields: [Int: [UInt16]] = [:]
    private var order: [Int] = []

    /// How many goals' lie is kept: the oldest goes first.
    static let kept = 64
    /// What a tile no way over the ground reaches costs.
    static let unreached = UInt16.max

    /// How many goals' lie is kept.
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return fields.count
    }

    /// Lets go of every goal's lie, as the ground has changed.
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        fields.removeAll()
        order.removeAll()
    }

    /// The lie of the land toward a tile: worked out the first time it is
    /// asked for, and kept.
    func toward(_ goal: Int, on map: WorldMap) -> [UInt16] {
        lock.lock()
        if let found = fields[goal] {
            lock.unlock()
            return found
        }
        lock.unlock()
        let made = LieOfTheLand.measure(toward: goal, on: map)
        lock.lock()
        defer { lock.unlock() }
        if fields[goal] == nil {
            fields[goal] = made
            order.append(goal)
            if order.count > LieOfTheLand.kept { fields[order.removeFirst()] = nil }
        }
        return fields[goal] ?? made
    }

    /// Each tile's cheapest cost to the goal over the ground, each step
    /// costing what the ground it enters does, as a march's does: the
    /// cheapest first, in buckets by cost, as the costs are small.
    static func measure(toward goal: Int, on map: WorldMap) -> [UInt16] {
        let neighbours = map.neighbours, steps = map.steps
        var cost = [UInt16](repeating: unreached, count: map.count)
        cost[goal] = 0
        var buckets: [[Int32]] = [[Int32(goal)]]
        var level = 0
        while level < buckets.count {
            var index = 0
            while index < buckets[level].count {
                let tile = Int(buckets[level][index])
                index += 1
                // Settled at a lower cost since it was put here.
                guard Int(cost[tile]) == level else { continue }
                // A way from a neighbour onto this tile costs this tile's step.
                let total = level + Int(steps[tile])
                for side in 0..<6 {
                    let next = Int(neighbours[tile * 6 + side])
                    guard next >= 0, steps[next] != 0, total < Int(cost[next]) else { continue }
                    cost[next] = UInt16(total)
                    while buckets.count <= total { buckets.append([]) }
                    buckets[total].append(Int32(next))
                }
            }
            buckets[level] = []
            level += 1
        }
        return cost
    }
}
