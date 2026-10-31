/// What the Houses of an alliance learn together: a study its leader
/// chooses, paid for by the stores its Houses give, each grade raising
/// every House of the alliance at once.
public enum AllianceStudy: String, CaseIterable, Codable, Sendable {
    /// More gathered at the land's sites.
    case fieldcraft
    /// Works rise sooner.
    case masonsCompact
    /// Companies muster sooner.
    case drillYards
    /// Companies of war strike harder.
    case oathOfSteel
    /// Companies of war stand firmer.
    case shieldOath
    /// Studies are done sooner.
    case sharedScrolls

    public var title: String {
        switch self {
        case .fieldcraft: return "Fieldcraft"
        case .masonsCompact: return "Masons' Compact"
        case .drillYards: return "Drill Yards"
        case .oathOfSteel: return "Oath of Steel"
        case .shieldOath: return "Shield Oath"
        case .sharedScrolls: return "Shared Scrolls"
        }
    }

    /// The grades each study has.
    public static let grades = 3

    /// What its grades give a figure of each House of the alliance.
    func bonus(_ bonus: Bonus, grade: Int) -> Int {
        switch (self, bonus) {
        case (.fieldcraft, .gathering): return 5 * grade
        case (.masonsCompact, .buildSpeed): return 4 * grade
        case (.drillYards, .trainingSpeed): return 4 * grade
        case (.oathOfSteel, .attack): return 3 * grade
        case (.shieldOath, .defense): return 3 * grade
        case (.sharedScrolls, .studySpeed): return 4 * grade
        default: return 0
        }
    }

    /// What it gives at a grade, in words.
    public func effect(grade: Int) -> String {
        switch self {
        case .fieldcraft: return "\(5 * grade)% more gathered at the land's sites"
        case .masonsCompact: return "works rise \(4 * grade)% sooner"
        case .drillYards: return "companies muster \(4 * grade)% sooner"
        case .oathOfSteel: return "every company of war strikes \(3 * grade)% harder"
        case .shieldOath: return "every company of war stands \(3 * grade)% firmer"
        case .sharedScrolls: return "studies are done \(4 * grade)% sooner"
        }
    }

    /// What its Houses together give for a grade of it.
    public func cost(grade: Int) -> Stock {
        let first: Stock
        switch self {
        case .fieldcraft: first = Stock(grain: 160, timber: 120, stone: 60)
        case .masonsCompact: first = Stock(grain: 80, timber: 160, stone: 160)
        case .drillYards: first = Stock(grain: 180, timber: 100, stone: 80)
        case .oathOfSteel, .shieldOath: first = Stock(grain: 140, timber: 120, stone: 120, moonsalt: 4)
        case .sharedScrolls: first = Stock(grain: 120, timber: 120, stone: 100, moonsalt: 6)
        }
        return first * grade
    }
}

/// What an alliance has learned together, and what its Houses have given
/// toward the grade it pursues.
public struct AllianceLore: Codable, Equatable, Sendable {
    /// Each study's grade learned, by its name.
    public internal(set) var grades: [String: Int] = [:]
    /// The study its leader has chosen to pursue.
    public internal(set) var pursuit: AllianceStudy?
    /// What its Houses have given toward the pursuit's next grade.
    public internal(set) var given = Stock.zero
    /// What each House has given in all, in barter worth, by House.
    public internal(set) var givers: [String: Int] = [:]

    public init() {}

    public func grade(of study: AllianceStudy) -> Int { grades[study.rawValue] ?? 0 }

    /// The grade the pursuit's stores go toward, if one is pursued.
    public var next: (study: AllianceStudy, grade: Int)? {
        pursuit.map { ($0, grade(of: $0) + 1) }
    }

    /// What every grade learned gives a figure of the alliance's Houses.
    /// A study's grade is looked up only if its grades give the figure
    /// anything, so much a grade: this is asked for every figure of every
    /// company weighed, and each study gives one.
    func bonus(_ bonus: Bonus) -> Int {
        guard !grades.isEmpty else { return 0 }
        return AllianceStudy.allCases.reduce(0) { total, study in
            study.bonus(bonus, grade: 1) == 0 ? total : total + study.bonus(bonus, grade: grade(of: study))
        }
    }

