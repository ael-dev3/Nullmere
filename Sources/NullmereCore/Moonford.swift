/// The Moonford: the moon waxes and wanes over thirty watches, and about
/// each full moon from the first Sundering's on, the lake's tide ebbs along
/// the moon's road across the still water, laying bare a ford of shingle
/// from shore to shore, two hexes wide through the deep water, for ten
/// watches: ground a company walks a step a move, where nothing may be
/// raised, lit by the moon for every House to see. The two kingdoms of a
/// Sundering meet on it. As the moon wanes the water comes back over it,
/// and the lake carries whoever still stands on it to the nearest shore,
/// worn by the tide.
extension GameState {
    /// The moon's round, in watches: the full falls on every thirtieth.
    public static let lunarMonth = 30
    /// The watches the ford lies open about each full moon: the five
    /// before the full and the five from it.
    public static let fordLasts = 10
    /// What the tide takes from a company it carries ashore, of its health.
    public static let tideToll = 20

    /// Whether the ford lies open at a watch.
    public static func fordOpen(at watch: Int) -> Bool {
        watch >= Sundering.first && (watch + fordLasts / 2) % lunarMonth < fordLasts
    }

    /// The watches until the ford next lies open; 0 while it does.
    public static func watchesToFord(from watch: Int) -> Int {
        var next = max(watch, 0)
        while !fordOpen(at: next) { next += 1 }
        return next - watch
    }

    /// The watches the ford still lies open, counting this one; 0 while it
    /// is under water.
    public static func fordWatchesLeft(at watch: Int) -> Int {
        var last = watch
        while fordOpen(at: last) { last += 1 }
        return last - watch
    }

    /// The moon's age at a watch, in watches from the full: 0 at the full,
    /// fifteen at the dark of the moon.
    public static func moonAge(at watch: Int) -> Int {
        ((watch % lunarMonth) + lunarMonth) % lunarMonth
    }

    /// Where the ford would lie: the still water of the row of hexes
    /// through the deep water, and of the row beside it, from shore to
    /// shore. None on a lake with no deep water.
    public func fordCourse() -> [Hex] {
        guard let deep = map.deepestWater()?.hex else { return [] }
        var course: [Hex] = []
        for row in [deep.r, deep.r + 1] {
            let heart = Hex(deep.q, row)
            guard map[heart]?.terrain == .still else { continue }
            course.append(heart)
            for step in [-1, 1] {
                var q = deep.q + step
                while let tile = map[Hex(q, row)], case .still = tile.terrain {
                    course.append(Hex(q, row))
                    q += step
                }
            }
        }
        return course.sorted()
    }

    /// The tide as the watch turns: the ford laid bare as the moon comes
    /// to its full, and the water back over it as the moon wanes.
    mutating func turnTide() -> [GameEvent] {
        let open = GameState.fordOpen(at: watch)
        if open, ford == nil {
            let course = fordCourse()
            guard !course.isEmpty else { return [] }
            for hex in course {
                guard let tile = map[hex] else { continue }
                map.set(hex, Tile(terrain: .ford, feature: tile.feature, relief: tile.relief))
            }
            ford = course
            // The moon lights it for every House.
            for house in houses.indices where !houses[house].isEliminated {
                for hex in course {
                    if let index = map.index(of: hex), houses[house].explored.indices.contains(index) {
                        houses[house].explored[index] = true
                    }
                }
            }
            let closes = watch + GameState.fordWatchesLeft(at: watch)
            record(.omen, [], "The moon is full: the tide ebbs along its road, and a ford of shingle lies across \(settings.lake.title) "
                + "from shore to shore until the \(ordinal(closes)) watch.")
            return [.fordOpened(closes: closes)]
        }
        guard !open, let course = ford else { return [] }
        for hex in course {
            guard let tile = map[hex] else { continue }
            map.set(hex, Tile(terrain: .still, feature: tile.feature, relief: tile.relief))
        }
        ford = nil
        // Whoever still stands on it is carried to the nearest shore, the
        // first mustered first, worn by the tide.
        var events: [GameEvent] = []
        let stranded = units.indices.filter { course.contains(units[$0].position) }.sorted { units[$0].id < units[$1].id }
        for index in stranded {
            let unit = units[index]
            guard let shore = nearestShore(to: unit.position, for: unit) else { continue }
            units[index].position = shore
            units[index].health = max(1, unit.health - GameState.tideToll)
            units[index].destination = nil
            units[index].way = nil
            units[index].drillAt = nil
            events.append(.carriedAshore(unit: unit.id, owner: unit.owner, from: unit.position, to: shore))
        }
        record(.omen, [], "The moon wanes and the water comes back over the ford"
            + (events.isEmpty ? "." : "; the lake carries \(events.count) compan\(events.count == 1 ? "y" : "ies") to the shore."))
        return [.fordClosed(carried: events.count)] + events
    }

    /// The nearest land a company may stand on, ring by ring from where
    /// it stands: no other company there, nor the wilds, nor another
    /// House's hold.
    func nearestShore(to hex: Hex, for unit: Unit) -> Hex? {
        for cell in hex.spiral(map.radius) {
            guard let tile = map[cell], tile.terrain.isPassable, !tile.terrain.isWater,
                  self.unit(at: cell) == nil, wild(at: cell) == nil, lair(at: cell) == nil else { continue }
            if let hold = hold(at: cell), hold.owner != unit.owner { continue }
            return cell
        }
        return nil
    }
}
