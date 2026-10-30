/// A House's heritage: the people of the lake it comes of, each with two
/// strengths of its own and a company of its own at the fifth tier. As an
/// age begins the realm deals every seat one, evenly round the lake; a
/// keeper may take up another, the first time freely and after that for
/// moonsalt.
public enum Heritage: String, CaseIterable, Codable, Sendable {
    /// Of the salt flats: moonsalt, and wards that mend.
    case saltborn
    /// Of the reeds and the shallows: bows, and far sight.
    case fenfolk
    /// Of the old woods: timber, and riders.
    case blackwood
    /// Of the spine's quarries: stone, and spears that hold.
    case spinewardens
    /// Of the barrows: commanders, and studies.
    case moundClans
    /// Of the strand: grain, and gathering.
    case strandfolk

    /// Its people, as a line names them: "the Saltborn".
    public var title: String {
        switch self {
        case .saltborn: return "the Saltborn"
        case .fenfolk: return "the Fenfolk"
        case .blackwood: return "the Blackwood Kin"
        case .spinewardens: return "the Spinewardens"
        case .moundClans: return "the Mound Clans"
        case .strandfolk: return "the Strandfolk"
        }
    }

    /// Its people as a heading names them: "The Saltborn".
    public var name: String { title.prefix(1).uppercased() + title.dropFirst() }

    /// Who its people are, in a line.
    public var origin: String {
        switch self {
        case .saltborn: return "Salt-rakers of the white flats, who read the moon in the brine"
        case .fenfolk: return "Reed-cutters of the shallows, who see far over still water"
        case .blackwood: return "Woodwards of the old trees, who ride the dark paths"
        case .spinewardens: return "Quarriers of the spine, who hold a line like its rock"
        case .moundClans: return "Keepers of the barrows, who forget no lesson of the dead"
        case .strandfolk: return "Fisher-farmers of the strand, who bring in every harvest"
        }
    }

    /// What it adds to a figure of its House's.
    func bonus(_ bonus: Bonus) -> Int {
        switch (self, bonus) {
        case (.saltborn, .yield(.moonsalt)): return 50
        case (.saltborn, .wardMending): return 50
        case (.fenfolk, .attack(.bow)): return 10
        case (.fenfolk, .sight): return 1
        case (.blackwood, .yield(.timber)): return 25
        case (.blackwood, .attack(.rider)): return 10
        case (.spinewardens, .yield(.stone)): return 25
        case (.spinewardens, .defense(.spear)): return 10
        case (.moundClans, .commanderExperience): return 25
        case (.moundClans, .studySpeed): return 10
        case (.strandfolk, .yield(.grain)): return 25
        case (.strandfolk, .gathering): return 20
        default: return 0
        }
    }

    /// Its two strengths, in words.
    public var strengths: [String] {
        switch self {
        case .saltborn: return ["half again the moonsalt from its holds", "its wards mend half again as fast"]
        case .fenfolk: return ["its Bows strike a tenth harder", "its companies see a tile further"]
        case .blackwood: return ["a quarter more timber from its holds", "its Riders strike a tenth harder"]
        case .spinewardens: return ["a quarter more stone from its holds", "its Spears stand a tenth firmer"]
        case .moundClans: return ["its commanders learn a quarter faster", "its studies are done a tenth sooner"]
        case .strandfolk: return ["a quarter more grain from its holds", "a fifth more gathered at the land's sites"]
        }
    }

    /// The kind of its own company, at the fifth tier.
    public var signature: UnitKind {
        switch self {
        case .saltborn, .spinewardens: return .spear
        case .fenfolk, .strandfolk: return .bow
        case .blackwood, .moundClans: return .rider
        }
    }

    /// Its own company's name.
    public var signatureTitle: String {
        switch self {
        case .saltborn: return "Salt Wardens"
        case .fenfolk: return "Reed Bows"
        case .blackwood: return "Wood Riders"
        case .spinewardens: return "Spine Guard"
        case .moundClans: return "Barrow Riders"
        case .strandfolk: return "Strand Bows"
        }
    }

    /// What its own company strikes and stands beyond others of its kind
    /// and tier, in percent.
    public static let signatureEdge = 5
    /// What taking up another heritage costs, once one has been taken up.
    public static let changeCost = Stock(moonsalt: 30)

    /// Every heritage, in the turn they are dealt round the lake: made once,
    /// for every rule that weighs a company asks after its House's.
    private static let round = allCases

    /// The heritage the realm deals a seat as an age begins: round the lake
    /// in turn, from one the seed chooses, so every heritage has its seats.
    static func dealt(seat: Int, seed: UInt64) -> Heritage {
        dealt(seat: seat, from: start(seed: seed))
    }

    /// The heritage dealt a seat, the round begun at `start`.
    static func dealt(seat: Int, from start: Int) -> Heritage {
        round[(start + seat) % round.count]
    }

    /// Where in the round a world's seed has the dealing begin.
    static func start(seed: UInt64) -> Int {
        Int(Seed.finalize(seed ^ 0x4E7A_5EED_D1A1_0000) % UInt64(round.count))
    }
}

extension GameState {
    /// A House's heritage: the one it took up, or the one the realm dealt it.
    public func heritage(of house: Int) -> Heritage {
        guard houses.indices.contains(house), let taken = houses[house].heritage else {
            return Heritage.dealt(seat: house, from: dealing?.firstHeritage ?? Heritage.start(seed: settings.seed))
        }
        return taken
    }

    /// Whether a company is its House's own: the fifth tier of its
    /// heritage's kind.
    public func isSignature(_ unit: Unit) -> Bool {
        unit.tier == Unit.highestTier && unit.kind == heritage(of: unit.owner).signature
    }

    /// A company's name: its House's own company's, or its kind's.
    public func title(of unit: Unit) -> String {
        isSignature(unit) ? heritage(of: unit.owner).signatureTitle : unit.kind.title
    }

    /// Why a House can't take up a heritage, if it can't.
    func heritageRefusal(_ heritage: Heritage, for house: Int) -> RuleError? {
        guard heritage != self.heritage(of: house) else { return .alreadyOfHeritage }
        guard houses[house].heritage != nil else { return nil }
        let stock = houses[house].stock
        return stock.covers(Heritage.changeCost) ? nil : .shortOf(stock.shortfall(for: Heritage.changeCost))
    }

    /// A House takes up a heritage: the first time freely, after that for
    /// moonsalt.
    mutating func takeUp(_ heritage: Heritage, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = heritageRefusal(heritage, for: house) { throw refusal }
        if houses[house].heritage != nil { houses[house].stock.debit(Heritage.changeCost) }
        houses[house].heritage = heritage
        record(.seating, [house], "\(houses[house].title) takes up the ways of \(heritage.title).")
        return [.heritageTaken(house: house, heritage: heritage)]
    }
}

/// Where a realm's rounds begin, as its seed sets them: the heritage dealt
/// the first seat, and the kind of happening that opens the age.
struct Dealing: Codable, Equatable, Sendable {
    var firstHeritage: Int
    var firstHappening: Int

    init(seed: UInt64) {
        firstHeritage = Heritage.start(seed: seed)
        firstHappening = Happening.start(seed: seed)
    }
}
