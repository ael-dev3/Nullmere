/// What a House's studies, works and commanders change, each named once:
/// every rule that a study can change asks `bonus(_:for:)` for its figure.
/// Percentages unless said otherwise.
public enum Bonus: Hashable, Sendable {
    /// More of a store from every hold's land.
    case yield(Resource)
    /// More of every store kept.
    case storage
    /// More gathered each watch from the land's sites.
    case gathering
    /// More carried home by a gathering company.
    case load
    /// A kind of company strikes harder.
    case attack(UnitKind)
    /// A kind of company stands firmer.
    case defense(UnitKind)
    /// Companies stand firmer within their own holds' walls.
    case garrison
    /// Blows on a ward take more of it.
    case wardDamage
    /// Wards mend faster.
    case wardMending
    /// Works rise sooner.
    case buildSpeed
    /// Works cost less.
    case buildCost
    /// Companies muster sooner.
    case trainingSpeed
    /// Companies cost less.
    case trainingCost
    /// Studies are done sooner.
    case studySpeed
    /// Commanders learn faster.
    case commanderExperience
    /// Moves a kind of company has in a watch, in moves.
    case moves(UnitKind)
    /// How far companies see, in tiles.
    case sight
    /// How far holds see, in tiles.
    case holdSight
    /// Health a resting company regains each watch, in points.
    case healing
    /// Tiers beyond the first a House's companies of war may muster at.
    case tier
}

/// The four branches of a House's studies.
public enum Branch: String, CaseIterable, Codable, Sendable {
    /// The land and its stores.
    case husbandry
    /// Companies and their tiers.
    case arms
    /// Works, walls and musters.
    case masonry
    /// Sight, roads, healing and commanders.
    case lore

    public var title: String {
        switch self {
        case .husbandry: return "Husbandry"
        case .arms: return "Arms"
        case .masonry: return "Masonry"
        case .lore: return "Lore"
        }
    }

    /// What a branch's studies cost at the first circle and grade.
    var price: Stock {
        switch self {
        case .husbandry: return Stock(grain: 40, timber: 30, stone: 10)
        case .arms: return Stock(grain: 30, timber: 10, stone: 30, moonsalt: 2)
        case .masonry: return Stock(grain: 10, timber: 40, stone: 40)
        case .lore: return Stock(grain: 30, timber: 20, stone: 10, moonsalt: 4)
        }
    }
}

/// A study a House can pursue at its Archive. Each has a branch, a circle
/// (the Archive level it needs), grades, studies it builds on, and the
/// rule it changes.
public enum Study: String, CaseIterable, Codable, Sendable {
    // Husbandry
    case furrowLore, woodcraft, stonecutting, saltRaking, deepCellars, gleaning, ladenCarts
    // Arms
    case drill, spearwork, fletching, horsemanship, ironRanks, greyCompanies, moonsteel
    // Masonry
    case scaffolding, mortar, musterYards, quartermasters, wardstones, bulwarks, siegecraft
    // Lore
    case lamplitLetters, roadcraft, starreading, beaconLore, fieldSurgeons, warChronicles, bannerLore

    /// A study and grade another needs first.
    public struct Requirement: Equatable, Sendable {
        public let study: Study
        public let grade: Int
    }

    /// A study's place in the tree and what each grade gives.
    public struct Profile: Sendable {
        public let title: String
        public let branch: Branch
        /// The Archive level it needs.
        public let circle: Int
        public let grades: Int
        public let needs: [Requirement]
        /// What each grade adds.
        public let gains: [Bonus: Int]
    }

    /// Every study's profile, made once.
    private static let profiles: [Study: Profile] = Dictionary(uniqueKeysWithValues: allCases.map { ($0, $0.makeProfile()) })

    public var profile: Profile { Study.profiles[self]! }

