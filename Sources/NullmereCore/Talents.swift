/// A tree of a commander's talents: what it grows into as it rises.
public enum TalentTree: String, CaseIterable, Codable, Sendable {
    /// The blow: attack, the hunt, the ram.
    case steel
    /// The guard: defence, healing, the walls.
    case ward
    /// The way: sight, the march, the sites of the land.
    case road

    public var title: String {
        switch self {
        case .steel: return "Steel"
        case .ward: return "Ward"
        case .road: return "Road"
        }
    }

    /// Its five talents, each opened by the one before it.
    public var talents: [Talent] { Talent.allCases.filter { $0.tree == self } }
}

/// A commander's talent: learned a rank at a time, a point a rank, each
/// rank giving its edge again to the company it leads.
public enum Talent: String, CaseIterable, Codable, Sendable {
    // Steel
    case keenEdge, huntersMark, rammingDrill, bloodedSteel, battleRage
    // Ward
    case thickHide, fieldSurgeon, gatewarden, ironRanks, unbroken
    // Road
    case keenEyes, gleanersHand, deepSaddlebags, longStride, pathfinder

    public var tree: TalentTree {
        switch self {
        case .keenEdge, .huntersMark, .rammingDrill, .bloodedSteel, .battleRage: return .steel
        case .thickHide, .fieldSurgeon, .gatewarden, .ironRanks, .unbroken: return .ward
        case .keenEyes, .gleanersHand, .deepSaddlebags, .longStride, .pathfinder: return .road
        }
    }

    public var title: String {
        switch self {
        case .keenEdge: return "Keen Edge"
        case .huntersMark: return "Hunter's Mark"
        case .rammingDrill: return "Ramming Drill"
        case .bloodedSteel: return "Blooded Steel"
        case .battleRage: return "Battle Rage"
        case .thickHide: return "Thick Hide"
        case .fieldSurgeon: return "Field Surgeon"
        case .gatewarden: return "Gatewarden"
        case .ironRanks: return "Iron Ranks"
        case .unbroken: return "Unbroken"
        case .keenEyes: return "Keen Eyes"
        case .gleanersHand: return "Gleaner's Hand"
        case .deepSaddlebags: return "Deep Saddlebags"
        case .longStride: return "Long Stride"
        case .pathfinder: return "Pathfinder"
        }
    }

    /// Its place in its tree, from the first.
    public var place: Int { tree.talents.firstIndex(of: self) ?? 0 }

    /// The talent before it in its tree, which must be learned first.
    public var opener: Talent? { place == 0 ? nil : tree.talents[place - 1] }

    /// Ranks it can be learned to.
    public var ranks: Int {
        switch self {
        case .battleRage, .unbroken, .keenEyes, .longStride: return 1
        case .pathfinder: return 2
        default: return 3
        }
    }

    /// What each rank gives the company its commander leads.
    public var edges: [Edge: Int] {
        switch self {
        case .keenEdge: return [.attack: 2]
        case .huntersMark: return [.hunting: 5]
        case .rammingDrill: return [.wardDamage: 5]
        case .bloodedSteel: return [.attack: 3]
        case .battleRage: return [:]
        case .thickHide: return [.defense: 2]
        case .fieldSurgeon: return [.healing: 2]
        case .gatewarden: return [.garrison: 5]
        case .ironRanks: return [.defense: 3]
        case .unbroken: return [.defense: 6, .attack: 3]
        case .keenEyes: return [.sight: 1]
        case .gleanersHand: return [.gathering: 5]
        case .deepSaddlebags: return [.load: 5]
        case .longStride: return [.moves: 1]
        case .pathfinder: return [.gathering: 5, .load: 5]
        }
    }

    /// What a rank does, in a line.
    public var effect: String {
        switch self {
        case .keenEdge: return "+2% attack a rank"
        case .huntersMark: return "+5% attack against the wilds a rank"
        case .rammingDrill: return "+5% to blows on a ward a rank"
        case .bloodedSteel: return "+3% attack a rank"
        case .battleRage: return "Its skill fires a battle sooner"
        case .thickHide: return "+2% defence a rank"
        case .fieldSurgeon: return "Heals 2 more each watch at rest a rank"
        case .gatewarden: return "+5% defence within its House's own walls a rank"
        case .ironRanks: return "+3% defence a rank"
        case .unbroken: return "+6% defence and +3% attack"
        case .keenEyes: return "Sees a tile further"
        case .gleanersHand: return "+5% gathered each watch a rank"
        case .deepSaddlebags: return "+5% carried home a rank"
        case .longStride: return "A move further each watch"
        case .pathfinder: return "+5% gathered and carried a rank"
        }
    }

