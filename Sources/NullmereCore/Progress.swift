import Foundation

/// A deed a House may do once in an age, for the honour of it. A keeper
/// keeps the deeds of every age they held a House in, and nothing else of
/// it: each age every House begins alike.
public enum Deed: String, Codable, CaseIterable, Sendable {
    case founder
    case wildbane
    case greatHunter
    case firstHarvest
    case scholar
    case fifthTier
    case greatWalls
    case sworn
    case hostTriumphant
    case conqueror
    case honoured
    case veteranCommander
    case spireBegun

    public var title: String {
        switch self {
        case .founder: return "Founder"
        case .wildbane: return "Wildbane"
        case .greatHunter: return "Great Hunter"
        case .firstHarvest: return "First Harvest"
        case .scholar: return "Scholar"
        case .fifthTier: return "Fifth Tier"
        case .greatWalls: return "Great Walls"
        case .sworn: return "Sworn"
        case .hostTriumphant: return "Host Triumphant"
        case .conqueror: return "Conqueror"
        case .honoured: return "Honoured"
        case .veteranCommander: return "Veteran Commander"
        case .spireBegun: return "Spire Begun"
        }
    }

    /// What the House did, as the realm tells it.
    public var deed: String {
        switch self {
        case .founder: return "founded a hold beyond its seat"
        case .wildbane: return "struck down a company of the wilds"
        case .greatHunter: return "struck down a company of the wilds of level VII or more"
        case .firstHarvest: return "brought home stores from a site of the land"
        case .scholar: return "learned ten grades of study"
        case .fifthTier: return "mustered a company of tier V"
        case .greatWalls: return "raised its seat's walls to V"
        case .sworn: return "sworn itself to an alliance"
        case .hostTriumphant: return "taken a hold with a host it called"
        case .conqueror: return "taken a hold of another House"
        case .honoured: return "stood first in a happening of the realm"
        case .veteranCommander: return "seen a commander of its rise to level X"
        case .spireBegun: return "raised the first stage of the Moonspire"
        }
    }
}

/// A deed done, by which House and in which watch.
public struct DeedDone: Codable, Equatable, Sendable {
    public let house: Int
    public let deed: Deed
    public let watch: Int
    /// Whether its House has been told, as the watch turned.
    public internal(set) var told: Bool
}

/// The charges every House is set, one at a time and in this order: first
/// steps on the way, each bringing stores as the watch turns after it is
/// done.
public enum Charge: Int, Codable, CaseIterable, Sendable {
    case raiseGranary
    case musterCompany
    case raiseArchive
    case learnStudy
    case foundHold
    case leadCompany
    case gatherSite
    case huntWild
    case swearBanner
    case raiseMusterHall
    case drillCompany

    public var title: String {
        switch self {
        case .raiseGranary: return "Raise a Granary at your seat"
        case .musterCompany: return "Muster a second company of war"
        case .raiseArchive: return "Raise an Archive"
        case .learnStudy: return "Learn a study at your Archive"
        case .foundHold: return "Found a second hold"
        case .leadCompany: return "Set a commander at the head of a company"
        case .gatherSite: return "Bring home stores from a site of the land"
        case .huntWild: return "Strike down a company of the wilds"
        case .swearBanner: return "Swear to an alliance, or raise a banner"
        case .raiseMusterHall: return "Raise a Muster Hall to III"
        case .drillCompany: return "Drill a company to twice its first muster"
        }
    }

    public var reward: Stock {
        switch self {
        case .raiseGranary: return Stock(grain: 30, timber: 30)
        case .musterCompany: return Stock(grain: 40, stone: 20)
        case .raiseArchive: return Stock(timber: 40, stone: 40)
        case .learnStudy: return Stock(grain: 40, timber: 40, moonsalt: 2)
        case .foundHold: return Stock(grain: 50, timber: 50, stone: 30)
        case .leadCompany: return Stock(grain: 40, stone: 40)
        case .gatherSite: return Stock(timber: 50, stone: 50)
        case .huntWild: return Stock(grain: 60, moonsalt: 3)
        case .swearBanner: return Stock(grain: 50, timber: 50, stone: 50)
        case .raiseMusterHall: return Stock(grain: 60, timber: 60, stone: 60, moonsalt: 5)
        case .drillCompany: return Stock(grain: 90, timber: 40)
        }
    }

