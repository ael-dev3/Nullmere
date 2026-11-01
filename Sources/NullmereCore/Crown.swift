/// The Crown of the Marches: on the Frontier's lake, a ring of the Spine
/// about the land between its four meres, a gate through it between each
/// two, and the Heartstone in its heart. The wilds hold the gates from the
/// season's first watch, so the Marches open zone by zone: the shores
/// first, the heart once a gate is broken. Unlike a lair, a gate stands
/// against any company alone, or a rally's host, and, struck, it stays
/// struck, never mending as a lair does; broken, it lies open to all for
/// the season, and counts for the kingdom of the House that broke it. The Heartstone is a holy site like any other, held by a company of
/// war standing on it as the watch turns: each watch it is held, its
/// holder's kingdom scores. Rise of Kingdoms' Lost Kingdom opens by its
/// passes about the Ziggurat; the Marches by the Crown's gates about the
/// Heartstone. Only the Marches have a Crown, so every other lake's world
/// goes as it always did.
extension GameState {
    /// The Crown's gates still standing.
    public var gatesStanding: [Lair] { lairsStanding.filter { $0.gate != nil } }

    /// The Heartstone, where the world has one.
    public var heartstone: Shrine? { holySites.first { $0.kind == .heartstone } }

    /// The Crown's gates, held by the wilds from the first and numbered
    /// after the world's other ids; and every House knows the Crown from
    /// afar, its ring, its gates and the Heartstone in its heart.
    mutating func raiseTheCrown(gates: [Hex]) {
        guard !gates.isEmpty else { return }
        var raised: [Lair] = []
        for (index, hex) in gates.enumerated() {
            raised.append(Lair(id: takeID(), kind: .spineHunters, level: Lair.gateLevel, position: hex, raised: watch, gate: index))
        }
        lairs = (lairs ?? []) + raised
        let crown = WorldGenerator.crown(radius: settings.radius)
        let known = map.hexes.compactMap { hex in hex.length == crown || hex == .origin ? map.index(of: hex) : nil }
        for house in houses.indices {
            for index in known where houses[house].explored.indices.contains(index) { houses[house].explored[index] = true }
        }
    }

    /// A company strikes a gate of the Crown, from beside it or with arrows
    /// from its reach: its blow against the gate's defence, and the gate's
    /// blow back on a company beside it. Broken, the gate is gone and the
    /// way through it open; what falls with it is the striker's House's,
    /// gear among its stones and items for its satchel.
    mutating func strike(gate target: Lair, with unitID: Int) -> [GameEvent] {
        guard let index = unitIndex(unitID), let at = lairs?.firstIndex(where: { $0.id == target.id }) else { return [] }
        var random = random()
        let unit = units[index]
        units[index].movesLeft = 0
        units[index].acted = true
        units[index].fortified = false
        units[index].destination = nil
        units[index].errand = nil
        var events: [GameEvent] = []
        let before = lairs![at].strength
        let dealt = min(before, blow(of: unit, on: target) * random.int(in: 85...115) / 100)
        lairs![at].strength -= dealt
        let taken = unit.position.distance(to: target.position) > 1 ? 0 : bodily(target.blowBack, on: unit)
        var fell = false
        if taken > 0 { fell = applyDamage(taken, to: unitID, events: &events) }
        if !fell {
            events += gainExperience(unitID)
            events += teach(unit, target.blowLessons)
        }
        let broken = lairs![at].strength == 0
        let strength = broken ? 0 : lairs![at].strength
        var spoils = Stock.zero
        if broken {
            lairs!.remove(at: at)
            spoils = target.spoils
            store(spoils, for: unit.owner)
            if !fell, let standing = self.unit(unitID) { events += teach(standing, target.breakLessons) }
            events += awardGear(from: target.kind, level: target.level * 2, to: unit.owner)
            record(.hunt, [unit.owner], "\(houses[unit.owner].title) breaks \(target.named): the way to the Heartstone lies open there.")
        }
        let strike = LairAssault.Strike(unit: unitID, owner: unit.owner, kind: unit.kind, from: unit.position, dealt: dealt, taken: taken, fell: fell)
        let assault = LairAssault(rally: 0, caller: unit.owner, lair: target.id, kind: target.kind, level: target.level, at: target.position,
                                  strikes: [strike], before: before, strength: strength, might: target.might,
                                  shares: [LairAssault.Share(house: unit.owner, spoils: spoils)], gate: target.gate)
        events.insert(.lairAssaulted(assault), at: 0)
        if broken { events += rewardLair(assault) }
        return events
    }
}

extension FrontierState {
    /// What a gate of the Crown broken counts for its breaker's kingdom.
    public static let gatePoints = 20
    /// What the Heartstone counts each watch for its holder's kingdom.
    public static let heartPoints = 10
}

extension RealmState {
    /// As the watch turns at the Frontier, the kingdom of the House that
    /// holds the Heartstone scores for it.
    mutating func scoreTheHeart() {
        guard var frontier, let holder = world.heartstone?.holder, frontier.kingdom(of: holder) != nil,
              frontier.points.indices.contains(holder) else { return }
        frontier.points[holder] += FrontierState.heartPoints
        self.frontier = frontier
    }
}
