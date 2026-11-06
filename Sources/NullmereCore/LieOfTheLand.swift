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

/// What the holds claim of a map's land: each tile's hold, kept for the
/// holds that last asked, by what decides it (each hold's id, where it
/// stands, when it was founded and how far it reaches), and given again
/// only to holds the same in all of it, in the same order.
final class Claims: @unchecked Sendable {
    struct Claimant: Equatable {
        let id: Int
        let position: Hex
        let founded: Int
        let reach: Int
    }

    private let lock = NSLock()
    private var kept: (token: UInt64, claimants: [Claimant], owners: [Int?])?

    /// What holds of this token claim, if they were the last to ask: told
    /// by the token alone (`Holdings.claims`), not hold by hold.
    func owners(forToken token: UInt64) -> [Int?]? {
        lock.lock()
        defer { lock.unlock() }
        guard let kept, kept.token == token else { return nil }
        return kept.owners
    }

    /// What these holds claim, if holds the same in all that decides it
    /// were the last to ask: kept from now under their token.
    func owners(for claimants: [Claimant], token: UInt64) -> [Int?]? {
        lock.lock()
        defer { lock.unlock() }
        guard let found = kept, found.claimants == claimants else { return nil }
        kept = (token, found.claimants, found.owners)
        return found.owners
    }

    func keep(_ owners: [Int?], for claimants: [Claimant], token: UInt64) {
        lock.lock()
        defer { lock.unlock() }
        kept = (token, claimants, owners)
    }

    /// Lets go of what was kept, as the ground has changed.
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        kept = nil
    }
}

/// The nearest hex of a terrain to the hexes it was sought from: kept with
/// the map while its ground stays as it is, the oldest let go of first.
final class Nearest: @unchecked Sendable {
    struct Key: Hashable {
        let terrain: Terrain
        let from: Hex
    }

    private let lock = NSLock()
    private var kept: [Key: Hex?] = [:]
    /// How many are kept before all are let go.
    static let most = 256

    /// What was found, if it was sought before: a hex, or none at all.
    func hex(of terrain: Terrain, near hex: Hex) -> Hex?? {
        lock.lock()
        defer { lock.unlock() }
        return kept[Key(terrain: terrain, from: hex)]
    }

    func keep(_ found: Hex?, of terrain: Terrain, near hex: Hex) {
        lock.lock()
        defer { lock.unlock() }
        if kept.count >= Nearest.most { kept.removeAll() }
        kept[Key(terrain: terrain, from: hex)] = .some(found)
    }

    /// Lets go of what was kept, as the ground has changed.
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        kept.removeAll()
    }
}

/// The open water farthest from any shore, kept with the map while its
/// ground stays as it is: sought through every tile of the lake the first
/// time it is asked, given again every time after. A wide lake's every
/// steward asks it at every pace of the full moon's walks on the mirror.
final class Deepest: @unchecked Sendable {
    private let lock = NSLock()
    /// Unasked, or what was found: the deepest water, or none at all.
    private var kept: DeepWater??

    var water: DeepWater?? {
        lock.lock()
        defer { lock.unlock() }
        return kept
    }

    func keep(_ found: DeepWater?) {
        lock.lock()
        defer { lock.unlock() }
        kept = .some(found)
    }

    /// Lets go of what was kept, as the ground has changed.
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        kept = nil
    }
}
