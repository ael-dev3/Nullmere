import Foundation

extension GameState {
    /// The cheapest route for a unit from its position to `target`, as the
    /// hexes to step through, not including the start. Hexes holding other
    /// units, and other Houses' holds, are avoided, except the target
    /// itself: a march stops at a foreign hold.
    public func path(for unit: Unit, to target: Hex) -> [Hex]? {
        guard unit.position != target,
              let start = map.index(of: unit.position),
              let goal = map.index(of: target),
              map.steps[goal] != 0
        else { return nil }

        // What stands in the way kept in the room from one search to the
        // next, and brought up to the realm as it stands: in a wide realm
        // the thousands of companies stood where they were for all but a
        // few, and marking every one of them anew for every march was the
        // most of what a search cost.
        var room = SearchRoom.take(count: map.count)
        room.ready(for: unit, toward: goal, in: self)
        let way = if let guide = map.guide(from: start, to: goal) {
            room.search.way(on: map, from: start, to: goal, around: room.blocked, guide: guide)
        } else {
            room.search.way(on: map, from: start, to: goal, around: room.blocked)
        }
        room.settle()
        SearchRoom.give(back: &room)
        return way
    }
}

/// What a search goes round: a company, a hold, a company of the wilds, a
/// lair, a hall or a storehouse, each by its id and where it stands.
protocol InTheWay {
    var id: Int { get }
    var position: Hex { get }
}

extension Unit: InTheWay {}
extension Hold: InTheWay {}
extension Wild: InTheWay {}
extension Lair: InTheWay {}
extension AllianceHall: InTheWay {}
extension Storehouse: InTheWay {}

extension WorldMap {
    /// How far a march goes, as the crow flies, for its way to be guided by
    /// the lie of the land.
    static let guidedFrom = 24

    /// The lie of the land toward a goal, for a march's search to be guided
    /// by: a far march's, in a lake wider than twelve seats' own, where far
    /// marches go round a lake too wide to search all the land before it.
    /// Its ways are as cheap as the plain search's, but where ways are as
    /// cheap as one another it may take another of them; so a lake of
    /// twelve seats goes as it always went. It turns on the map and the
    /// march alone, never on what is kept, so the realm and every keeper's
    /// copy take the same way.
    func guide(from start: Int, to goal: Int) -> [UInt16]? {
        guard radius > RealmState.defaultRadius, hexes[start].distance(to: hexes[goal]) >= WorldMap.guidedFrom else { return nil }
        return lie.toward(goal, on: self)
    }
}

/// Room for a search for a way, kept from one search to the next, as the
/// tens of thousands of tiles of a wide lake are too many to lay out anew
/// for every march: the search's own, and what stands in its way, as it
/// stood at the last search, for the next to change only what has moved.
/// A map's tiles are numbered by its radius alone, so a room serves any
/// map of its size.
struct SearchRoom {
    var search: WaySearch
    /// Each tile something stands in the way on, but those lifted for the
    /// search under way.
    private(set) var blocked: [Bool]
    /// How many things stand in the way on each tile.
    private var standing: [UInt16]
    /// What stood in the way when the room was last brought up to a realm,
    /// kind by kind.
    private var companies: [Mark] = []
    private var holds: [Mark] = []
    private var wilds: [Mark] = []
    private var lairs: [Mark] = []
    private var halls: [Mark] = []
    private var storehouses: [Mark] = []
    private var spare: [Mark] = []
    /// The tiles lifted for the search under way, and its goal.
    private var lifted: [Int] = []
    private var goal = -1

    /// A thing in the way as it was marked: its id, where it stood and that
    /// hex's tile, or -1 off the map.
    struct Mark {
        var id: Int
        var position: Hex
        var tile: Int32
    }

    init(count: Int) {
        search = WaySearch(count: count)
        blocked = [Bool](repeating: false, count: count)
        standing = [UInt16](repeating: 0, count: count)
    }