    private func makeProfile() -> Profile {
        func make(_ title: String, _ branch: Branch, circle: Int, grades: Int, needs: [(Study, Int)] = [],
                  _ gains: [Bonus: Int]) -> Profile {
            Profile(title: title, branch: branch, circle: circle, grades: grades,
                    needs: needs.map { Requirement(study: $0.0, grade: $0.1) }, gains: gains)
        }
        switch self {
        case .furrowLore: return make("Furrow Lore", .husbandry, circle: 1, grades: 3, [.yield(.grain): 8])
        case .woodcraft: return make("Woodcraft", .husbandry, circle: 1, grades: 3, [.yield(.timber): 8])
        case .stonecutting: return make("Stonecutting", .husbandry, circle: 1, grades: 3, [.yield(.stone): 8])
        case .saltRaking: return make("Salt Raking", .husbandry, circle: 2, grades: 3, needs: [(.stonecutting, 1)], [.yield(.moonsalt): 10])
        case .deepCellars: return make("Deep Cellars", .husbandry, circle: 2, grades: 3, needs: [(.woodcraft, 1)], [.storage: 10])
        case .gleaning: return make("Gleaning", .husbandry, circle: 2, grades: 3, needs: [(.furrowLore, 1)], [.gathering: 10])
        case .ladenCarts: return make("Laden Carts", .husbandry, circle: 3, grades: 2, needs: [(.gleaning, 2)], [.load: 15])
        case .drill: return make("Drill", .arms, circle: 1, grades: 1, [.tier: 1])
        case .spearwork: return make("Spearwork", .arms, circle: 1, grades: 3, [.attack(.spear): 5, .defense(.spear): 5])
        case .fletching: return make("Fletching", .arms, circle: 2, grades: 3, needs: [(.drill, 1)], [.attack(.bow): 6])
        case .horsemanship: return make("Horsemanship", .arms, circle: 2, grades: 3, needs: [(.drill, 1)],
                                        [.attack(.rider): 5, .defense(.rider): 5])
        case .ironRanks: return make("Iron Ranks", .arms, circle: 2, grades: 1, needs: [(.drill, 1), (.spearwork, 1)], [.tier: 1])
        case .greyCompanies: return make("Grey Companies", .arms, circle: 3, grades: 1, needs: [(.ironRanks, 1)], [.tier: 1])
        case .moonsteel: return make("Moonsteel", .arms, circle: 4, grades: 1, needs: [(.greyCompanies, 1), (.saltRaking, 1)], [.tier: 1])
        case .scaffolding: return make("Scaffolding", .masonry, circle: 1, grades: 3, [.buildSpeed: 8])
        case .mortar: return make("Mortar", .masonry, circle: 1, grades: 3, [.buildCost: 5])
        case .musterYards: return make("Muster Yards", .masonry, circle: 2, grades: 2, needs: [(.scaffolding, 1)], [.trainingSpeed: 10])
        case .quartermasters: return make("Quartermasters", .masonry, circle: 2, grades: 3, needs: [(.mortar, 1)], [.trainingCost: 5])
        case .wardstones: return make("Wardstones", .masonry, circle: 2, grades: 2, needs: [(.mortar, 1)], [.wardMending: 25])
        case .bulwarks: return make("Bulwarks", .masonry, circle: 3, grades: 3, needs: [(.wardstones, 1)], [.garrison: 5])
        case .siegecraft: return make("Siegecraft", .masonry, circle: 3, grades: 3, needs: [(.scaffolding, 2)], [.wardDamage: 10])
        case .lamplitLetters: return make("Lamplit Letters", .lore, circle: 1, grades: 3, [.studySpeed: 8])
        case .roadcraft: return make("Roadcraft", .lore, circle: 2, grades: 1, needs: [(.lamplitLetters, 1)],
                                     [.moves(.spear): 1, .moves(.bow): 1, .moves(.founder): 1])
        case .starreading: return make("Starreading", .lore, circle: 2, grades: 1, needs: [(.lamplitLetters, 1)], [.sight: 1])
        case .beaconLore: return make("Beacon Lore", .lore, circle: 2, grades: 1, needs: [(.lamplitLetters, 1)], [.holdSight: 1])
        case .fieldSurgeons: return make("Field Surgeons", .lore, circle: 2, grades: 2, needs: [(.lamplitLetters, 1)], [.healing: 5])
        case .warChronicles: return make("War Chronicles", .lore, circle: 3, grades: 3, needs: [(.lamplitLetters, 2)], [.commanderExperience: 15])
        case .bannerLore: return make("Banner Lore", .lore, circle: 4, grades: 2, needs: [(.warChronicles, 1)], [:])
        }
    }

    public var title: String { profile.title }
    public var branch: Branch { profile.branch }
    public var circle: Int { profile.circle }
    public var grades: Int { profile.grades }
    public var needs: [Requirement] { profile.needs }

    /// The studies of a branch, in the order of the tree.
    public static func of(_ branch: Branch) -> [Study] {
        allCases.filter { $0.branch == branch }
    }

    /// The tier a study opens to companies of war, if it opens one.
    public static func opening(tier: Int) -> Study? {
        switch tier {
        case 2: return .drill
        case 3: return .ironRanks
        case 4: return .greyCompanies
        case 5: return .moonsteel
        default: return nil
        }
    }

    /// Price of a grade, before the House's own works lessen it.
    public func price(grade: Int) -> Stock {
        let circleFactor = [1, 2, 3, 5][min(max(circle, 1), 4) - 1]
        let gradeFactor = [1, 2, 4][min(max(grade, 1), 3) - 1]
        return branch.price * (circleFactor * gradeFactor)
    }

