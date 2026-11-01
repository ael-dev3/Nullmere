/// Oaths the realm keeps. A keeper swears an oath to another House, in
/// their own words, which their Mac's model reads into the realm's terms,
/// and the realm then holds their House to it: sworn to peace, the House
/// may not declare war on the other until the oath ends; sworn to send
/// goods, the realm sends them at each watch's turn. An oath is renounced
/// only with notice, three watches told to the whole realm, so it is never
/// broken by surprise; an oath whose goods the House cannot send is
/// broken, and the realm remembers it as it remembers a pact betrayed. A
/// steward sent goods by oath keeps the peace with the House that sends
/// them. Only keepers swear, so a world of stewards goes as it always did.
public enum OathTerm: Codable, Equatable, Sendable {
    /// No war declared on the House sworn to.
    case peace
    /// So much of a store sent to it each watch.
    case send(Resource, Int)
}

/// An oath in force: who swore it, to whom, what to, and until when.
public struct Oath: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let by: Int
    public let to: Int
    public let term: OathTerm
    /// The watch it was sworn.
    public let sworn: Int
    /// The watch it is kept through: it binds until that watch turns.
    public let until: Int
    /// The watch it was renounced, if it has been.
    public internal(set) var renounced: Int?

    public init(id: Int, by: Int, to: Int, term: OathTerm, sworn: Int, until: Int, renounced: Int? = nil) {
        self.id = id
        self.by = by
        self.to = to
        self.term = term
        self.sworn = sworn
        self.until = until
        self.renounced = renounced
    }
}

/// How an oath came to an end.
public enum OathEnd: String, Codable, Equatable, Sendable {
    /// Kept to its last watch.
    case kept
    /// Renounced, and its notice run out.
    case renounced
    /// Its goods not sent: broken.
    case broken
    /// One of the two Houses fallen.
    case fallen
}

extension GameState {
    /// The most oaths a House holds itself to at once.
    public static let oathsHeld = 6
    /// The most watches an oath binds.
    public static let oathLongest = 60
    /// The watches a renounced oath still binds.
    public static let oathNotice = 3

    /// The oaths in force, the oldest first.
    public var oathsInForce: [Oath] { oaths ?? [] }

    /// The oaths a House has sworn.
    public func oaths(by house: Int) -> [Oath] {
        oathsInForce.filter { $0.by == house }
    }

    /// The last watch an oath binds: its own last, or its notice's.
    public func lastWatch(of oath: Oath) -> Int {
        min(oath.until, oath.renounced.map { $0 + GameState.oathNotice } ?? oath.until)
    }

    /// Whether a House is sworn to peace with another now.
    public func isSwornToPeace(_ house: Int, with other: Int) -> Bool {
        oathsInForce.contains { $0.by == house && $0.to == other && $0.term == .peace }
    }

    /// Whether a House sends goods by oath to another now.
    func sendsByOath(_ house: Int, to other: Int) -> Bool {
        oathsInForce.contains { oath in
            guard oath.by == house, oath.to == other, case .send = oath.term else { return false }
            return true
        }
    }

    /// An oath as the realm tells it: "peace with House X until watch 40",
    /// "30 grain to House X each watch until watch 40".
    public func terms(of oath: Oath) -> String {
        let other = houses.indices.contains(oath.to) ? houses[oath.to].title : "a fallen House"
        switch oath.term {
        case .peace: return "peace with \(other) until watch \(lastWatch(of: oath))"
        case let .send(resource, amount):
            return "\(GameState.counted(amount)) \(resource.title.lowercased()) to \(other) each watch until watch \(lastWatch(of: oath))"
        }
    }

