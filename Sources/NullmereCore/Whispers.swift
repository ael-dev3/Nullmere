/// Whispers on the water: a keeper lets a rumour loose about another
/// House, unsigned: its host gathered at one of its holds, its granaries
/// near empty, or the walls of its seat broken. The realm tells every
/// keeper the whisper, but not whose it is, nor whether it is true; the
/// realm alone knows that, from the moment it is let loose. A keeper whose
/// Lanterns scout a hold of the House it names, within ten watches, learns
/// the truth of it; a whisper found false names its teller to the whole
/// realm, and its teller pays the House it belied. A true one is never
/// traced. Stewards whisper nothing, so a world of stewards goes as it
/// always did.
public struct Whisper: Codable, Equatable, Identifiable, Sendable {
    /// What a whisper says of a House.
    public enum Claim: Codable, Equatable, Hashable, Sendable {
        /// Its host stands gathered at one of its holds.
        case hostGathered(house: Int, hold: Int)
        /// Its granaries run low.
        case granariesLow(house: Int)
        /// The walls of its seat are broken.
        case seatBreached(house: Int)

        /// The House it is about.
        public var house: Int {
            switch self {
            case .hostGathered(let house, _), .granariesLow(let house), .seatBreached(let house): return house
            }
        }
    }

    /// What a whisper being made says, before its House is chosen.
    public enum Kind: CaseIterable, Sendable {
        case host, granaries, walls

        public var title: String {
            switch self {
            case .host: return "A host gathered"
            case .granaries: return "Granaries low"
            case .walls: return "Walls broken"
            }
        }
    }

    /// The whisper the choices make, once they are enough: a host, at a
    /// hold of its House.
    public static func claim(_ kind: Kind, house: Int?, hold: Int? = nil) -> Claim? {
        guard let house else { return nil }
        switch kind {
        case .host: return hold.map { .hostGathered(house: house, hold: $0) }
        case .granaries: return .granariesLow(house: house)
        case .walls: return .seatBreached(house: house)
        }
    }

    public let id: Int
    /// The House that let it loose: in a keeper's view, known only to that
    /// House, and to all once it is found false.
    public internal(set) var by: Int?
    public let claim: Claim
    /// The watch it was let loose.
    public let spoken: Int
    /// Whether it was true when let loose: in a keeper's view, known only
    /// once that keeper's Lanterns have tried it, or it is found false.
    public internal(set) var truth: Bool?
    /// The keepers' Houses whose Lanterns have tried it; in a keeper's
    /// view, only its own.
    public internal(set) var triedBy: [Int]
    /// Whether it was found false and its teller named.
    public internal(set) var unmasked: Bool

    public init(id: Int, by: Int?, claim: Claim, spoken: Int, truth: Bool?, triedBy: [Int] = [], unmasked: Bool = false) {
        self.id = id
        self.by = by
        self.claim = claim
        self.spoken = spoken
        self.truth = truth
        self.triedBy = triedBy
        self.unmasked = unmasked
    }
}

extension GameState {
    /// What a whisper costs to let loose.
    public static let whisperCost = Stock(moonsalt: 10)
    /// Watches between one whisper of a House and its next.
    public static let whisperRest = 5
    /// Watches after it is let loose that Lanterns may try a whisper.
    public static let whisperReach = 10
    /// Watches the realm remembers a whisper.
    public static let whispersKept = 24
    /// What a teller found false pays the House it belied, at most.
    public static let whisperPenalty = 30
    /// The troops within two tiles of a hold that make a host gathered.
    public static let gatheredHost = 2_000

    /// The realm's whispers, the earliest first.
    public var whispersHeard: [Whisper] { whispers ?? [] }

    /// Whether a claim is true now, as the realm knows it.
    public func isTrue(_ claim: Whisper.Claim) -> Bool {
        switch claim {
        case .hostGathered(let house, let holdID):
            guard let hold = hold(holdID) else { return false }
            let near = units.filter { $0.owner == house && $0.kind.isMilitary && $0.position.distance(to: hold.position) <= 2 }
            return near.reduce(0) { $0 + troops(of: $1) } >= GameState.gatheredHost
        case .granariesLow(let house):
            return houses[house].stock.grain < max(upkeep(of: house), 1) * 3
        case .seatBreached(let house):
            guard let seat = seat(of: house) else { return false }
            return seat.ward * 2 < seat.maximumWard
        }
    }

