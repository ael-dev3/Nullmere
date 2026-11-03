/// A tree of a commander's talents: what it grows into as it rises.
public enum TalentTree: String, CaseIterable, Codable, Sendable, PlainCases {
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

    /// Its talents: a root, two branches of two from it, then a deep
    /// talent from either branch, one opened only by ten points spent in
    /// the tree, and its crown, by sixteen.
    public var talents: [Talent] { Talent.allCases.filter { $0.tree == self } }

    /// Its two branches, as its screen names them.
    public var branches: (String, String) {
        switch self {
        case .steel: return ("the hunt", "the ram")
        case .ward: return ("the mending", "the walls")
        case .road: return ("the field", "the train")
        }
    }
}

/// A commander's talent: learned a rank at a time, a point a rank, each
/// rank giving its edge again to the company it leads. The trees hold
/// sixty ranks between them, and a commander at its highest level has
/// twenty-nine points: it grows into one tree, or a little of two.
public enum Talent: String, CaseIterable, Codable, Sendable, PlainCases {
    // Steel
    case keenEdge, huntersMark, quarryCall, rammingDrill, sapperCraft, bloodedSteel, battleRage, moonsteel
    // Ward
    case thickHide, fieldSurgeon, poultice, gatewarden, bastion, ironRanks, unbroken, stillWater
    // Road
    case keenEyes, gleanersHand, furrowSense, deepSaddlebags, packTrain, longStride, pathfinder, lakeWalker

    public var tree: TalentTree {
        switch self {
        case .keenEdge, .huntersMark, .quarryCall, .rammingDrill, .sapperCraft, .bloodedSteel, .battleRage, .moonsteel: return .steel
        case .thickHide, .fieldSurgeon, .poultice, .gatewarden, .bastion, .ironRanks, .unbroken, .stillWater: return .ward
        case .keenEyes, .gleanersHand, .furrowSense, .deepSaddlebags, .packTrain, .longStride, .pathfinder, .lakeWalker: return .road
        }
    }

    public var title: String {
        switch self {
        case .keenEdge: return "Keen Edge"
        case .huntersMark: return "Hunter's Mark"
        case .quarryCall: return "Quarry Call"
        case .rammingDrill: return "Ramming Drill"
        case .sapperCraft: return "Sapper Craft"
        case .bloodedSteel: return "Blooded Steel"
        case .battleRage: return "Battle Rage"
        case .moonsteel: return "Moonsteel"
        case .thickHide: return "Thick Hide"
        case .fieldSurgeon: return "Field Surgeon"
        case .poultice: return "Poultice"
        case .gatewarden: return "Gatewarden"
        case .bastion: return "Bastion"
        case .ironRanks: return "Iron Ranks"
        case .unbroken: return "Unbroken"
        case .stillWater: return "Still Water"
        case .keenEyes: return "Keen Eyes"
        case .gleanersHand: return "Gleaner's Hand"
        case .furrowSense: return "Furrow Sense"
        case .deepSaddlebags: return "Deep Saddlebags"
        case .packTrain: return "Pack Train"
        case .longStride: return "Long Stride"
        case .pathfinder: return "Pathfinder"
        case .lakeWalker: return "Lake Walker"
        }
    }

    /// Its place in its tree, from the first.
    public var place: Int { tree.talents.firstIndex(of: self) ?? 0 }

    /// The talents that open it: any one of them learned will do.
    public var openers: [Talent] {
        let t = tree.talents
        switch place {
        case 0: return []
        case 1, 3: return [t[0]]
        case 2, 4: return [t[place - 1]]
        case 5: return [t[1], t[3]]
        default: return [t[place - 1]]
        }
    }

    /// The first talent that opens it, for older callers.
    public var opener: Talent? { openers.first }

    /// The branch it lies on, 0 or 1; nil for the root and what lies past the branches.
    public var branch: Int? {
        switch place {
        case 1, 2: return 0
        case 3, 4: return 1
        default: return nil
        }
    }

    /// Points to be spent in its tree before it opens.
    public var treePointsNeeded: Int {
        switch place {
        case 5: return 6
        case 6: return 10
        case 7: return 16
        default: return 0
        }
    }

    /// Ranks it can be learned to.
    public var ranks: Int {
        switch self {
        case .battleRage, .unbroken, .keenEyes, .longStride, .moonsteel, .stillWater, .lakeWalker: return 1
        case .pathfinder: return 2
        default: return 3
        }
    }

