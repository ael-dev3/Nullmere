/// Standing orders: what a keeper would have their House do while they are
/// away, kept by the realm and followed by the caretaker that keeps the
/// House once its keeper has been away two watches. The one kind of
/// company of war it musters; the work it raises first, wherever it can;
/// every company kept on the House's own land; peace made with any House
/// that offers it, and sued for in every war, or with none; and tribute
/// paid or refused. A keeper gives them in their own words, read by their
/// Mac's model, or in the order book's lines, and they stand until the
/// keeper changes or clears them. No other House knows them. Only a
/// keeper's House has a caretaker, so a world of stewards goes as it
/// always did.
public struct StandingOrders: Codable, Equatable, Sendable {
    public let house: Int
    /// The kind of company of war the caretaker musters, and no other.
    public internal(set) var muster: UnitKind?
    /// The work the caretaker raises first, wherever it can.
    public internal(set) var raise: BuildingKind?
    /// Every company kept on the House's own land.
    public internal(set) var home: Bool?
    /// Peace made with every House that offers it and sued for in every
    /// war (true), or made with none (false).
    public internal(set) var peace: Bool?
    /// Tribute demanded of the House paid (true) or refused (false).
    public internal(set) var tribute: Bool?

    public init(house: Int) {
        self.house = house
    }

    public var isEmpty: Bool {
        muster == nil && raise == nil && home == nil && peace == nil && tribute == nil
    }

    /// The orders with one more given, standing in for any of its kind.
    mutating func take(_ order: StandingOrder) {
        switch order {
        case .muster(let kind): muster = kind
        case .raise(let kind): raise = kind
        case .home: home = true
        case .peace(let made): peace = made
        case .tribute(let paid): tribute = paid
        }
    }

    /// What the caretaker does by them, a clause each: "musters only
    /// Spears", "keeps every company on your land".
    public var told: [String] {
        var clauses: [String] = []
        if let muster { clauses.append("musters only \(muster.title)") }
        if let raise { clauses.append("raises the \(raise.title) first wherever it can") }
        if home == true { clauses.append("keeps every company on your land") }
        switch peace {
        case true?: clauses.append("makes peace with any House that offers it, and sues for it in every war")
        case false?: clauses.append("makes peace with no House")
        case nil: break
        }
        switch tribute {
        case true?: clauses.append("pays any tribute demanded")
        case false?: clauses.append("pays no tribute")
        case nil: break
        }
        return clauses
    }

    /// The orders whole, as the keeper is told them.
    public var said: String {
        let clauses = told
        guard !clauses.isEmpty else { return "While you are away, your caretaker keeps your House as it sees fit." }
        let joined = clauses.count == 1 ? clauses[0]
            : clauses.dropLast().joined(separator: "; ") + "; and " + clauses[clauses.count - 1]
        return "While you are away, your caretaker \(joined)."
    }
}

/// One standing order, as a keeper gives it.
public enum StandingOrder: Codable, Equatable, Sendable {
    case muster(UnitKind)
    case raise(BuildingKind)
    case home
    case peace(Bool)
    case tribute(Bool)
}

extension GameState {
    /// The standing orders a House's keeper has given: none, where they
    /// have given none.
    public func standingOrders(of house: Int) -> StandingOrders {
        standing?.first { $0.house == house } ?? StandingOrders(house: house)
    }

    /// Why a House can't give this standing order; nil if it can.
    public func standRefusal(_ order: StandingOrder, as house: Int) -> RuleError? {
        guard houses.indices.contains(house), houses[house].isPlayer else { return .notAKeeper }
        if case .muster(let kind) = order, !kind.isMilitary { return .notACompanyOfWar }
        return nil
    }

    mutating func stand(_ order: StandingOrder, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = standRefusal(order, as: house) { throw refusal }
        var orders = standingOrders(of: house)
        orders.take(order)
        keep(orders)
        return [.standingOrdersGiven(house: house)]
    }

    /// The keeper's standing orders cleared: the caretaker keeps the House
    /// as it sees fit.
    mutating func standDown(as house: Int) throws(RuleError) -> [GameEvent] {
        guard houses.indices.contains(house), houses[house].isPlayer else { throw .notAKeeper }
        guard !standingOrders(of: house).isEmpty else { throw .noStandingOrders }
        keep(StandingOrders(house: house))
        return [.standingOrdersGiven(house: house)]
    }

    /// A House's keeper gone from its seat takes their standing orders with
    /// them: a steward keeps the House as it sees fit.
    mutating func withdrawStandingOrders(of house: Int) {
        keep(StandingOrders(house: house))
    }

    private mutating func keep(_ orders: StandingOrders) {
        let all = (standing ?? []).filter { $0.house != orders.house } + (orders.isEmpty ? [] : [orders])
        standing = all.isEmpty ? nil : all.sorted { $0.house < $1.house }
    }
}