    /// The items it brings beside its stores: the first steps bring
    /// hourglasses, to learn to hasten what is under way by.
    public var items: [ItemKind] {
        switch self {
        case .raiseGranary, .musterCompany: return [.hourglass]
        case .raiseArchive: return [.hourglass, .hourglass]
        case .learnStudy: return [.grainCache]
        case .foundHold: return [.hourglass, .timberCache]
        case .leadCompany, .huntWild, .drillCompany: return [.mendingDraught]
        case .gatherSite: return [.stoneCache]
        case .swearBanner: return [.wardStone]
        case .raiseMusterHall: return [.hourglass, .hourglass, .moonsaltCache]
        }
    }

    /// Whether a House has done it.
    func isMet(by house: Int, in state: GameState) -> Bool {
        switch self {
        case .raiseGranary: return state.seat(of: house).map { $0.level(.granary) >= 1 } ?? false
        case .musterCompany: return state.units(of: house).filter(\.kind.isMilitary).count >= 2
        case .raiseArchive: return state.holds(of: house).contains { $0.level(.archive) >= 1 }
        case .learnStudy: return !state.houses[house].research.known.isEmpty
        case .foundHold: return state.holds(of: house).count >= 2 || state.hasDone(.founder, house)
        case .leadCompany: return state.units(of: house).contains { $0.leader != nil }
        case .gatherSite: return state.hasDone(.firstHarvest, house)
        case .huntWild: return state.hasDone(.wildbane, house)
        case .swearBanner: return state.alliance(of: house) != nil || state.hasDone(.sworn, house)
        case .raiseMusterHall: return state.holds(of: house).contains { $0.level(.musterHall) >= 3 }
        case .drillCompany: return state.units(of: house).contains { $0.kind.hasTiers && state.musterPercent(of: $0) >= 200 }
        }
    }
}

extension GameState {
    // MARK: Might

    /// A House's might: its companies of war and its walls, its works, its
    /// learning and its commanders, in one figure that ranks the Houses.
    /// Known to every keeper, as the realm reckons it.
    public func might(of house: Int) -> Int {
        if let reputedMight, reputedMight.indices.contains(house) { return reputedMight[house] }
        guard houses.indices.contains(house) else { return 0 }
        let works = holds(of: house).reduce(0) { $0 + $1.levels.values.reduce(0, +) }
        let learning = houses[house].research.known.reduce(0) { $0 + $1.grade }
        let leading = commanders(of: house).reduce(0) { $0 + $1.level }
        return strength(of: house) + 10 * works + 8 * learning + 4 * leading
    }

    /// The Houses standing, mightiest first.
    public var byMight: [Int] {
        let might = houses.map { self.might(of: $0.id) }
        return livingHouses.map(\.id).sorted { (-might[$0], $0) < (-might[$1], $1) }
    }

    // MARK: Deeds

    /// The deeds a House has done this age, in the order it did them.
    public func deeds(of house: Int) -> [Deed] {
        deedsDone?.filter { $0.house == house }.map(\.deed) ?? []
    }

    public func hasDone(_ deed: Deed, _ house: Int) -> Bool {
        deedsDone?.contains { $0.house == house && $0.deed == deed } ?? false
    }

