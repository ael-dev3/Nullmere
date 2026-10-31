/// The ground of the basin around the Nullmere, from the dead water outward
/// to the mountains that wall it in.
public enum Terrain: String, CaseIterable, Codable, Sendable {
    /// The open lake: black, deep and perfectly still. Nothing crosses it.
    case still
    /// Dead shallows near the shore. Wadeable, slowly; nothing grows or lives here.
    case shallows
    /// Pale shingle at the water's edge.
    case strand
    /// White crust where moonsalt forms.
    case saltFlat
    /// Grey grassland, the basin's farmland.
    case greyfield
    /// Dark old forest.
    case blackwood
    /// Low hills full of old graves and good stone.
    case barrow
    /// The mountains that ring the basin. Impassable.
    case spine
    /// The Moonford: the lake's bed laid bare along the moon's road while
    /// the moon is full, shingle under a skin of water from shore to shore.
    /// Walked a step a move; nothing is raised on it, for the water comes
    /// back over it as the moon wanes.
    case ford

    public var title: String {
        switch self {
        case .still: return "The Still"
        case .shallows: return "Dead Shallows"
        case .strand: return "Strand"
        case .saltFlat: return "Salt Flat"
        case .greyfield: return "Greyfield"
        case .blackwood: return "Blackwood"
        case .barrow: return "Barrows"
        case .spine: return "The Spine"
        case .ford: return "The Moonford"
        }
    }

    // These ask by case, not `==`, which for an enum of strings can come
    // to comparing the strings: the search for ways asks them of every
    // tile it looks at.
    public var isWater: Bool {
        switch self {
        case .still, .shallows, .ford: return true
        case .strand, .saltFlat, .greyfield, .blackwood, .barrow, .spine: return false
        }
    }

    /// Whether units can enter it.
    public var isPassable: Bool {
        switch self {
        case .still, .spine: return false
        case .shallows, .strand, .saltFlat, .greyfield, .blackwood, .barrow, .ford: return true
        }
    }

    /// Whether a hold can be founded on it.
    public var isSettleable: Bool {
        switch self {
        case .strand, .saltFlat, .greyfield, .blackwood, .barrow: return true
        case .still, .shallows, .spine, .ford: return false
        }
    }

    /// Movement points to enter.
    public var moveCost: Int {
        switch self {
        case .strand, .saltFlat, .greyfield, .ford: return 1
        case .shallows, .blackwood, .barrow: return 2
        case .still, .spine: return 99
        }
    }

    /// Bonus to a defender standing here, in percent.
    public var defenseBonus: Int {
        switch self {
        case .blackwood: return 25
        case .barrow: return 50
        case .shallows: return -25
        default: return 0
        }
    }

    /// Extra sight for a unit standing here.
    public var visionBonus: Int {
        if case .barrow = self { return 1 }
        return 0
    }

    /// What one worked tile yields each watch.
    public var yield: Stock {
        switch self {
        case .still, .shallows, .spine, .ford: return .zero
        case .strand: return Stock(grain: 1)
        case .saltFlat: return Stock(moonsalt: 1)
        case .greyfield: return Stock(grain: 2)
        case .blackwood: return Stock(timber: 2)
        case .barrow: return Stock(stone: 2)
        }
    }
}

/// Something notable on a tile.
public enum Feature: String, CaseIterable, Codable, Sendable {
    /// A thick bed of moonsalt.
    case moonsaltBed
    /// Ancient trees, vast and dense.
    case elderGrove
    /// A seam of cut-ready stone.
    case stoneSeam
    /// Black, rich soil.
    case darkLoam
    /// A half-sunken ruin of whoever was here before. The first to reach it
    /// finds what remains.
    case drownedRuin

    public var title: String {
        switch self {
        case .moonsaltBed: return "Moonsalt Bed"
        case .elderGrove: return "Elder Grove"
        case .stoneSeam: return "Stone Seam"
        case .darkLoam: return "Dark Loam"
        case .drownedRuin: return "Drowned Ruin"
        }
    }

    /// Added to the tile's yield when worked.
    public var yield: Stock {
        switch self {
        case .moonsaltBed: return Stock(moonsalt: 2)
        case .elderGrove: return Stock(timber: 4)
        case .stoneSeam: return Stock(stone: 4)
        case .darkLoam: return Stock(grain: 4)
        case .drownedRuin: return .zero
        }
    }
}