    /// The trees an archetype's steward grows first, in its order.
    public static func path(for archetype: Archetype) -> [TalentTree] {
        switch archetype {
        case .warden: return [.ward, .steel, .road]
        case .vanguard: return [.steel, .ward, .road]
        case .outrider: return [.road, .steel, .ward]
        case .gleaner: return [.road, .ward, .steel]
        case .wallbreaker: return [.steel, .ward, .road]
        }
    }
}

extension Commander {
    /// Talent points: one for each level past the first.
    public var talentPoints: Int { level - 1 }

    /// The ranks it has learned of a talent.
    public func rank(of talent: Talent) -> Int {
        (talents ?? []).filter { $0 == talent }.count
    }

    /// Talent points it has yet to spend.
    public var pointsLeft: Int { max(0, talentPoints - (talents?.count ?? 0)) }

    /// Why it can't learn the next rank of a talent, if it can't.
    public func learnRefusal(of talent: Talent) -> RuleError? {
        if rank(of: talent) >= talent.ranks { return .talentMastered }
        if let opener = talent.opener, rank(of: opener) == 0 { return .needsTalent(opener) }
        if pointsLeft == 0 { return .noTalentPoints }
        return nil
    }

    /// Battles its fury takes to rise before its active skill fires: a
    /// battle sooner with Battle Rage, never sooner than every second.
    public var cadence: Int {
        let cadence = archetype.active.cadence
        return rank(of: .battleRage) > 0 ? max(2, cadence - 1) : cadence
    }

    /// What its talents give the company it leads.
    func talentEdge(_ edge: Edge) -> Int {
        (talents ?? []).reduce(0) { $0 + ($1.edges[edge] ?? 0) }
    }
}

extension GameState {
    /// Moonsalt it costs to forget a commander's talents, to learn anew.
    public static let forgettingCost = Stock(moonsalt: 20)

    mutating func learn(_ talent: Talent, by commanderID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        guard let index = commanderIndex(commanderID), commanders![index].owner == house else { throw .unknownCommander }
        if let refusal = commanders![index].learnRefusal(of: talent) { throw refusal }
        commanders![index].talents = (commanders![index].talents ?? []) + [talent]
        return [.talentLearned(commander: commanderID, house: house, talent: talent, rank: commanders![index].rank(of: talent))]
    }

    mutating func forgetTalents(of commanderID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        guard let index = commanderIndex(commanderID), commanders![index].owner == house else { throw .unknownCommander }
        guard !(commanders![index].talents ?? []).isEmpty else { throw .nothingToForget }
        let cost = GameState.forgettingCost
        guard houses[house].stock.covers(cost) else { throw .shortOf(houses[house].stock.shortfall(for: cost)) }
        houses[house].stock.debit(cost)
        commanders![index].talents = []
        return [.talentsForgotten(commander: commanderID, house: house)]
    }

    /// A steward spends its commanders' talent points, along the trees its
    /// archetype grows first: each talent in turn to its last rank.
    mutating func growTalents(for house: Int) -> [GameEvent] {
        var events: [GameEvent] = []
        for commander in commanders(of: house) where commander.pointsLeft > 0 {
            for tree in Talent.path(for: commander.archetype) {
                for talent in tree.talents {
                    while self.commander(commander.id).map({ $0.learnRefusal(of: talent) == nil }) == true {
                        events += (try? learn(talent, by: commander.id, as: house)) ?? []
                    }
                }
            }
        }
        return events
    }
}

/// A talent as a commander's screen shows it: its rank, and whether the
/// next can be learned, or why not.
public struct TalentLine: Equatable, Sendable, Identifiable {
    public var id: Talent { talent }
    public let talent: Talent
    public let rank: Int
    /// Why the next rank can't be learned; nil when it can.
    public let refusal: RuleError?

    public var isMastered: Bool { rank >= talent.ranks }
}

/// One of a commander's trees, its talents in order, and the points spent in it.
public struct TalentTreeLine: Equatable, Sendable, Identifiable {
    public var id: TalentTree { tree }
    public let tree: TalentTree
    public let lines: [TalentLine]

    public var spent: Int { lines.reduce(0) { $0 + $1.rank } }
}

extension Commander {
    /// Its three trees, as its screen shows them.
    public var talentTrees: [TalentTreeLine] {
        TalentTree.allCases.map { tree in
            TalentTreeLine(tree: tree, lines: tree.talents.map { talent in
                TalentLine(talent: talent, rank: rank(of: talent), refusal: learnRefusal(of: talent))
            })
        }
    }
}