    /// Readies the room for a company's search toward a goal: brought up to
    /// what stands in the way in the realm, then the company itself, its
    /// House's holds and its alliance's halls and storehouses lifted from
    /// it, and the goal left clear, as a march stops at what it goes for.
    mutating func ready(for unit: Unit, toward goal: Int, in state: GameState) {
        let map = state.map
        SearchRoom.bring(&companies, to: state.units, on: map, standing: &standing, blocked: &blocked, spare: &spare)
        SearchRoom.bring(&holds, to: state.holds, on: map, standing: &standing, blocked: &blocked, spare: &spare)
        SearchRoom.bring(&wilds, to: state.wildsStanding, on: map, standing: &standing, blocked: &blocked, spare: &spare)
        SearchRoom.bring(&lairs, to: state.lairsStanding, on: map, standing: &standing, blocked: &blocked, spare: &spare)
        SearchRoom.bring(&halls, to: state.hallsStanding, on: map, standing: &standing, blocked: &blocked, spare: &spare)
        SearchRoom.bring(&storehouses, to: state.storehousesStanding, on: map, standing: &standing, blocked: &blocked, spare: &spare)
        if let index = state.unitIndex(unit.id) { lift(state.units[index].position, on: map) }
        for index in state.holds.indices where state.holds[index].owner == unit.owner { lift(state.holds[index].position, on: map) }
        // Only its alliance's companies pass through a hall, or a storehouse.
        for hall in state.hallsStanding where state.isOfHall(unit.owner, hall) { lift(hall.position, on: map) }
        for storehouse in state.storehousesStanding where state.isOf(storehouse.alliance, unit.owner) { lift(storehouse.position, on: map) }
        self.goal = goal
        blocked[goal] = false
    }

    /// Puts back what was lifted for the search just made.
    mutating func settle() {
        for tile in lifted {
            standing[tile] += 1
            blocked[tile] = true
        }
        lifted.removeAll(keepingCapacity: true)
        if goal >= 0 { blocked[goal] = standing[goal] > 0 }
        goal = -1
    }

    private mutating func lift(_ hex: Hex, on map: WorldMap) {
        guard let tile = map.index(of: hex) else { return }
        lifted.append(tile)
        standing[tile] -= 1
        if standing[tile] == 0 { blocked[tile] = false }
    }

    /// Brings one kind of what stands in the way up to date, walking what
    /// stands now beside what was marked, both kept in the order they came
    /// in: a thing still where it stood costs a look, one moved is taken off
    /// its old tile and put on its new, one gone taken off, one come put on.
    /// However they came to be ordered, each thing marked is taken off or
    /// kept once and each standing now put on or kept once.
    private static func bring<Thing: InTheWay>(_ marks: inout [Mark], to things: [Thing], on map: WorldMap,
                                               standing: inout [UInt16], blocked: inout [Bool], spare: inout [Mark]) {
        func tile(_ hex: Hex) -> Int32 { map.index(of: hex).map { Int32($0) } ?? -1 }
        func put(_ tile: Int32) {
            guard tile >= 0 else { return }
            standing[Int(tile)] += 1
            blocked[Int(tile)] = true
        }
        func take(_ tile: Int32) {
            guard tile >= 0 else { return }
            standing[Int(tile)] -= 1
            if standing[Int(tile)] == 0 { blocked[Int(tile)] = false }
        }
        // As a rule the same things, a few moved: looked over in place.
        if marks.count == things.count {
            var index = 0
            while index < things.count, marks[index].id == things[index].id {
                let position = things[index].position
                if marks[index].position != position {
                    take(marks[index].tile)
                    marks[index] = Mark(id: marks[index].id, position: position, tile: tile(position))
                    put(marks[index].tile)
                }
                index += 1
            }
            if index == things.count { return }
        }
        spare.removeAll(keepingCapacity: true)
        var old = 0
        for index in things.indices {
            let id = things[index].id, position = things[index].position
            while old < marks.count, marks[old].id < id {
                take(marks[old].tile)
                old += 1
            }
            if old < marks.count, marks[old].id == id {
                var mark = marks[old]
                old += 1
                if mark.position != position {
                    take(mark.tile)
                    mark = Mark(id: id, position: position, tile: tile(position))
                    put(mark.tile)
                }
                spare.append(mark)
            } else {
                let mark = Mark(id: id, position: position, tile: tile(position))
                put(mark.tile)
                spare.append(mark)
            }
        }
        while old < marks.count {
            take(marks[old].tile)
            old += 1
        }
        swap(&marks, &spare)
    }

    private static let shelf = Shelf()

    /// A room for a map of so many tiles.
    static func take(count: Int) -> SearchRoom {
        shelf.take(count: count)
    }

    /// A room done with, put back for the next search.
    static func give(back room: inout SearchRoom) {
        shelf.put(room)
    }

    /// The rooms not in use, for any search on any thread to take.
    private final class Shelf: @unchecked Sendable {
        private let lock = NSLock()
        private var rooms: [SearchRoom] = []

        func take(count: Int) -> SearchRoom {
            lock.lock()
            defer { lock.unlock() }
            guard let index = rooms.lastIndex(where: { $0.blocked.count == count }) else { return SearchRoom(count: count) }
            rooms.swapAt(index, rooms.count - 1)
            return rooms.removeLast()
        }