    /// Watches a grade takes, before the House's studies hasten it.
    public func watches(grade: Int) -> Int {
        1 + circle + grade
    }

    /// What a grade gives, in all: each grade adds its gains again.
    public func gains(atGrade grade: Int) -> [Bonus: Int] {
        profile.gains.mapValues { $0 * grade }
    }

    /// What a study does, in a line.
    public var effect: String {
        switch self {
        case .furrowLore: return "+8% grain from the land each grade"
        case .woodcraft: return "+8% timber from the land each grade"
        case .stonecutting: return "+8% stone from the land each grade"
        case .saltRaking: return "+10% moonsalt from the land each grade"
        case .deepCellars: return "+10% to every store kept each grade"
        case .gleaning: return "+10% gathered from the land's sites each grade"
        case .ladenCarts: return "+15% carried home by gatherers each grade"
        case .drill: return "Companies of war of tier II"
        case .spearwork: return "+5% to the attack and defence of Spears each grade"
        case .fletching: return "+6% to the attack of Bows each grade"
        case .horsemanship: return "+5% to the attack and defence of Riders each grade"
        case .ironRanks: return "Companies of war of tier III"
        case .greyCompanies: return "Companies of war of tier IV"
        case .moonsteel: return "Companies of war of tier V"
        case .scaffolding: return "Works rise 8% sooner each grade"
        case .mortar: return "Works cost 5% less each grade"
        case .musterYards: return "Companies muster 10% sooner each grade"
        case .quartermasters: return "Companies cost 5% less each grade"
        case .wardstones: return "Wards mend 25% faster each grade"
        case .bulwarks: return "+5% defence within the House's own walls each grade"
        case .siegecraft: return "+10% to blows on a ward each grade"
        case .lamplitLetters: return "Studies done 8% sooner each grade"
        case .roadcraft: return "Spears, Bows and Founders march a move further"
        case .starreading: return "Companies see a tile further"
        case .beaconLore: return "Holds see a tile further"
        case .fieldSurgeons: return "Resting companies heal 5 more each watch each grade"
        case .warChronicles: return "Commanders learn 15% faster each grade"
        case .bannerLore: return "A commander answers the House's banner at each grade"
        }
    }
}

/// A study known to a grade.
public struct Learned: Codable, Equatable, Sendable {
    public let study: Study
    public var grade: Int
}

/// A study under way at a House's Archive.
public struct Pursuit: Codable, Equatable, Sendable {
    public let study: Study
    /// The grade it will reach.
    public let grade: Int
    public var watchesLeft: Int
}

/// A House's studies: what it knows, and what it is studying.
public struct Research: Codable, Equatable, Sendable {
    /// Each study known, in the order it was first learned.
    public internal(set) var known: [Learned] {
        didSet { totals = Research.sum(known) }
    }
    public internal(set) var pursuit: Pursuit?
    /// What its studies add, summed as they are learned: every rule asks
    /// it, often. Never kept, for it follows from what is known.
    private(set) var totals: [Bonus: Int]

    private enum CodingKeys: String, CodingKey {
        case known, pursuit
    }

    public init(known: [Learned] = [], pursuit: Pursuit? = nil) {
        self.known = known
        self.pursuit = pursuit
        self.totals = Research.sum(known)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        known = try container.decode([Learned].self, forKey: .known)
        pursuit = try container.decodeIfPresent(Pursuit.self, forKey: .pursuit)
        totals = Research.sum(known)
    }

    private static func sum(_ known: [Learned]) -> [Bonus: Int] {
        var totals: [Bonus: Int] = [:]
        for learned in known {
            for (gain, amount) in learned.study.profile.gains {
                totals[gain, default: 0] += amount * learned.grade
            }
        }
        return totals
    }

    /// What its studies add to a bonus.
    public func total(_ bonus: Bonus) -> Int {
        totals[bonus] ?? 0
    }

    public var isEmpty: Bool { known.isEmpty && pursuit == nil }

    /// The grade a study is known to; zero if not at all.
    public func grade(of study: Study) -> Int {
        known.first { $0.study == study }?.grade ?? 0
    }

    mutating func learn(_ study: Study, grade: Int) {
        if let index = known.firstIndex(where: { $0.study == study }) {
            known[index].grade = max(known[index].grade, grade)
        } else {
            known.append(Learned(study: study, grade: grade))
        }
    }
}

extension GameState {
    /// A House's figure for something its studies and works change: the
    /// sum of what each study known gives at its grade, with the Archive's
    /// own pace for studies.
    public func bonus(_ bonus: Bonus, for house: Int) -> Int {
        guard houses.indices.contains(house) else { return 0 }
        let studied = houses[house].research.total(bonus)
        return bonus == .studySpeed ? studied + GameState.archivePace * archiveLevel(of: house) : studied
    }

