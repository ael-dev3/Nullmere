/// Edicts of the realm: laws a realm makes for itself. A keeper's House of
/// two holds or more puts one of a few to the realm; every House votes aye
/// or nay over three watches, each with its might; and an edict passed
/// holds every House for twenty watches. The rules keep it, not the
/// Houses' good faith: a House that breaks it is named in the Chronicle and
/// pays a fine to the House it wronged, once a watch for each edict it
/// breaks, and loses renown as the age ends.
public enum EdictKind: String, Codable, CaseIterable, Sendable {
    /// No House strikes another's hold about the full moon.
    case moonPeace
    /// No House strikes another's companies out at the land's work.
    case harvestTruce
    /// No House strikes Founders or Lanterns.
    case safeConduct
    /// No House strikes a company standing on a holy site.
    case holyGround

    public var title: String {
        switch self {
        case .moonPeace: return "the Moon's Peace"
        case .harvestTruce: return "the Harvest Truce"
        case .safeConduct: return "Safe Conduct"
        case .holyGround: return "Holy Ground"
        }
    }

    /// Its name at the head of a line.
    public var heading: String { title.prefix(1).uppercased() + title.dropFirst() }

    /// What it forbids, as the realm reads it out.
    public var law: String {
        switch self {
        case .moonPeace: return "no House strikes another's hold in the five watches about each full moon"
        case .harvestTruce: return "no House strikes another's companies out at the land's work"
        case .safeConduct: return "no House strikes Founders or Lanterns"
        case .holyGround: return "no House strikes a company standing on a holy site"
        }
    }
}

public struct Edict: Codable, Equatable, Identifiable, Sendable {
    /// A House's breaking of an edict: whom it wronged, and when.
    public struct Breach: Codable, Equatable, Sendable {
        public let house: Int
        public let against: Int
        public let watch: Int

        public init(house: Int, against: Int, watch: Int) {
            self.house = house
            self.against = against
            self.watch = watch
        }
    }

    public let id: Int
    public let kind: EdictKind
    /// The House that put it to the realm.
    public let proposer: Int
    /// The watch it was put to the vote.
    public let proposed: Int
    /// The Houses for it and against it, each once, in the order they voted.
    public internal(set) var ayes: [Int]
    public internal(set) var nays: [Int]
    /// The watch its vote closed, and the might on each side as it did.
    public internal(set) var closed: Int?
    public internal(set) var ayeMight: Int?
    public internal(set) var nayMight: Int?
    /// Each time a House broke it, in order.
    public internal(set) var breaches: [Breach]

    public init(id: Int, kind: EdictKind, proposer: Int, proposed: Int, ayes: [Int] = [], nays: [Int] = [], closed: Int? = nil,
                ayeMight: Int? = nil, nayMight: Int? = nil, breaches: [Breach] = []) {
        self.id = id
        self.kind = kind
        self.proposer = proposer
        self.proposed = proposed
        self.ayes = ayes
        self.nays = nays
        self.closed = closed
        self.ayeMight = ayeMight
        self.nayMight = nayMight
        self.breaches = breaches
    }

    /// Whether it passed: its vote closed with more might for it than against.
    public var passed: Bool { closed != nil && (ayeMight ?? 0) > (nayMight ?? 0) }
}

extension GameState {
    /// The watches an edict is before the realm, and the watches one passed holds.
    public static let edictVote = 3
    public static let edictLasts = 20
    /// What putting an edict to the realm costs the House that does.
    public static let edictCost = Stock(grain: 100, moonsalt: 10)
    /// What a House pays the House it wronged for breaking an edict, as
    /// much as it has.
    public static let edictFine = Stock(grain: 150, timber: 75, stone: 75, moonsalt: 15)
    /// The renown a House loses as the age ends for each edict it broke.
    public static let renownPerBreach = 3
    /// The most edicts the realm remembers, the oldest let go first.
    public static let edictsKept = 24

    /// Every edict put to the realm this age, the latest last.
    public var edictsOfTheRealm: [Edict] { edicts ?? [] }

    /// The edict before the realm, its vote open, if one is.
    public var edictInVote: Edict? { edictsOfTheRealm.first { $0.closed == nil } }

    /// Whether an edict holds the realm now: passed, and within its watches.
    public func isInForce(_ edict: Edict) -> Bool {
        guard edict.passed, let closed = edict.closed else { return false }
        return watch < closed + GameState.edictLasts
    }