    /// The deeds in what was done, each noted once for its House.
    mutating func noteDeeds(_ events: [GameEvent]) {
        for event in events {
            switch event {
            case .holdFounded(let id):
                if let owner = hold(id)?.owner { did(.founder, owner) }
            case .hunted(let hunt) where hunt.wildFell:
                did(.wildbane, hunt.attackerOwner)
                if hunt.level >= 7 { did(.greatHunter, hunt.attackerOwner) }
            case .delivered(_, let owner, _, _):
                did(.firstHarvest, owner)
            case .studyCompleted(let house, _, _):
                if houses[house].research.known.reduce(0, { $0 + $1.grade }) >= 10 { did(.scholar, house) }
            case .unitTrained(let id, _):
                if let unit = unit(id), unit.tier >= 5 { did(.fifthTier, unit.owner) }
            case .buildingCompleted(let id, let kind, let level):
                guard let hold = hold(id) else { break }
                if kind == .walls, level >= 5, hold.isSeat { did(.greatWalls, hold.owner) }
                if kind == .moonspire { did(.spireBegun, hold.owner) }
            case .allianceFounded(_, let house), .allianceJoined(_, let house):
                did(.sworn, house)
            case .rallyStruck(_, let caller, _, _, true):
                did(.hostTriumphant, caller)
            case .holdCaptured(_, _, let by):
                did(.conqueror, by)
            case .happeningEnded(_, let leaders):
                if let first = leaders.first { did(.honoured, first) }
            case .commanderRose(_, let house, let level) where level >= 10:
                did(.veteranCommander, house)
            default:
                break
            }
        }
    }

    private mutating func did(_ deed: Deed, _ house: Int) {
        guard houses.indices.contains(house), !hasDone(deed, house) else { return }
        deedsDone = (deedsDone ?? []) + [DeedDone(house: house, deed: deed, watch: watch, told: false)]
    }

    /// The deeds done since the watch last turned, told as it turns.
    mutating func tellDeeds() -> [GameEvent] {
        guard var done = deedsDone, done.contains(where: { !$0.told }) else { return [] }
        var events: [GameEvent] = []
        for index in done.indices where !done[index].told {
            done[index].told = true
            events.append(.deedDone(house: done[index].house, deed: done[index].deed))
        }
        deedsDone = done
        return events
    }

    // MARK: Charges

    /// The charge a House is set now; none once it has done them all.
    public func charge(of house: Int) -> Charge? {
        let done = chargesDone.flatMap { $0.indices.contains(house) ? $0[house] : nil } ?? 0
        return Charge(rawValue: done)
    }

    /// As the watch turns: each charge done brings its stores and items,
    /// and the next is set, perhaps done already too.
    mutating func fulfilCharges() -> [GameEvent] {
        var done = chargesDone ?? []
        if done.count < houses.count { done += Array(repeating: 0, count: houses.count - done.count) }
        var events: [GameEvent] = []
        for house in houses.indices where !houses[house].isEliminated {
            while let charge = Charge(rawValue: done[house]), charge.isMet(by: house, in: self) {
                store(charge.reward, for: house)
                done[house] += 1
                events.append(.chargeDone(house: house, charge: charge, reward: charge.reward))
                events += give(charge.items, to: house)
            }
        }
        if chargesDone != done { chargesDone = done }
        return events
    }
}

extension RealmState {
    /// As an age ends, each keeper who held a House in it is remembered for
    /// it: five renown for each deed their House did, ten if it stood at
    /// the end, and fifty and a title to the age's victor; and every deed
    /// joins those of their other ages. Nothing of it goes into the next
    /// age's world: there a keeper's House begins as every other does.
    mutating func rememberTheAge() {
        guard let outcome = world.outcome else { return }
        for index in keepers.indices {
            guard let house = keepers[index].house, world.houses.indices.contains(house) else { continue }
            let deeds = world.deeds(of: house)
            var gained = 5 * deeds.count + (world.houses[house].isEliminated ? 0 : 10)
            if outcome.winner == house {
                gained += 50
                let title = outcome.kind == .ascendancy ? "Raiser of the Moonspire" : "Lord of the Lake"
                keepers[index].titles = (keepers[index].titles ?? []) + ["\(title), Age \(age)"]
            }
            keepers[index].renown = (keepers[index].renown ?? 0) + gained
            let known = keepers[index].deeds ?? []
            let all = Deed.allCases.filter { known.contains($0) || deeds.contains($0) }
            keepers[index].deeds = all.isEmpty ? nil : all
        }
    }
}