    /// What each rank gives the company its commander leads.
    public var edges: [Edge: Int] {
        switch self {
        case .keenEdge: return [.attack: 2]
        case .huntersMark: return [.hunting: 5]
        case .quarryCall: return [.hunting: 4, .attack: 1]
        case .rammingDrill: return [.wardDamage: 5]
        case .sapperCraft: return [.wardDamage: 4, .attack: 1]
        case .bloodedSteel: return [.attack: 3]
        case .battleRage: return [:]
        case .moonsteel: return [.attack: 8, .wardDamage: 5]
        case .thickHide: return [.defense: 2]
        case .fieldSurgeon: return [.healing: 2]
        case .poultice: return [.healing: 2, .defense: 1]
        case .gatewarden: return [.garrison: 5]
        case .bastion: return [.garrison: 4, .defense: 1]
        case .ironRanks: return [.defense: 3]
        case .unbroken: return [.defense: 6, .attack: 3]
        case .stillWater: return [.defense: 8, .healing: 4]
        case .keenEyes: return [.sight: 1]
        case .gleanersHand: return [.gathering: 5]
        case .furrowSense: return [.gathering: 4, .load: 1]
        case .deepSaddlebags: return [.load: 5]
        case .packTrain: return [.load: 4, .gathering: 1]
        case .longStride: return [.moves: 1]
        case .pathfinder: return [.gathering: 5, .load: 5]
        case .lakeWalker: return [.moves: 1, .sight: 1, .gathering: 6]
        }
    }

    /// What a rank does, in a line.
    public var effect: String {
        switch self {
        case .keenEdge: return "+2% attack a rank"
        case .huntersMark: return "+5% attack against the wilds a rank"
        case .quarryCall: return "+4% against the wilds and +1% attack a rank"
        case .rammingDrill: return "+5% to blows on a ward a rank"
        case .sapperCraft: return "+4% to blows on a ward and +1% attack a rank"
        case .bloodedSteel: return "+3% attack a rank"
        case .battleRage: return "Its skill fires a battle sooner"
        case .moonsteel: return "+8% attack and +5% to blows on a ward"
        case .thickHide: return "+2% defence a rank"
        case .fieldSurgeon: return "Heals 2 more each watch at rest a rank"
        case .poultice: return "Heals 2 more at rest and +1% defence a rank"
        case .gatewarden: return "+5% defence within its House's own walls a rank"
        case .bastion: return "+4% within its own walls and +1% defence a rank"
        case .ironRanks: return "+3% defence a rank"
        case .unbroken: return "+6% defence and +3% attack"
        case .stillWater: return "+8% defence, and heals 4 more at rest"
        case .keenEyes: return "Sees a tile further"
        case .gleanersHand: return "+5% gathered each watch a rank"
        case .furrowSense: return "+4% gathered and +1% carried a rank"
        case .deepSaddlebags: return "+5% carried home a rank"
        case .packTrain: return "+4% carried and +1% gathered a rank"
        case .longStride: return "A move further each watch"
        case .pathfinder: return "+5% gathered and carried a rank"
        case .lakeWalker: return "A move and a tile of sight further, +6% gathered"
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
    /// The tree it has learned most in, and how many ranks it holds in all;
    /// nil before it learns any. Ties go to the tree written first.
    public var leadingTree: (tree: TalentTree, ranks: Int)? {
        let learned = talents ?? []
        guard !learned.isEmpty else { return nil }
        let tree = TalentTree.allCases.max { a, b in
            let ca = learned.filter { $0.tree == a }.count, cb = learned.filter { $0.tree == b }.count
            return ca < cb || (ca == cb && TalentTree.allCases.firstIndex(of: a)! > TalentTree.allCases.firstIndex(of: b)!)
        }!
        return (tree, learned.count)
    }

    /// Points it has spent in a tree.
    public func spent(in tree: TalentTree) -> Int {
        (talents ?? []).filter { $0.tree == tree }.count
    }

    public var pointsLeft: Int { max(0, talentPoints - (talents?.count ?? 0)) }

    /// Why it can't learn the next rank of a talent, if it can't.
    public func learnRefusal(of talent: Talent) -> RuleError? {
        if rank(of: talent) >= talent.ranks { return .talentMastered }
        if !talent.openers.isEmpty, talent.openers.allSatisfy({ rank(of: $0) == 0 }) { return .needsTalent(talent.openers[0]) }
        if spent(in: talent.tree) < talent.treePointsNeeded { return .needsTreePoints(talent.tree, talent.treePointsNeeded) }
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
