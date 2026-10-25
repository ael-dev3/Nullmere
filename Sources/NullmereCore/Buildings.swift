/// What a hold can build. Each building rises through levels; every level
/// costs more and takes longer, and each completed level adds its effect.
public enum BuildingKind: String, CaseIterable, Codable, Sendable {
    case granary
    case sawpit
    case quarry
    case saltworks
    case musterHall
    case walls
    case beacon
    /// The great work: a white tower of moonsalt and stone. A House that
    /// raises it to its fifth level is ascendant over the whole lake.
    case moonspire

    public var title: String {
        switch self {
        case .granary: return "Granary"
        case .sawpit: return "Sawpit"
        case .quarry: return "Quarry"
        case .saltworks: return "Saltworks"
        case .musterHall: return "Muster Hall"
        case .walls: return "Walls"
        case .beacon: return "Beacon"
        case .moonspire: return "Moonspire"
        }
    }

    public var maxLevel: Int {
        switch self {
        case .beacon: return 3
        case .musterHall: return 3
        default: return 5
        }
    }

    /// Only a House's seat can raise the Moonspire.
    public var requiresSeat: Bool { self == .moonspire }

    /// The resource whose yield this building raises, if any.
    public var boostedResource: Resource? {
        switch self {
        case .granary: return .grain
        case .sawpit: return .timber
        case .quarry: return .stone
        case .saltworks: return .moonsalt
        default: return nil
        }
    }

    /// Percent added to the boosted resource's yield per level.
    public static let yieldBoostPerLevel = 25

    private var baseCost: Stock {
        switch self {
        case .granary: return Stock(grain: 10, timber: 25, stone: 10)
        case .sawpit: return Stock(grain: 20, timber: 10, stone: 15)
        case .quarry: return Stock(grain: 20, timber: 20, stone: 5)
        case .saltworks: return Stock(grain: 25, timber: 25, stone: 25)
        case .musterHall: return Stock(grain: 30, timber: 40, stone: 30)
        case .walls: return Stock(grain: 10, timber: 15, stone: 45)
        case .beacon: return Stock(grain: 10, timber: 30, stone: 20, moonsalt: 5)
        case .moonspire: return Stock(grain: 60, timber: 60, stone: 80, moonsalt: 24)
        }
    }

    /// Cost multipliers for levels one to five.
    private static let costMultipliers = [1, 2, 4, 7, 12]

    /// The cost of raising this building to `level`.
    public func cost(toLevel level: Int) -> Stock {
        precondition((1...maxLevel).contains(level), "level out of range")
        return baseCost * BuildingKind.costMultipliers[level - 1]
    }

    /// Watches it takes to raise this building to `level`.
    public func buildWatches(toLevel level: Int) -> Int {
        precondition((1...maxLevel).contains(level), "level out of range")
        return self == .moonspire ? 2 + level * 2 : 1 + level
    }

    /// One line on what the next level does.
    public func effect(atLevel level: Int) -> String {
        switch self {
        case .granary, .sawpit, .quarry, .saltworks:
            let resource = boostedResource!.title.lowercased()
            return "+\(BuildingKind.yieldBoostPerLevel * level)% \(resource) from this hold's land"
        case .musterHall:
            let unlocked = UnitKind.allCases.filter { $0.requiredMuster == level }.map(\.title)
            return unlocked.isEmpty ? "Trains faster" : "Trains " + unlocked.joined(separator: " and ")
        case .walls:
            return "Ward \(Hold.maximumWard(wallLevel: level)), garrison +\(level * 20)% defence"
        case .beacon:
            return "Sight \(Hold.sight(beaconLevel: level)) and +\(level) territory"
        case .moonspire:
            return level == maxLevel ? "Ascendancy over the Nullmere" : "Spire \(level) of \(maxLevel)"
        }
    }
}