    /// What a House has given in all, in barter worth.
    public func given(by house: Int) -> Int { givers[String(house)] ?? 0 }
}

extension GameState {
    /// The barter worth given to an alliance that brings the giver a Salt
    /// Hourglass, each time it is passed.
    public static let givenPerHourglass = 300

    private func allianceIndex(of house: Int) -> Int? {
        alliances?.firstIndex { $0.members.contains(house) }
    }

    /// What the studies of a House's alliance give a figure of it.
    func allianceLoreBonus(_ bonus: Bonus, for house: Int) -> Int {
        guard let alliances, !alliances.isEmpty else { return 0 }
        for alliance in alliances where alliance.lore != nil && alliance.members.contains(house) {
            return alliance.lore!.bonus(bonus)
        }
        return 0
    }

    /// Why a House can't set its alliance to pursue a study, if it can't.
    func pursuitRefusal(_ study: AllianceStudy, by house: Int) -> RuleError? {
        guard let sworn = alliance(of: house) else { return .notInAlliance }
        guard sworn.leader == house else { return .notAllianceLeader }
        let lore = sworn.lore ?? AllianceLore()
        guard lore.grade(of: study) < AllianceStudy.grades else { return .allianceStudyMastered }
        guard lore.pursuit != study else { return .alreadyPursued }
        return nil
    }

    /// The leader sets the alliance to pursue a study; what was given
    /// toward another goes toward it instead.
    mutating func pursue(_ study: AllianceStudy, by house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = pursuitRefusal(study, by: house) { throw refusal }
        let index = allianceIndex(of: house)!
        var lore = alliances![index].lore ?? AllianceLore()
        lore.pursuit = study
        alliances![index].lore = lore
        return [.allianceStudyChosen(alliance: alliances![index].id, study: study)]
    }

    /// Why a House can't give stores to its alliance's study, if it can't.
    func allianceGiftRefusal(_ stock: Stock, by house: Int) -> RuleError? {
        guard let sworn = alliance(of: house) else { return .notInAlliance }
        guard sworn.lore?.pursuit != nil else { return .noAllianceStudy }
        guard !stock.isZero, Resource.allCases.allSatisfy({ stock[$0] >= 0 }) else { return .nothingGiven }
        let held = houses[house].stock
        return held.covers(stock) ? nil : .shortOf(held.shortfall(for: stock))
    }

    /// A House gives stores toward its alliance's study: each grade they
    /// pay for is learned at once, and every so much given brings the giver
    /// a Salt Hourglass.
    mutating func giveToAlliance(_ stock: Stock, by house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = allianceGiftRefusal(stock, by: house) { throw refusal }
        let index = allianceIndex(of: house)!
        let id = alliances![index].id
        var lore = alliances![index].lore!
        houses[house].stock.debit(stock)
        lore.given = lore.given + stock
        let worth = Resource.allCases.reduce(0) { $0 + stock[$1] * $1.worth }
        let before = lore.given(by: house)
        lore.givers[String(house)] = before + worth
        let toward = lore.next!
        var events: [GameEvent] = [.allianceGift(house: house, alliance: id, stock: stock, study: toward.study, grade: toward.grade)]
        while let next = lore.next, next.grade <= AllianceStudy.grades, lore.given.covers(next.study.cost(grade: next.grade)) {
            let (study, grade) = next
            lore.given.debit(study.cost(grade: grade))
            lore.grades[study.rawValue] = grade
            if grade == AllianceStudy.grades { lore.pursuit = nil }
            events.append(.allianceStudied(alliance: id, study: study, grade: grade))
            record(.alliance, alliances![index].members,
                   "\(alliances![index].name) learns \(study.title) \(BuildingKind.numeral(grade)) together.")
        }
        alliances![index].lore = lore
        let hourglasses = (before + worth) / GameState.givenPerHourglass - before / GameState.givenPerHourglass
        events += give(.hourglass, hourglasses, to: house)
        return events
    }
}