    /// Each store's yield bonus for a House at once, in percent.
    func yieldBonuses(for house: Int) -> Stock {
        guard houses.indices.contains(house) else { return .zero }
        let research = houses[house].research
        var total = Stock.zero
        for resource in Resource.allCases {
            total[resource] = research.total(.yield(resource))
        }
        return total
    }

    /// Percent sooner studies are done for each level of a House's Archive.
    public static let archivePace = 4

    /// The highest Archive among a House's holds.
    public func archiveLevel(of house: Int) -> Int {
        holds.lazy.filter { $0.owner == house }.map { $0.level(.archive) }.max() ?? 0
    }

    /// A count of watches made shorter by a percentage, rounded, never under one.
    static func hastened(_ watches: Int, by percent: Int) -> Int {
        max(1, (watches * (100 - min(max(percent, 0), 90)) + 50) / 100)
    }

    /// A price made smaller by a percentage, never by more than half.
    static func lessened(_ price: Stock, by percent: Int) -> Stock {
        price.scaled(percent: 100 - min(max(percent, 0), 50))
    }

    /// What the next grade of a study costs a House.
    public func studyPrice(of study: Study, grade: Int, for house: Int) -> Stock {
        study.price(grade: grade)
    }

    /// Watches the next grade of a study takes a House.
    public func studyWatches(of study: Study, grade: Int, for house: Int) -> Int {
        GameState.hastened(study.watches(grade: grade), by: bonus(.studySpeed, for: house))
    }

    /// Why a House can't begin the next grade of a study, if it can't.
    public func studyRefusal(of study: Study, for house: Int) -> RuleError? {
        guard houses.indices.contains(house) else { return .unknownHouse }
        let research = houses[house].research
        if let pursuit = research.pursuit { return .studyUnderWay(pursuit.study) }
        let grade = research.grade(of: study) + 1
        guard grade <= study.grades else { return .studiedFully }
        guard archiveLevel(of: house) >= study.circle else { return .needsArchive(study.circle) }
        if let missing = study.needs.first(where: { research.grade(of: $0.study) < $0.grade }) {
            return .needsStudy(missing.study, missing.grade)
        }
        let price = studyPrice(of: study, grade: grade, for: house)
        guard houses[house].stock.covers(price) else { return .shortOf(houses[house].stock.shortfall(for: price)) }
        return nil
    }

    /// The studies a House could begin now, stores aside.
    public func studiesOpen(to house: Int) -> [Study] {
        Study.allCases.filter { study in
            switch studyRefusal(of: study, for: house) {
            case nil, .shortOf?: return true
            default: return false
            }
        }
    }

    mutating func beginStudy(_ study: Study, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = studyRefusal(of: study, for: house) { throw refusal }
        let grade = houses[house].research.grade(of: study) + 1
        houses[house].stock.debit(studyPrice(of: study, grade: grade, for: house))
        houses[house].research.pursuit = Pursuit(study: study, grade: grade, watchesLeft: studyWatches(of: study, grade: grade, for: house))
        return [.studyBegun(house: house, study: study, grade: grade)]
    }

    /// Studies go on a watch at every House with an Archive high enough for
    /// them; one that has lost its Archive waits for another.
    mutating func advanceStudies() -> [GameEvent] {
        var events: [GameEvent] = []
        for house in houses.indices where !houses[house].isEliminated {
            guard var pursuit = houses[house].research.pursuit, archiveLevel(of: house) >= pursuit.study.circle else { continue }
            pursuit.watchesLeft -= 1
            guard pursuit.watchesLeft <= 0 else {
                houses[house].research.pursuit = pursuit
                continue
            }
            houses[house].research.pursuit = nil
            houses[house].research.learn(pursuit.study, grade: pursuit.grade)
            events.append(.studyCompleted(house: house, study: pursuit.study, grade: pursuit.grade))
            if pursuit.study == .bannerLore {
                events += commanderJoins(house, why: "answers the banner of")
            }
            if let tier = (2...Unit.highestTier).first(where: { Study.opening(tier: $0) == pursuit.study }) {
                record(.learning, [house], "\(houses[house].title) masters \(pursuit.study.title): its companies of war may muster at tier \(BuildingKind.numeral(tier)).")
            } else if pursuit.study.circle >= 4 || pursuit.grade == pursuit.study.grades && pursuit.study.circle >= 3 {
                record(.learning, [house], "\(houses[house].title) completes its study of \(pursuit.study.title).")
            }
        }
        return events
    }
}
