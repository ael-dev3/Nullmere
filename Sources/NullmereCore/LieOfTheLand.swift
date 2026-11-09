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

        /// Whether it claims before the hold of `id`, founded in `watch`:
        /// the older first, and of two founded alike the lower id.
        func precedes(_ id: Int, foundedIn watch: Int) -> Bool {
            (founded, self.id) < (watch, id)
        }
    }

    /// Whether a hold may claim a tile of this ground: land, and of the
    /// Spine only the tile it stands on itself.
    static func claimable(_ terrain: Terrain, tile: Int, home: Int?) -> Bool {
        switch terrain {
        case .still, .shallows, .ford, .stream, .shoal: return false
        case .spine: return tile == home
        case .strand, .saltFlat, .greyfield, .blackwood, .barrow: return true
        }
    }

    /// The most holds that may differ from those that last asked for what
    /// they claim to be amended from it, not worked out afresh.
    static let mostAmended = 32

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

    /// What these holds claim, amended from what the holds that last asked
    /// claimed where few of them differ: each tile's hold is the first in
    /// the claiming whose reach takes it in, so only the tiles about a hold
    /// gone, come or changed can change hands. Each tile a hold gone held
    /// goes to the first of the holds now that reaches it, if any; then
    /// each hold come takes every tile it reaches that it claims before the
    /// holder of. The same tile by tile as worked out afresh, and kept from
    /// now under their token. Nil where nothing is kept or too many differ.
    func amend(to claimants: [Claimant], token: UInt64, on map: WorldMap) -> [Int?]? {
        lock.lock()
        defer { lock.unlock() }
        guard let before = kept?.claimants else { return nil }
        // Holds keep their places in the list, a new one founded at its end:
        // what is alike at either end is passed over, what differs lies
        // between, and of that only what is not in both is gone or come.
        let shorter = min(before.count, claimants.count)
        var head = 0
        while head < shorter, before[head] == claimants[head] { head += 1 }
        var tail = 0
        while tail < shorter - head, before[before.count - 1 - tail] == claimants[claimants.count - 1 - tail] { tail += 1 }
        let was = before[head..<(before.count - tail)], now = claimants[head..<(claimants.count - tail)]
        guard was.count + now.count <= Claims.mostAmended else { return nil }
        let gone = was.filter { !now.contains($0) }, come = now.filter { !was.contains($0) }
        // Taken out of what is kept, so that where none else holds it the
        // list is amended where it lies, not copied whole.
        guard var owners = kept?.owners, owners.count == map.count else { return nil }
        kept = nil
        for gone in gone {
            // The holds now that might reach a tile it reached, and the
            // tile each stands on.
            let near = claimants.filter { $0.position.distance(to: gone.position) <= $0.reach + gone.reach }
            let homes = near.map { map.index(of: $0.position) }
            gone.position.forEach(within: gone.reach) { hex in
                guard let tile = map.index(of: hex), owners[tile] == gone.id else { return }
                let terrain = map[tile].terrain
                var first: Claimant?
                for (index, claimant) in near.enumerated()
                where hex.distance(to: claimant.position) <= claimant.reach && Claims.claimable(terrain, tile: tile, home: homes[index]) {
                    if let found = first, !claimant.precedes(found.id, foundedIn: found.founded) { continue }
                    first = claimant
                }
                owners[tile] = first?.id
            }
        }
        for come in come {
            let home = map.index(of: come.position)
            var unknown = false
            map.forEachIndex(within: come.reach, of: come.position) { tile in
                guard Claims.claimable(map[tile].terrain, tile: tile, home: home) else { return }
                if let holder = owners[tile] {
                    guard let founded = Claims.founded(of: holder, in: claimants) else { unknown = true; return }
                    guard come.precedes(holder, foundedIn: founded) else { return }
                }
                owners[tile] = come.id
            }
            // A holder not among the holds now: what was kept was not theirs.
            if unknown { return nil }
        }
        kept = (token, claimants, owners)
        return owners
    }

    /// When the hold of an id among these was founded: found by halving
    /// the list, as holds are founded each with an id above the one before,
    /// or looked for in each should any be out of that order.
    static func founded(of id: Int, in claimants: [Claimant]) -> Int? {
        var low = 0, high = claimants.count
        while low < high {
            let middle = (low + high) / 2
            if claimants[middle].id == id { return claimants[middle].founded }
            if claimants[middle].id < id { low = middle + 1 } else { high = middle }
        }
        return claimants.first { $0.id == id }?.founded
    }

    /// Lets go of what was kept, as the ground has changed.
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        kept = nil
    }
}

/// A map's relief, as one: its copies, and the maps a keeper is shown of it,
/// keep the same one while their relief is its relief.
final class ReliefOf: Sendable {}

/// A map's ground, as one, page by page (`RealmState.mapPage` tiles a
/// page, as its pages go): its copies, and the maps a keeper is shown of
/// it, keep the same one, each setting apart the pages it writes tiles of
/// its own to.
final class GroundOf: Sendable {}

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
