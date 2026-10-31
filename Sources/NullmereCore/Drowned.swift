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
        guard !laid.isEmpty else { return }
        drowned = laid
        let named = laid.prefix(2).map(\.name).joined(separator: " and ")
        record(.beginning, [], "The water has risen over the \(ordinal(age - 1)) age: \(laid.count) of its holds lie drowned about the lake, "
            + "\(named) among them.")
    }

    /// What a drowned hold of an age before gives up besides a ruin's own:
    /// ten of each store for each level of its works, two hundred at most,
    /// and moonsalt besides, the more for each stage of its Moonspire.
    static func spoils(of hold: DrownedHold) -> Stock {
        let each = min(hold.works * 10, 200)
        return Stock(grain: each, timber: each, stone: each, moonsalt: min(hold.works * 2, 60) + 20 * hold.spire)
    }
}
