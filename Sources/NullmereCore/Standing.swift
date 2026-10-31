/// How near a House stands to winning the lake, by either road.
public struct Standing: Equatable, Sendable {
    public let house: Int
    /// Holds it rules, its vassals' counted.
    public let realm: Int
    /// Holds a realm needs for dominion, as the lake stands now.
    public let needed: Int
    /// Completed stages of its Moonspire.
    public let spire: Int
    /// A vassal can't win while it serves.
    public let isVassal: Bool

    /// How far along the road to dominion, out of a hundred.
    public var dominionPercent: Int { min(100, realm * 100 / max(needed, 1)) }
    /// How far along the road to ascendancy, out of a hundred.
    public var spirePercent: Int { spire * 100 / BuildingKind.moonspire.maxLevel }

    /// The road it is nearest the end of, when that end is close: two
    /// holds short of dominion, or a Moonspire at its fourth stage.
    public var threat: Outcome.Kind? {
        guard !isVassal else { return nil }
        if spire >= BuildingKind.moonspire.maxLevel - 1 { return .ascendancy }
        if realm >= needed - 2 { return .dominion }
        return nil
    }
}

/// The lake as it stood at the start of a watch, for the story of a game.
public struct Snapshot: Codable, Equatable, Sendable {
    public let watch: Int
    /// Holds each House held, by House id.
    public let holds: [Int]
    /// Each House's strength, by House id.
    public let strength: [Int]

    public init(watch: Int, holds: [Int], strength: [Int]) {
        self.watch = watch
        self.holds = holds
        self.strength = strength
    }
}

extension GameState {
    /// Holds a realm needs for dominion with the lake as it is.
    public var dominionNeed: Int {
        max(GameState.supremacyMinimum, (holds.count * GameState.supremacyShare + 99) / 100)
    }

    public func standing(of house: Int) -> Standing {
        Standing(house: house, realm: realm(of: house), needed: dominionNeed,
                 spire: holds(of: house).map { $0.level(.moonspire) }.max() ?? 0,
                 isVassal: houses[house].liege != nil)
    }

    /// Every living House's standing, nearest to winning first.
    public func standings() -> [Standing] {
        livingHouses.map { standing(of: $0.id) }.sorted {
            (max($0.dominionPercent, $0.spirePercent), -$0.house) > (max($1.dominionPercent, $1.spirePercent), -$1.house)
        }
    }

    /// The watches so far, one snapshot each.
    public var history: [Snapshot] { recorded ?? [] }

    mutating func takeSnapshot() {
        let snapshot = Snapshot(watch: watch, holds: houses.map { holds(of: $0.id).count },
                                strength: zip(houses, strengths()).map { $0.isEliminated ? 0 : $1 })
        if recorded == nil { recorded = [] }
        recorded?.removeAll { $0.watch == watch }
        recorded?.append(snapshot)
    }
}
