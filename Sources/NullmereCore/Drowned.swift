/// Drowned ages: what an age leaves is the next age's lake. As a new age
/// begins, the holds of the age before lie drowned where they stood, in
/// the shallows or on the land of the new lake: ruins with their names,
/// their Houses and their ages, searched by the first company to reach
/// them for what their works held. Searched or not, the map remembers
/// where each stood, so a realm's history is its map.
public struct DrownedHold: Codable, Equatable, Sendable {
    public let position: Hex
    /// The hold's name, and the title of the House that held it.
    public let name: String
    public let house: String
    /// The age it stood in.
    public let age: Int
    /// The levels of its works, all told, and its Moonspire's stage.
    public let works: Int
    public let spire: Int

    public init(position: Hex, name: String, house: String, age: Int, works: Int, spire: Int) {
        self.position = position
        self.name = name
        self.house = house
        self.age = age
        self.works = works
        self.spire = spire
    }

    /// "Vael, House Aurel's in the 2nd age".
    public var title: String {
        "\(name), \(house)'s in the \(ordinal(age)) age"
    }

    /// What its ground says of it: drowned there and not yet searched, or
    /// searched.
    public func told(searched: Bool) -> String {
        searched ? "Here stood \(name), \(house)'s hold in the \(ordinal(age)) age; its ruin has been searched."
            : "Here lies \(name) drowned, \(house)'s hold in the \(ordinal(age)) age: the first company to reach it searches what its works held."
    }
}

/// The Moonspire the age before raised highest, standing broken in this
/// one where it stood, or near: a holy site its holders take its stones
/// from, every House's to fight for.
public struct BrokenSpire: Codable, Equatable, Sendable {
    public let position: Hex
    /// The House that raised it, its title, and the age it stood in.
    public let house: String
    public let age: Int
    /// The stages it had reached.
    public let stages: Int

    public init(position: Hex, house: String, age: Int, stages: Int) {
        self.position = position
        self.house = house
        self.age = age
        self.stages = stages
    }
}

extension GameState {
    /// The most holds of the age before that lie drowned in a new one.
    public static let drownedAtMost = 12
    /// The nearest a drowned hold lies to a new age's seat.
    public static let drownedFromSeats = 3

    /// The holds of the ages before, where they lie in this one.
    public var drownedHolds: [DrownedHold] { drowned ?? [] }

    /// The drowned hold at a hex, searched or not.
    public func drowned(at hex: Hex) -> DrownedHold? {
        drownedHolds.first { $0.position == hex }
    }

    /// As a new age begins: the holds of the age before, the greatest first,
    /// laid as ruins where they stood, wherever this lake has ground there a
    /// company may reach (the shallows too) clear of the new seats; and the
    /// Chronicle opens with them.
    mutating func drown(_ before: GameState, age: Int) {
        let seats = holds.map(\.position)
        let greatest = before.holds.sorted { a, b in
            let (left, right) = (a.levels.values.reduce(0, +), b.levels.values.reduce(0, +))
            return (a.isSeat ? 1 : 0, left, -a.id) > (b.isSeat ? 1 : 0, right, -b.id)
        }
        var laid: [DrownedHold] = []
        for hold in greatest where laid.count < GameState.drownedAtMost {
            guard let tile = map[hold.position], tile.feature == nil, tile.terrain.isPassable, tile.terrain != .ford,
                  seats.allSatisfy({ $0.distance(to: hold.position) >= GameState.drownedFromSeats }),
                  unit(at: hold.position) == nil else { continue }
            let title = before.houses.indices.contains(hold.owner) ? before.houses[hold.owner].title : "a House now gone"
            map.set(hold.position, Tile(terrain: tile.terrain, feature: .drownedRuin, relief: tile.relief))
            laid.append(DrownedHold(position: hold.position, name: hold.name, house: title, age: age - 1,
                                    works: hold.levels.values.reduce(0, +), spire: hold.level(.moonspire)))
        }
        raiseTheBrokenSpire(of: before, age: age)
        guard !laid.isEmpty else { return }
        drowned = laid
        let named = laid.prefix(2).map(\.name).joined(separator: " and ")
        record(.beginning, [], "The water has risen over the \(ordinal(age - 1)) age: \(laid.count) of its holds lie drowned about the lake, "
            + "\(named) among them.")
    }

    /// The Moonspire the age before raised highest, laid broken where it
    /// stood, or on the nearest land a company may stand on within three
    /// tiles, clear of the new seats and the lake's holy sites; a holy site
    /// itself, among them.
    mutating func raiseTheBrokenSpire(of before: GameState, age: Int) {
        guard let raiser = before.holds.filter({ $0.level(.moonspire) > 0 })
            .max(by: { ($0.level(.moonspire), -$0.id) < ($1.level(.moonspire), -$1.id) }) else { return }
        let seats = holds.map(\.position)
        guard let at = raiser.position.spiral(3).first(where: { hex in
            guard let tile = map[hex], tile.terrain.isPassable, !tile.terrain.isWater, tile.terrain != .ford else { return false }
            return seats.allSatisfy { $0.distance(to: hex) >= GameState.drownedFromSeats } && unit(at: hex) == nil && shrine(at: hex) == nil
        }) else { return }
        let title = before.houses.indices.contains(raiser.owner) ? before.houses[raiser.owner].title : "a House now gone"
        brokenSpire = BrokenSpire(position: at, house: title, age: age - 1, stages: raiser.level(.moonspire))
        // The lake's own raised already, it stands among them; else it is
        // raised with them.
        if let raised = shrines {
            shrines = raised + [Shrine(id: (raised.map(\.id).max() ?? 0) + 1, kind: .brokenSpire, position: at)]
        }
        let stages = raiser.level(.moonspire)
        record(.beginning, [], "The Moonspire \(title) raised in the \(ordinal(age - 1)) age stands broken by the new water, "
            + (stages == 1 ? "a stage" : "\(stages) stages") + " high: whoever holds it takes its stones.")
    }

    /// What a drowned hold of an age before gives up besides a ruin's own:
    /// ten of each store for each level of its works, two hundred at most,
    /// and moonsalt besides, the more for each stage of its Moonspire.
    static func spoils(of hold: DrownedHold) -> Stock {
        let each = min(hold.works * 10, 200)
        return Stock(grain: each, timber: each, stone: each, moonsalt: min(hold.works * 2, 60) + 20 * hold.spire)
    }
}