    /// Why a House can't swear this oath now, if it can't: a keeper's, to
    /// another House standing, for one to sixty watches, of goods it names,
    /// to peace with a House it is not at war with, and not more oaths than
    /// it may hold.
    public func swearRefusal(_ term: OathTerm, to other: Int, watches: Int, as house: Int) -> RuleError? {
        guard houses.indices.contains(house), houses[house].isPlayer, !houses[house].isEliminated else { return .notAKeeper }
        guard other != house, houses.indices.contains(other), !houses[other].isEliminated else { return .unknownHouse }
        guard (1...GameState.oathLongest).contains(watches) else { return .invalidAmount }
        switch term {
        case .peace:
            guard stance(house, other) != .war else { return .alreadyStance(.war) }
            guard !isSwornToPeace(house, with: other) else { return .notApplicable }
        case let .send(_, amount):
            guard amount > 0 else { return .invalidAmount }
        }
        guard oaths(by: house).count < GameState.oathsHeld else { return .oathsHeld }
        return nil
    }

    /// A keeper swears an oath: the realm holds their House to it, and tells
    /// the whole realm.
    mutating func swear(_ term: OathTerm, to other: Int, watches: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = swearRefusal(term, to: other, watches: watches, as: house) { throw refusal }
        let oath = Oath(id: takeID(), by: house, to: other, term: term, sworn: watch, until: watch + watches)
        oaths = oathsInForce + [oath]
        record(.pact, [house, other], "\(houses[house].title) swears an oath to \(houses[other].title): \(terms(of: oath)).")
        return [.oathSworn(oath)]
    }

    /// Why a House can't renounce an oath now: one it swore, not renounced already.
    public func renounceRefusal(_ oathID: Int, as house: Int) -> RuleError? {
        guard let oath = oathsInForce.first(where: { $0.id == oathID }), oath.by == house else { return .notYourOath }
        guard oath.renounced == nil else { return .notApplicable }
        return nil
    }

    /// A House renounces an oath it swore: it binds three watches more, and
    /// the whole realm is told.
    mutating func renounce(_ oathID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = renounceRefusal(oathID, as: house) { throw refusal }
        let index = oaths!.firstIndex { $0.id == oathID }!
        oaths![index].renounced = watch
        let oath = oaths![index]
        record(.pact, [house, oath.to], "\(houses[house].title) renounces its oath to \(houses[oath.to].title); it binds until watch \(lastWatch(of: oath)).")
        return [.oathRenounced(oath)]
    }

    /// A keeper gone from their House takes their oaths with them: the next
    /// to keep it, or its steward, swore none of them.
    mutating func withdrawOaths(of house: Int) {
        guard let sworn = oaths else { return }
        let kept = sworn.filter { $0.by != house }
        oaths = kept.isEmpty ? nil : kept
    }

    /// As the watch turns: each oath's goods sent, or the oath broken if they
    /// can't be; and the oaths at their end let go, kept, renounced, or with
    /// a House fallen.
    mutating func keepOaths() -> [GameEvent] {
        guard let sworn = oaths, !sworn.isEmpty else { return [] }
        var events: [GameEvent] = []
        var standing: [Oath] = []
        for oath in sworn {
            let fallen = !houses.indices.contains(oath.by) || houses[oath.by].isEliminated
                || !houses.indices.contains(oath.to) || houses[oath.to].isEliminated
            if fallen {
                events.append(.oathEnded(oath, why: .fallen))
                continue
            }
            if case let .send(resource, amount) = oath.term {
                var goods = Stock()
                goods[resource] = amount
                if houses[oath.by].stock.covers(goods) {
                    houses[oath.by].stock.debit(goods)
                    store(goods, for: oath.to)
                } else {
                    // Unpaid: the oath is broken, and remembered as a betrayal is.
                    if let index = relationIndex(oath.by, oath.to) { relations[index].betrayals += 1 }
                    record(.betrayal, [oath.by, oath.to],
                           "\(houses[oath.by].title) breaks its oath to \(houses[oath.to].title), sending nothing it swore to send.")
                    events.append(.oathEnded(oath, why: .broken))
                    continue
                }
            }
            if watch >= lastWatch(of: oath) {
                let end: OathEnd = oath.renounced != nil && lastWatch(of: oath) < oath.until ? .renounced : .kept
                if end == .kept {
                    record(.pact, [oath.by, oath.to], "\(houses[oath.by].title) has kept its oath to \(houses[oath.to].title).")
                }
                events.append(.oathEnded(oath, why: end))
                continue
            }
            standing.append(oath)
        }
        oaths = standing.isEmpty ? nil : standing
        return events
    }
}