    /// The edicts holding the realm now.
    public var edictsInForce: [Edict] { edictsOfTheRealm.filter(isInForce) }

    /// The watches an edict in force still holds, counting this one.
    public func watchesLeft(of edict: Edict) -> Int {
        guard isInForce(edict), let closed = edict.closed else { return 0 }
        return closed + GameState.edictLasts - watch
    }

    /// The watches an edict's vote is still open, counting this one.
    public func watchesToVote(on edict: Edict) -> Int {
        edict.closed == nil ? max(edict.proposed + GameState.edictVote - watch, 1) : 0
    }

    /// Whether the moon is full enough for the Moon's Peace: the five
    /// watches about each full.
    public static func moonIsFull(at watch: Int) -> Bool {
        let age = moonAge(at: watch)
        return age <= 2 || age >= lunarMonth - 2
    }

    /// The might for an edict and against it, as its votes stand.
    public func tally(of edict: Edict) -> (aye: Int, nay: Int) {
        (edict.ayes.reduce(0) { $0 + might(of: $1) }, edict.nays.reduce(0) { $0 + might(of: $1) })
    }

    /// How many times a House broke the realm's edicts this age.
    public func breaches(by house: Int) -> Int {
        edictsOfTheRealm.reduce(0) { $0 + $1.breaches.filter { $0.house == house }.count }
    }

    // MARK: Putting an edict to the realm, and voting

    /// Why a House can't put an edict to the realm now, if it can't.
    public func edictRefusal(_ kind: EdictKind, as house: Int) -> RuleError? {
        guard houses.indices.contains(house), houses[house].isPlayer, !houses[house].isEliminated else { return .notAKeeper }
        guard holds(of: house).count >= 2 else { return .tooFewHolds }
        if edictInVote != nil { return .edictInVote }
        if edictsInForce.contains(where: { $0.kind == kind }) { return .edictInForce }
        if edictsOfTheRealm.contains(where: { $0.proposer == house && watch - $0.proposed < GameState.edictLasts }) { return .proposedLately }
        guard houses[house].stock.covers(GameState.edictCost) else { return .shortOf(houses[house].stock.shortfall(for: GameState.edictCost)) }
        return nil
    }

    mutating func proposeEdict(_ kind: EdictKind, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = edictRefusal(kind, as: house) { throw refusal }
        houses[house].stock.debit(GameState.edictCost)
        let edict = Edict(id: takeID(), kind: kind, proposer: house, proposed: watch, ayes: [house])
        edicts = Array((edictsOfTheRealm + [edict]).suffix(GameState.edictsKept))
        record(.edict, [house], "\(houses[house].title) puts \(kind.title) to the realm: \(kind.law).")
        return [.edictProposed(edict)]
    }

    /// Why a House can't vote on an edict now, if it can't.
    public func voteRefusal(on edictID: Int, as house: Int) -> RuleError? {
        guard houses.indices.contains(house), !houses[house].isEliminated else { return .notAKeeper }
        guard let edict = edictsOfTheRealm.first(where: { $0.id == edictID }) else { return .unknownEdict }
        guard edict.closed == nil else { return .voteClosed }
        if edict.ayes.contains(house) || edict.nays.contains(house) { return .votedAlready }
        return nil
    }

    mutating func vote(on edictID: Int, aye: Bool, as house: Int) throws(RuleError) -> [GameEvent] {
        guard houses.indices.contains(house), houses[house].isPlayer else { throw .notAKeeper }
        if let refusal = voteRefusal(on: edictID, as: house) { throw refusal }
        cast(aye, on: edictID, by: house)
        return [.edictVoted(edict: edictID, house: house, aye: aye)]
    }

    private mutating func cast(_ aye: Bool, on edictID: Int, by house: Int) {
        guard let index = edicts?.firstIndex(where: { $0.id == edictID }) else { return }
        if aye { edicts![index].ayes.append(house) } else { edicts![index].nays.append(house) }
    }

    /// How a steward votes: the wary and the steadfast for the realm's law;
    /// the ambitious and the cunning against it, unless theirs is of the
    /// weaker half of the realm; for Holy Ground, any House holding a site.
    public func stewardVotesAye(on kind: EdictKind, as house: Int) -> Bool {
        if kind == .holyGround, holySites.contains(where: { $0.holder == house }) { return true }
        switch houses[house].temperament {
        case .wary, .steadfast: return true
        case .ambitious, .cunning:
            let ranked = byMight
            return (ranked.firstIndex(of: house) ?? 0) >= ranked.count / 2
        }
    }