        func put(_ room: SearchRoom) {
            lock.lock()
            defer { lock.unlock() }
            if rooms.count < 8 { rooms.append(room) }
        }
    }
}

extension GameState {
    /// A way toward a hex that can't be reached: to the hex nearest it that
    /// can, keeping clear of other companies and of other Houses' holds.
    /// Nil when the unit already stands as near as it can come.
    public func approach(for unit: Unit, toward target: Hex) -> [Hex]? {
        guard let start = map.index(of: unit.position) else { return nil }
        var blocked = [Bool](repeating: false, count: map.count)
        for index in units.indices where units[index].id != unit.id {
            if let tile = map.index(of: units[index].position) { blocked[tile] = true }
        }
        for index in holds.indices where holds[index].owner != unit.owner {
            if let tile = map.index(of: holds[index].position) { blocked[tile] = true }
        }
        for wild in wildsStanding {
            if let index = map.index(of: wild.position) { blocked[index] = true }
        }
        for lair in lairsStanding {
            if let index = map.index(of: lair.position) { blocked[index] = true }
        }
        let hexes = map.hexes, neighbours = map.neighbours, steps = map.steps
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
            for side in 0..<6 {
                let next = Int(neighbours[tile * 6 + side])
                guard next >= 0, cameFrom[next] == -2, !blocked[next], steps[next] != 0 else { continue }
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
        for index in state.units.indices { mark(state.units[index].position) }
        for index in state.holds.indices where state.holds[index].owner != owner { mark(state.holds[index].position) }
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
              map.steps[goal] != 0
        else { return nil }
        let blocked = blocked(for: unit.owner)
        if let guide = map.guide(from: start, to: goal) {
            return search.way(on: map, from: start, to: goal, around: blocked, guide: guide)
        }
        return search.way(on: map, from: start, to: goal, around: blocked)
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
    /// Each tile's mark from the last look about the goal, and that look's
    /// own: a mark is the look's when it is `stamp`.
    private var marks: [UInt32]
    private var stamp: UInt32 = 0
    private var around: [Int32] = []

    init(count: Int) {
        best = [Int32](repeating: 0, count: count)
        cameFrom = [Int32](repeating: 0, count: count)
        marks = [UInt32](repeating: 0, count: count)
    }

    /// How many tiles the last search reached: for tests.
    var reached: Int { touched.count }

    /// The most tiles looked over about a goal before the search goes on
    /// without knowing whether it is shut in.
    static let pocket = 128

    /// A goal every way into which is shut, or a start every way out of
    /// which is, has no way to it: known at once, not after searching all
    /// the land that can be reached, as a goal ringed by companies would
    /// have it.
    private static func shut(_ tile: Int, but other: Int, neighbours: [Int32], steps: [UInt8], blocked: [Bool]) -> Bool {
        for side in 0..<6 {
            let next = Int(neighbours[tile * 6 + side])
            if next >= 0, next == other || (!blocked[next] && steps[next] != 0) { return false }
        }
        return true
    }

    /// Whether the goal is shut in, with the start outside: the tiles a
    /// way could come to it through, fewer than `pocket` of them, close
    /// round it and never reach the start. A hold ringed two deep by
    /// companies has no way into it, known after a few tiles rather than
    /// after all the land a search could reach; of any other goal, the
    /// search finds what it would have.
    private mutating func pocketed(_ goal: Int, apartFrom start: Int, neighbours: [Int32], steps: [UInt8], blocked: [Bool]) -> Bool {
        stamp &+= 1
        if stamp == 0 {
            marks = [UInt32](repeating: 0, count: marks.count)
            stamp = 1
        }
        around.removeAll(keepingCapacity: true)
        around.append(Int32(goal))
        marks[goal] = stamp
        var head = 0
        while head < around.count {
            guard around.count <= WaySearch.pocket else { return false }
            let tile = Int(around[head])
            head += 1
            for side in 0..<6 {
                let next = Int(neighbours[tile * 6 + side])
                guard next >= 0, marks[next] != stamp else { continue }
                // A way from the start steps onto any tile not blocked, and
                // off the start itself.
                if next == start { return false }
                guard !blocked[next], steps[next] != 0 else { continue }
                marks[next] = stamp
                around.append(Int32(next))
            }
        }
        return true
    }

    /// The cheapest way from the tile `start` to the tile `goal`, as the
    /// hexes stepped through after the start, round every tile `blocked`
    /// but the goal; nil when there is none. However far it is, a way there
    /// is is found: across the widest lake a march may be a hundred and
    /// sixty steps, and the search that finds it once is kept by the march.
    mutating func way(on map: WorldMap, from start: Int, to goal: Int, around blocked: [Bool]) -> [Hex]? {
        let hexes = map.hexes, neighbours = map.neighbours, steps = map.steps
        if WaySearch.shut(goal, but: start, neighbours: neighbours, steps: steps, blocked: blocked)
            || WaySearch.shut(start, but: goal, neighbours: neighbours, steps: steps, blocked: blocked)
            || pocketed(goal, apartFrom: start, neighbours: neighbours, steps: steps, blocked: blocked) { return nil }
        for tile in touched { best[Int(tile)] = 0 }
        touched.removeAll(keepingCapacity: true)
        open.removeAll()
        let target = hexes[goal]
        best[start] = 1
        touched.append(Int32(start))
        open.push(KeyHeap.key(hexes[start].distance(to: target), start))

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
            for side in 0..<6 {
                let next = Int(neighbours[tile * 6 + side])
                guard next >= 0, next == goal || !blocked[next] else { continue }
                let step = Int(steps[next])
                guard step != 0 else { continue }
                let total = cost + step
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

    /// How far from its start a far march goes round what stands in its way
    /// as it sets out: what stands farther along it meets as it comes to
    /// it, and finds its way round then, as any march finds its way anew
    /// when its next step is shut.
    static let seen = 8

    /// A far march's way, guided by the lie of the land toward the goal
    /// rather than by the distance as the crow flies: round what stands in
    /// its way within `seen` tiles of its start, and otherwise the cheapest
    /// the ground gives. Going round every company of a crowded lake as far
    /// as its goal, a search had to look over every tile within what the
    /// crowd added to the way; and the companies of a far march's way will
    /// have moved by the time it comes there. Of tiles equally promising,
    /// the one furthest along is taken first, then the lower index, so it
    /// follows one way rather than every way as cheap. A goal shut in by
    /// companies, beside it or in a pocket about it, has no way, as for any
    /// march.
    mutating func way(on map: WorldMap, from start: Int, to goal: Int, around blocked: [Bool], guide: [UInt16]) -> [Hex]? {
        let hexes = map.hexes, neighbours = map.neighbours, steps = map.steps
        let origin = hexes[start]
        // How dear the goal lies from the start; from a start on ground no
        // way runs over, a company on a ford as it closes, from the land it
        // steps off onto. None at all: no way over the ground.
        var lead = Int(guide[start])
        if guide[start] == LieOfTheLand.unreached {
            lead = Int.max
            for side in 0..<6 {
                let next = Int(neighbours[start * 6 + side])
                guard next >= 0, steps[next] != 0, guide[next] != LieOfTheLand.unreached else { continue }
                lead = min(lead, Int(steps[next]) + Int(guide[next]))
            }
            guard lead != Int.max else { return nil }
        }
        if WaySearch.shut(goal, but: start, neighbours: neighbours, steps: steps, blocked: blocked)
            || WaySearch.shut(start, but: goal, neighbours: neighbours, steps: steps, blocked: blocked)
            || pocketed(goal, apartFrom: start, neighbours: neighbours, steps: steps, blocked: blocked) { return nil }
        for tile in touched { best[Int(tile)] = 0 }
        touched.removeAll(keepingCapacity: true)
        open.removeAll()
        best[start] = 1
        touched.append(Int32(start))
        open.push(WaySearch.guided(lead, 0, start))

        while let key = open.pop() {
            let tile = WaySearch.tile(ofGuided: key)
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
            guard WaySearch.cost(ofGuided: key) == cost else { continue }
            for side in 0..<6 {
                let next = Int(neighbours[tile * 6 + side])
                guard next >= 0, next == goal || !blocked[next] || hexes[next].distance(to: origin) > WaySearch.seen else { continue }
                let step = Int(steps[next]), left = guide[next]
                guard step != 0, left != LieOfTheLand.unreached else { continue }
                let total = cost + step
                let known = Int(best[next])
                if known == 0 || total + 1 < known {
                    if known == 0 { touched.append(Int32(next)) }
                    best[next] = Int32(total + 1)
                    cameFrom[next] = Int32(tile)
                    open.push(WaySearch.guided(total + Int(left), total, next))
                }
            }
        }
        return nil
    }

    /// A guided search's key: its priority, then the furthest along, then
    /// the lower tile, smallest first.
    static func guided(_ priority: Int, _ cost: Int, _ tile: Int) -> Int {
        priority << 42 | (0x3FFFFF - cost) << 20 | tile
    }
    static func cost(ofGuided key: Int) -> Int { 0x3FFFFF - (key >> 20 & 0x3FFFFF) }
    static func tile(ofGuided key: Int) -> Int { key & 0xFFFFF }
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