    /// Why a House can't let this whisper loose now, if it can't: a
    /// keeper's, about another living House (of a hold of its own, for a
    /// host), rested since its last, and the moonsalt for it.
    public func whisperRefusal(_ claim: Whisper.Claim, as house: Int) -> RuleError? {
        guard houses.indices.contains(house), houses[house].isPlayer, !houses[house].isEliminated else { return .notAKeeper }
        let other = claim.house
        guard other != house, houses.indices.contains(other), !houses[other].isEliminated else { return .notApplicable }
        if case .hostGathered(_, let holdID) = claim, hold(holdID)?.owner != other { return .unknownHold }
        if let last = whispersHeard.last(where: { $0.by == house }), watch < last.spoken + GameState.whisperRest {
            return .whisperedLately(until: last.spoken + GameState.whisperRest)
        }
        let stock = houses[house].stock
        guard stock.covers(GameState.whisperCost) else { return .shortOf(stock.shortfall(for: GameState.whisperCost)) }
        return nil
    }

    /// A keeper lets a whisper loose: the realm keeps whose it is, and
    /// whether it is true.
    mutating func whisper(_ claim: Whisper.Claim, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = whisperRefusal(claim, as: house) { throw refusal }
        houses[house].stock.debit(GameState.whisperCost)
        let id = (whispersHeard.map(\.id).max() ?? 0) + 1
        whispers = whispersHeard + [Whisper(id: id, by: house, claim: claim, spoken: watch, truth: isTrue(claim))]
        return [.whispered(id: id, claim: claim), .whisperLet(id: id, by: house)]
    }

    /// A keeper's Lanterns, having scouted a hold, try every whisper of its
    /// House still within reach that they have not: they learn its truth,
    /// and one found false names its teller, who pays the House it belied.
    mutating func tryWhispers(scouting holdID: Int, as house: Int) -> [GameEvent] {
        guard var kept = whispers, houses.indices.contains(house), houses[house].isPlayer, let owner = hold(holdID)?.owner else { return [] }
        var events: [GameEvent] = []
        for index in kept.indices where kept[index].claim.house == owner && !kept[index].triedBy.contains(house)
            && watch <= kept[index].spoken + GameState.whisperReach {
            kept[index].triedBy.append(house)
            let truth = kept[index].truth ?? false
            events.append(.whisperTried(id: kept[index].id, house: house, truth: truth))
            guard !truth, !kept[index].unmasked, let teller = kept[index].by else { continue }
            kept[index].unmasked = true
            let paid = min(GameState.whisperPenalty, houses[teller].stock.moonsalt)
            houses[teller].stock.moonsalt -= paid
            store(Stock(moonsalt: paid), for: owner)
            record(.whisper, [teller, owner], "\(houses[teller].title) is found to have whispered falsely of \(houses[owner].title), and pays it \(paid) moonsalt.")
            events.append(.whisperUnmasked(id: kept[index].id, teller: teller, belied: owner, paid: paid))
        }
        whispers = kept
        return events
    }

    /// As the watch turns, the realm forgets the whispers of long ago.
    mutating func keepWhispers() {
        guard let kept = whispers else { return }
        let fresh = kept.filter { watch < $0.spoken + GameState.whispersKept }
        whispers = fresh.isEmpty ? nil : fresh
    }

    /// A whisper as the realm tells it.
    /// A whisper heard, as the Mac's Realm panel and the phone tell it.
    public func whisperSaid(_ whisper: Whisper) -> String {
        "Watch \(whisper.spoken): \(told(whisper.claim))."
    }

    /// How a whisper stands for a keeper's House, in a line, on the Mac and
    /// the phone: unproven, tried by its Lanterns, or found false and its
    /// teller named.
    public func whisperStandingSaid(_ whisper: Whisper, to house: Int) -> String {
        if whisper.unmasked, let teller = whisper.by {
            return "Found false: it was \(teller == house ? "yours" : (houses.indices.contains(teller) ? houses[teller].title : "a fallen House") + "'s")."
        }
        let yours = whisper.by == house ? "Yours. " : ""
        // Its truth as the House's Lanterns found it, the realm's word.
        switch whisper.triedBy.contains(house) ? whisper.truth : nil {
        case true?: return yours + "True, as your Lanterns found."
        case false?: return yours + "False, as your Lanterns found."
        case nil:
            let until = whisper.spoken + GameState.whisperReach
            guard watch <= until, whisper.claim.house != house else { return yours + "Unproven." }
            return yours + "Unproven: your Lanterns may try it at any hold of that House until watch \(until)."
        }
    }

    public func told(_ claim: Whisper.Claim) -> String {
        let name = houses.indices.contains(claim.house) ? houses[claim.house].title : "a fallen House"
        switch claim {
        case .hostGathered(_, let holdID): return "\(name) gathers its host at \(hold(holdID)?.name ?? "one of its holds")"
        case .granariesLow: return "the granaries of \(name) run low"
        case .seatBreached: return "the walls of \(name)'s seat are broken"
        }
    }
}