    /// The realm's edicts as the watch turns: the stewards vote on an edict
    /// before the realm, its vote closes when its watches are done, and an
    /// edict whose watches are done lapses.
    mutating func turnEdicts() -> [GameEvent] {
        guard let all = edicts, !all.isEmpty else { return [] }
        var events: [GameEvent] = []
        for edict in all where edict.closed == nil {
            for house in houses.indices where !houses[house].isPlayer && !houses[house].isEliminated
                && !edict.ayes.contains(house) && !edict.nays.contains(house) {
                cast(stewardVotesAye(on: edict.kind, as: house), on: edict.id, by: house)
            }
            guard watch >= edict.proposed + GameState.edictVote, let index = edicts?.firstIndex(where: { $0.id == edict.id }) else { continue }
            let (aye, nay) = tally(of: edicts![index])
            edicts![index].closed = watch
            edicts![index].ayeMight = aye
            edicts![index].nayMight = nay
            let closed = edicts![index]
            let voters = closed.ayes.count + closed.nays.count
            if closed.passed {
                record(.edict, closed.ayes, "The realm passes \(edict.kind.title), \(closed.ayes.count) of \(voters) Houses for it: "
                       + "for \(GameState.edictLasts) watches \(edict.kind.law).")
                events.append(.edictPassed(closed))
            } else {
                record(.edict, closed.nays, "The realm refuses \(edict.kind.title), \(closed.nays.count) of \(voters) Houses against it.")
                events.append(.edictFailed(closed))
            }
        }
        for edict in edictsOfTheRealm where edict.passed && edict.closed.map({ watch == $0 + GameState.edictLasts }) == true {
            record(.edict, [], "\(edict.kind.heading) holds the realm no longer.")
            events.append(.edictLapsed(edict))
        }
        return events
    }

    // MARK: Breaking an edict

    /// The edicts in force a company would break by striking a hex: none
    /// when none holds, or what stands there is no other House's.
    public func edictsBroken(striking target: Hex, from striker: Unit) -> [Edict] {
        guard let edicts, !edicts.isEmpty else { return [] }
        let inForce = edicts.filter(isInForce)
        guard !inForce.isEmpty, let foe = foe(at: target, for: striker.owner) else { return [] }
        let struck = foe.unit.flatMap { unit($0) }
        return inForce.filter { edict in
            switch edict.kind {
            case .moonPeace: return foe.hold != nil && GameState.moonIsFull(at: watch)
            case .harvestTruce: return struck.map(isOutGathering) ?? false
            case .safeConduct: return struck.map { !$0.kind.isMilitary } ?? false
            case .holyGround: return struck != nil && shrine(at: target) != nil
            }
        }
    }

    /// A strike that breaks edicts in force: the striker's House named in
    /// the Chronicle, paying the House it wronged the fine, as much as it
    /// has, once a watch for each edict it breaks.
    mutating func breakEdicts(striking target: Hex, from striker: Unit) -> [GameEvent] {
        let broken = edictsBroken(striking: target, from: striker)
        guard !broken.isEmpty, let wronged = foe(at: target, for: striker.owner)?.owner else { return [] }
        let breaker = striker.owner
        var events: [GameEvent] = []
        for edict in broken where !edict.breaches.contains(where: { $0.house == breaker && $0.watch == watch }) {
            guard let index = edicts?.firstIndex(where: { $0.id == edict.id }) else { continue }
            let stock = houses[breaker].stock, owed = GameState.edictFine
            let fine = Stock(grain: min(stock.grain, owed.grain), timber: min(stock.timber, owed.timber),
                             stone: min(stock.stone, owed.stone), moonsalt: min(stock.moonsalt, owed.moonsalt))
            houses[breaker].stock.debit(fine)
            store(fine, for: wronged)
            edicts![index].breaches.append(Edict.Breach(house: breaker, against: wronged, watch: watch))
            let paid = fine == .zero ? "with nothing to pay them" : "and pays them \(fine)"
            record(.betrayal, [breaker, wronged], "\(houses[breaker].title) breaks \(edict.kind.title), striking \(houses[wronged].title), \(paid).")
            events.append(.edictBroken(edict: edict.id, kind: edict.kind, by: breaker, against: wronged, fine: fine))
        }
        return events
    }
}
