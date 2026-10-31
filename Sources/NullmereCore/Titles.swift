/// Titles of the Spire: the keeper whose House holds the broken Spire, the
/// Moonspire the age before raised highest, names other Houses to the
/// realm's titles, boons and slights both, as a kingdom's king names its
/// lords. Each title is borne by one House at a time, and each House bears
/// one at most; a title is named anew no sooner than three watches after it
/// was last named; and every one lapses when the Spire passes from the
/// House that named it. Stewards name none, so a world of stewards goes as
/// it always did.
public enum Title: String, CaseIterable, Codable, Sendable {
    /// More gathered at the land's sites.
    case granaryWarden
    /// Every work raised sooner.
    case masterMason
    /// Every company strikes harder.
    case swordOfTheLake
    /// Every study done sooner.
    case sageOfTheStill
    /// Less gathered at the land's sites.
    case shoreBeggar
    /// Every company strikes softer.
    case craven
    /// Every company stands less firm.
    case oathbreaker

    public var title: String {
        switch self {
        case .granaryWarden: return "Warden of the Granaries"
        case .masterMason: return "Master Mason"
        case .swordOfTheLake: return "Sword of the Lake"
        case .sageOfTheStill: return "Sage of the Still"
        case .shoreBeggar: return "Beggar of the Shore"
        case .craven: return "Craven"
        case .oathbreaker: return "Oathbreaker"
        }
    }

    /// A boon to the House that bears it, or a slight.
    public var isBoon: Bool {
        switch self {
        case .granaryWarden, .masterMason, .swordOfTheLake, .sageOfTheStill: return true
        case .shoreBeggar, .craven, .oathbreaker: return false
        }
    }

    /// What it does to the House that bears it, in a line.
    public var effect: String {
        switch self {
        case .granaryWarden: return "+10% gathered at the land's sites"
        case .masterMason: return "every work raised 10% sooner"
        case .swordOfTheLake: return "+5% attack to every company"
        case .sageOfTheStill: return "every study done 10% sooner"
        case .shoreBeggar: return "10% less gathered at the land's sites"
        case .craven: return "5% less attack to every company"
        case .oathbreaker: return "5% less defence to every company"
        }
    }

    /// What it adds to a figure of the House that bears it.
    func bonus(_ bonus: Bonus) -> Int {
        switch (self, bonus) {
        case (.granaryWarden, .gathering): return 10
        case (.masterMason, .buildSpeed): return 10
        case (.swordOfTheLake, .attack): return 5
        case (.sageOfTheStill, .studySpeed): return 10
        case (.shoreBeggar, .gathering): return -10
        case (.craven, .attack): return -5
        case (.oathbreaker, .defense): return -5
        default: return 0
        }
    }
}

/// A title named: which, the House that bears it, the House that named it
/// and the watch it was named.
public struct Bestowal: Codable, Equatable, Sendable {
    public let title: Title
    public let house: Int
    public let by: Int
    public let watch: Int

    public init(title: Title, house: Int, by: Int, watch: Int) {
        self.title = title
        self.house = house
        self.by = by
        self.watch = watch
    }
}

extension GameState {
    /// The watches a title rests after it is named, before it is named anew.
    public static let titleRest = 3

    /// The titles borne now, the latest named last.
    public var titlesBorne: [Bestowal] { bestowals ?? [] }

    /// The title a House bears, if it bears one.
    public func title(of house: Int) -> Bestowal? {
        bestowals?.first { $0.house == house }
    }

    /// The House that may name the realm's titles now: a keeper's House
    /// that holds the broken Spire.
    public var titleGiver: Int? {
        guard let spire = shrines?.first(where: { $0.kind == .brokenSpire }), let holder = spire.holder,
              houses.indices.contains(holder), houses[holder].isPlayer, !houses[holder].isEliminated else { return nil }
        return holder
    }

    /// Why a House can't name another to a title now, if it can't: it must
    /// be a keeper's House holding the broken Spire, the other a living
    /// House not its own and not bearing the title already, and the title
    /// rested since it was last named.
    public func bestowRefusal(_ title: Title, on house: Int, as giver: Int) -> RuleError? {
        guard titleGiver == giver else { return .notTheSpiresHolder }
        guard house != giver, houses.indices.contains(house), !houses[house].isEliminated else { return .notApplicable }
        if let named = bestowals?.first(where: { $0.title == title }) {
            guard named.house != house else { return .notApplicable }
            if watch < named.watch + GameState.titleRest { return .titleResting(until: named.watch + GameState.titleRest) }
        }
        return nil
    }

    /// The Spire's keeper names a House to a title: whoever bore it before
    /// bears it no more, and the House named lays down any it bore.
    mutating func bestow(_ title: Title, on house: Int, as giver: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = bestowRefusal(title, on: house, as: giver) { throw refusal }
        var named = (bestowals ?? []).filter { $0.title != title && $0.house != house }
        named.append(Bestowal(title: title, house: house, by: giver, watch: watch))
        bestowals = named
        record(.title, [giver, house], "\(houses[giver].title), holding the broken Spire, names \(houses[house].title) \(title.title).")
        return [.titleBestowed(title: title, house: house, by: giver)]
    }

    /// As the watch turns: the titles named by a House that no longer holds
    /// the broken Spire, or is no keeper's, lapse.
    mutating func keepTitles() -> [GameEvent] {
        guard let named = bestowals, !named.isEmpty else { return [] }
        let giver = titleGiver
        let lapsed = named.filter { $0.by != giver }
        guard !lapsed.isEmpty else { return [] }
        let kept = named.filter { $0.by == giver }
        bestowals = kept.isEmpty ? nil : kept
        return Set(lapsed.map(\.by)).sorted().map { by in
            if houses.indices.contains(by) {
                record(.title, [by], "The titles \(houses[by].title) named lapse, the broken Spire no longer its.")
            }
            return .titlesLapsed(by: by, titles: lapsed.filter { $0.by == by })
        }
    }

    /// What the title a House bears adds to one of its figures.
    func titleBonus(_ bonus: Bonus, for house: Int) -> Int {
        guard let bestowals, !bestowals.isEmpty else { return 0 }
        return bestowals.first { $0.house == house }?.title.bonus(bonus) ?? 0
    }
}
